package kite

import (
	"encoding/json"
	"fmt"
	"github.com/streadway/amqp"
	"koding/tools/amqputil"
	"koding/tools/dnode"
	"koding/tools/lifecycle"
	"koding/tools/log"
	"os"
	"os/signal"
	"syscall"
	"time"
)

type Kite struct {
	Name          string
	Handlers      map[string]Handler
	LoadBalancing bool
}

type Handler struct {
	Concurrent bool
	Callback   func(args *dnode.Partial, session *Session) (interface{}, error)
}

func New(name string) *Kite {
	return &Kite{
		Name:     name,
		Handlers: make(map[string]Handler),
	}
}

func (k *Kite) LoadBalance() {
	k.LoadBalancing = true
}

func (k *Kite) Handle(method string, concurrent bool, callback func(args *dnode.Partial, session *Session) (interface{}, error)) {
	k.Handlers[method] = Handler{concurrent, callback}
}

func (k *Kite) Run() {
	changeClientsGauge := lifecycle.CreateClientsGauge()
	log.RunGaugesLoop()

	routeMap := make(map[string](chan<- []byte))
	defer func() {
		for _, channel := range routeMap {
			close(channel)
		}
	}()

	timeoutChannel := make(chan string)

	sigtermChannel := make(chan os.Signal)
	signal.Notify(sigtermChannel, syscall.SIGTERM)

	consumeConn := amqputil.CreateConnection("kite-" + k.Name)
	defer consumeConn.Close()

	publishConn := amqputil.CreateConnection("kite-" + k.Name)
	defer publishConn.Close()

	publishChannel := amqputil.CreateChannel(publishConn)
	defer publishChannel.Close()

	consumeChannel := amqputil.CreateChannel(consumeConn)
	amqputil.DeclarePresenceExchange(consumeChannel, "services-presence", "kite", "kite-"+k.Name, "kite-"+k.Name, k.LoadBalancing)
	stream := amqputil.DeclareBindConsumeQueue(consumeChannel, "fanout", "kite-"+k.Name, "", true)

	for {
		select {
		case message, ok := <-stream:
			if !ok {
				return
			}

			switch message.RoutingKey {
			case "auth.join":
				var client struct {
					Username   string
					RoutingKey string
				}
				err := json.Unmarshal(message.Body, &client)
				if err != nil || client.Username == "" || client.RoutingKey == "" {
					log.Err("Invalid auth.join message.", message.Body)
					continue
				}

				if _, found := routeMap[client.RoutingKey]; found {
					log.Warn("Duplicate auth.join for same routing key.")
					continue
				}
				channel := make(chan []byte, 1024)
				routeMap[client.RoutingKey] = channel

				go func() {
					defer log.RecoverAndLog()

					changeClientsGauge(1)
					log.Debug("Client connected: " + client.Username)
					defer func() {
						changeClientsGauge(-1)
						log.Debug("Client disconnected: " + client.Username)
					}()

					session := NewSession(client.Username)
					defer session.Close()

					d := dnode.New()
					defer d.Close()
					d.OnRootMethod = func(method string, args *dnode.Partial) {
						defer log.RecoverAndLog()

						if method == "ping" {
							d.Send("pong")
							return
						}

						var partials []*dnode.Partial
						err := args.Unmarshal(&partials)
						if err != nil {
							panic(err)
						}

						var options struct {
							WithArgs *dnode.Partial
						}
						err = partials[0].Unmarshal(&options)
						if err != nil {
							panic(err)
						}
						var resultCallback dnode.Callback
						err = partials[1].Unmarshal(&resultCallback)
						if err != nil {
							panic(err)
						}

						handler, found := k.Handlers[method]
						if !found {
							resultCallback(fmt.Sprintf("Method '%v' not known.", method), nil)
							return
						}

						execHandler := func() {
							result, err := handler.Callback(options.WithArgs, session)
							if b, ok := result.([]byte); ok {
								result = string(b)
							}

							if err != nil {
								resultCallback(err.Error(), result)
								return
							}

							resultCallback(nil, result)
						}

						if handler.Concurrent {
							go func() {
								defer log.RecoverAndLog()
								execHandler()
							}()
							return
						}

						execHandler()
					}

					go func() {
						defer log.RecoverAndLog()
						for data := range d.SendChan {
							log.Debug("Write", client.RoutingKey, data)
							err := publishChannel.Publish("broker", client.RoutingKey, false, false, amqp.Publishing{Body: data})
							if err != nil {
								log.LogError(err, 0)
							}
						}
					}()

					d.Send("ready", "kite-"+k.Name)

					for {
						select {
						case message, ok := <-channel:
							if !ok {
								return
							}
							log.Debug("Read", client.RoutingKey, message)
							d.ProcessMessage(message)
						case <-time.After(24 * time.Hour):
							timeoutChannel <- client.RoutingKey
						}
					}
				}()

			case "auth.leave":
				var client struct {
					RoutingKey string
				}
				err := json.Unmarshal(message.Body, &client)
				if err != nil || client.RoutingKey == "" {
					log.Err("Invalid auth.leave message.", message.Body)
					continue
				}

				channel, found := routeMap[client.RoutingKey]
				if found {
					close(channel)
					delete(routeMap, client.RoutingKey)
				}

			case "auth.who":
				var client struct {
					RoutingKey string
					Username   string
				}
				if handler, ok := k.Handlers["auth.who"]; ok {
					json.Unmarshal(message.Body, &client)
					session := NewSession(client.Username)
					handler.Callback(nil, session)
				} else {
					log.Warn("Need to implement the handler for auth.who")
				}

			default:
				channel, found := routeMap[message.RoutingKey]
				if found {
					select {
					case channel <- message.Body:
						// successful
					default:
						close(channel)
						delete(routeMap, message.RoutingKey)
						log.Warn("Dropped client because of message buffer overflow.")
					}
				}
			}

		case routingKey := <-timeoutChannel:
			channel, found := routeMap[routingKey]
			if found {
				close(channel)
				delete(routeMap, routingKey)
				log.Warn("Dropped client because of fallback session timeout.")
			}

		case <-sigtermChannel:
			log.Info("Received TERM signal. Beginning shutdown...")
			lifecycle.BeginShutdown()
			consumeChannel.Close()
		}
	}
}

type Session struct {
	Username     string
	Alive        bool
	onDisconnect []func()
}

func NewSession(username string) *Session {
	return &Session{
		Username: username,
		Alive:    true,
	}
}

func (session *Session) OnDisconnect(f func()) {
	session.onDisconnect = append(session.onDisconnect, f)
}

func (session *Session) Close() {
	session.Alive = false
	for _, f := range session.onDisconnect {
		f()
	}
	session.onDisconnect = nil
}
