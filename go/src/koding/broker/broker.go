package main

import (
	"crypto/rand"
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"github.com/streadway/amqp"
	"koding/tools/amqputil"
	"koding/tools/config"
	"koding/tools/lifecycle"
	"koding/tools/log"
	"koding/tools/sockjs"
	"koding/tools/utils"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"
)

func main() {
	lifecycle.Startup("broker", false)
	changeClientsGauge := lifecycle.CreateClientsGauge()
	changeNewClientsGauge := log.CreateCounterGauge("newClients", true)
	changeWebsocketClientsGauge := log.CreateCounterGauge("websocketClients", false)
	log.RunGaugesLoop()

	publishConn := amqputil.CreateConnection("broker")
	defer publishConn.Close()

	routeMap := make(map[string]([]*sockjs.Session))
	var routeMapMutex sync.Mutex

	service := sockjs.NewService(config.Current.Client.StaticFilesBaseUrl+"/js/sock.js", 10*time.Minute, func(session *sockjs.Session) {
		defer log.RecoverAndLog()

		r := make([]byte, 128/8)
		rand.Read(r)
		socketId := base64.StdEncoding.EncodeToString(r)
		session.Tag = socketId

		log.Debug("Client connected: " + socketId)
		changeClientsGauge(1)
		changeNewClientsGauge(1)
		if session.IsWebsocket {
			changeWebsocketClientsGauge(1)
		}
		defer func() {
			log.Debug("Client disconnected: " + socketId)
			changeClientsGauge(-1)
			if session.IsWebsocket {
				changeWebsocketClientsGauge(-1)
			}
		}()

		addToRouteMap := func(routingKeyPrefix string) {
			routeMapMutex.Lock()
			defer routeMapMutex.Unlock()
			routeMap[routingKeyPrefix] = append(routeMap[routingKeyPrefix], session)
		}
		removeFromRouteMap := func(routingKeyPrefix string) {
			routeMapMutex.Lock()
			defer routeMapMutex.Unlock()
			routeSessions := routeMap[routingKeyPrefix]
			for i, routeSession := range routeSessions {
				if routeSession == session {
					routeSessions[i] = routeSessions[len(routeSessions)-1]
					routeSessions = routeSessions[:len(routeSessions)-1]
					break
				}
			}
			if len(routeSessions) == 0 {
				delete(routeMap, routingKeyPrefix)
				return
			}
			routeMap[routingKeyPrefix] = routeSessions
		}

		subscriptions := make(map[string]bool)

		var controlChannel *amqp.Channel
		var lastPayload string
		resetControlChannel := func() {
			if controlChannel != nil {
				controlChannel.Close()
			}
			var err error
			controlChannel, err = publishConn.Channel()
			if err != nil {
				panic(err)
			}
			go func() {
				defer log.RecoverAndLog()

				for amqpErr := range controlChannel.NotifyClose(make(chan *amqp.Error)) {
					log.Warn("AMQP channel: "+amqpErr.Error(), "Last publish payload:", lastPayload)

					session.Send(map[string]interface{}{"routingKey": "broker.error", "code": amqpErr.Code, "reason": amqpErr.Reason, "server": amqpErr.Server, "recover": amqpErr.Recover})
				}
			}()
		}
		resetControlChannel()
		defer func() { controlChannel.Close() }()

		err := controlChannel.Publish("authAll", "broker.clientConnected", false, false, amqp.Publishing{Body: []byte(socketId)})
		if err != nil {
			panic(err)
		}

		defer func() {
			for routingKeyPrefix := range subscriptions {
				removeFromRouteMap(routingKeyPrefix)
			}
			for {
				err := controlChannel.Publish("authAll", "broker.clientDisconnected", false, false, amqp.Publishing{Body: []byte(socketId)})
				if err == nil {
					break
				}
				if amqpError, isAmqpError := err.(*amqp.Error); !isAmqpError || amqpError.Code != 504 {
					panic(err)
				}
				resetControlChannel()
			}
		}()

		for data := range session.ReceiveChan {
			func() {
				defer log.RecoverAndLog()

				message := data.(map[string]interface{})
				log.Debug("Received message", message)

				action := message["action"]
				switch action {
				case "subscribe":
					routingKeyPrefix := message["routingKeyPrefix"].(string)
					addToRouteMap(routingKeyPrefix)
					subscriptions[routingKeyPrefix] = true
					session.Send(map[string]string{"routingKey": "broker.subscribed", "payload": routingKeyPrefix})

				case "unsubscribe":
					routingKeyPrefix := message["routingKeyPrefix"].(string)
					removeFromRouteMap(routingKeyPrefix)
					delete(subscriptions, routingKeyPrefix)

				case "publish":
					exchange := message["exchange"].(string)
					routingKey := message["routingKey"].(string)
					if !strings.HasPrefix(routingKey, "client.") {
						log.Warn("Invalid routing key.", message, socketId)
						return
					}
					for {
						lastPayload = ""
						err := controlChannel.Publish(exchange, routingKey, false, false, amqp.Publishing{CorrelationId: socketId, Body: []byte(message["payload"].(string))})
						if err == nil {
							lastPayload = message["payload"].(string)
							break
						}
						if amqpError, isAmqpError := err.(*amqp.Error); !isAmqpError || amqpError.Code != 504 {
							panic(err)
						}
						resetControlChannel()
					}

				case "ping":
					session.Send(map[string]string{"routingKey": "broker.pong"})

				default:
					log.Warn("Invalid action.", message, socketId)

				}
			}()
		}
	})
	defer service.Close()
	service.ErrorHandler = log.LogError

	go func() {
		server := &http.Server{
			Handler: &sockjs.Mux{
				Handlers: map[string]http.Handler{
					"/subscribe": service,
					"/version": http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
						w.Header().Set("Content-Type", "text/plain")
						w.Write([]byte(config.Current.Version))
					}),
				},
			},
		}

		var listener net.Listener
		listener, err := net.ListenTCP("tcp", &net.TCPAddr{net.ParseIP(config.Current.Broker.IP), config.Current.Broker.Port})
		if err != nil {
			log.LogError(err, 0)
			os.Exit(1)
		}

		if config.Current.Broker.CertFile != "" {
			cert, err := tls.LoadX509KeyPair(config.Current.Broker.CertFile, config.Current.Broker.KeyFile)
			if err != nil {
				log.LogError(err, 0)
				os.Exit(1)
			}
			listener = tls.NewListener(listener, &tls.Config{
				NextProtos:   []string{"http/1.1"},
				Certificates: []tls.Certificate{cert},
			})
		}

		go func() {
			sigtermChannel := make(chan os.Signal)
			signal.Notify(sigtermChannel, syscall.SIGTERM)
			<-sigtermChannel
			lifecycle.BeginShutdown()
			listener.Close()
		}()

		lastErrorTime := time.Now()
		for {
			err := server.Serve(listener)
			if lifecycle.ShuttingDown {
				break
			}
			if err != nil {
				log.Warn("Server error: " + err.Error())
				if time.Now().Sub(lastErrorTime) < time.Second {
					os.Exit(1)
				}
				lastErrorTime = time.Now()
			}
		}
	}()

	consumeConn := amqputil.CreateConnection("broker")
	defer consumeConn.Close()

	consumeChannel := amqputil.CreateChannel(consumeConn)
	defer consumeChannel.Close()

	stream := amqputil.DeclareBindConsumeQueue(consumeChannel, "topic", "broker", "#", false)
	if err := consumeChannel.ExchangeDeclare("updateInstances", "fanout", false, false, false, false, nil); err != nil {
		panic(err)
	}
	if err := consumeChannel.ExchangeBind("broker", "", "updateInstances", false, nil); err != nil {
		panic(err)
	}

	for amqpMessage := range stream {
		routingKey := amqpMessage.RoutingKey
		payload := json.RawMessage(utils.FilterInvalidUTF8(amqpMessage.Body))
		jsonMessage := map[string]interface{}{"routingKey": routingKey, "payload": &payload}

		pos := strings.IndexRune(routingKey, '.') // skip first dot, since we want at least two components to always include the secret
		for pos != -1 && pos < len(routingKey) {
			index := strings.IndexRune(routingKey[pos+1:], '.')
			pos += index + 1
			if index == -1 {
				pos = len(routingKey)
			}
			prefix := routingKey[:pos]
			routeMapMutex.Lock()
			routeSessions := routeMap[prefix]
			for _, routeSession := range routeSessions {
				if !routeSession.Send(jsonMessage) {
					routeSession.Close()
					log.Warn("Dropped session because of broker to client buffer overflow.", routeSession.Tag)
				}
			}
			routeMapMutex.Unlock()
		}
	}
}
