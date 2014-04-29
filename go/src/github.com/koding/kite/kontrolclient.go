// kontrolclient implements a kite.Client for interacting with Kontrol kite.
package kite

import (
	"container/list"
	"errors"
	"net/url"
	"sync"

	"github.com/dgrijalva/jwt-go"
	"github.com/koding/kite/dnode"
	"github.com/koding/kite/protocol"
)

// Returned from GetKites when query matches no kites.
var ErrNoKitesAvailable = errors.New("no kites availabile")

// KontrolClient is a kite for registering and querying Kites from Kontrol.
type KontrolClient struct {
	*Client

	// used for synchronizing methods that needs to be called after
	// successful connection.
	Ready chan struct{}

	// Watchers are saved here to re-watch on reconnect.
	watchers      *list.List
	watchersMutex sync.RWMutex
}

// Event is the struct that is emitted from Kontrol.WatchKites method.
type Event struct {
	protocol.KiteEvent

	localKite *Kite
}

type registerResult struct {
	URL *url.URL
}

// SetupKontrolClient setups and prepares a new kontrol client instance.
// Usually needed for preparations.
func (k *Kite) SetupKontrolClient() error {
	if k.Kontrol != nil {
		return nil // already prepared
	}

	kontrolClient, err := k.newKontrolClient()
	if err != nil {
		return err
	}

	k.Kontrol = kontrolClient
	return nil
}

// newKontrolClient returns a ready and connected KontrolClient instance.
func (k *Kite) newKontrolClient() (*KontrolClient, error) {
	if k.Config.KontrolURL == nil {
		return nil, errors.New("no kontrol URL given in config")
	}

	client := k.NewClient(k.Config.KontrolURL)
	client.Kite = protocol.Kite{Name: "kontrol"} // for logging purposes
	client.Authentication = &Authentication{
		Type: "kiteKey",
		Key:  k.Config.KiteKey,
	}

	kontrolClient := &KontrolClient{
		Client:   client,
		Ready:    make(chan struct{}),
		watchers: list.New(),
	}

	var once sync.Once

	kontrolClient.OnConnect(func() {
		k.Log.Info("Connected to Kontrol ")

		// signal all other methods that are listening on this channel, that we
		// are ready.
		once.Do(func() { close(kontrolClient.Ready) })

		// Re-register existing watchers.
		kontrolClient.watchersMutex.RLock()
		for e := kontrolClient.watchers.Front(); e != nil; e = e.Next() {
			watcher := e.Value.(*Watcher)
			if err := watcher.rewatch(); err != nil {
				k.Log.Error("Cannot rewatch query: %+v", watcher)
			}
		}
		kontrolClient.watchersMutex.RUnlock()
	})

	// non blocking, is going to reconnect if the connection goes down.
	if _, err := kontrolClient.DialForever(); err != nil {
		return nil, err
	}

	return kontrolClient, nil
}

// Register registers current Kite to Kontrol. After registration other Kites
// can find it via GetKites() method.
//
// This method does not handle the reconnection case. If you want to keep
// registered to kontrol, use kite/registration package.
func (k *Kite) Register(kiteURL *url.URL) (*registerResult, error) {
	if k.Kontrol == nil {
		kontrolClient, err := k.newKontrolClient()
		if err != nil {
			return nil, err
		}

		k.Kontrol = kontrolClient
	}

	<-k.Kontrol.Ready

	args := protocol.RegisterArgs{
		URL: kiteURL.String(),
	}

	response, err := k.Kontrol.Tell("register", args)
	if err != nil {
		return nil, err
	}

	var rr protocol.RegisterResult
	err = response.Unmarshal(&rr)
	if err != nil {
		return nil, err
	}

	k.Log.Info("Registered to kontrol with URL: %s", rr.URL)

	parsed, err := url.Parse(rr.URL)
	if err != nil {
		k.Log.Error("Cannot parse registered URL: %s", err.Error())
	}

	return &registerResult{parsed}, nil
}

// WatchKites watches for Kites that matches the query. The onEvent functions
// is called for current kites and every new kite event.
func (k *Kite) WatchKites(query protocol.KontrolQuery, onEvent EventHandler) (*Watcher, error) {
	if k.Kontrol == nil {
		kontrolClient, err := k.newKontrolClient()
		if err != nil {
			return nil, err
		}

		k.Kontrol = kontrolClient
	}

	<-k.Kontrol.Ready

	watcherID, err := k.watchKites(query, onEvent)
	if err != nil {
		return nil, err
	}

	return k.newWatcher(watcherID, &query, onEvent), nil
}

func (k *Kite) eventCallbackHandler(onEvent EventHandler) dnode.Function {
	return dnode.Callback(func(args *dnode.Partial) {
		var response struct {
			Result *Event `json:"result"`
			Error  *Error `json:"error"`
		}

		args.One().MustUnmarshal(&response)

		if response.Result != nil {
			response.Result.localKite = k
		}

		onEvent(response.Result, response.Error)
	})
}

func (k *Kite) watchKites(query protocol.KontrolQuery, onEvent EventHandler) (watcherID string, err error) {
	args := protocol.GetKitesArgs{
		Query:         query,
		WatchCallback: k.eventCallbackHandler(onEvent),
	}
	clients, watcherID, err := k.getKites(args)
	if err != nil && err != ErrNoKitesAvailable {
		return "", err // return only when something really happened
	}

	// also put the current kites to the eventChan.
	for _, client := range clients {
		event := Event{
			KiteEvent: protocol.KiteEvent{
				Action: protocol.Register,
				Kite:   client.Kite,
				URL:    client.WSConfig.Location.String(),
				Token:  client.Authentication.Key,
			},
			localKite: k,
		}

		onEvent(&event, nil)
	}

	return watcherID, nil
}

// GetKites returns the list of Kites matching the query. The returned list
// contains Ready to connect Client instances. The caller must connect
// with Client.Dial() before using each Kite. An error is returned when no
// kites are available.
func (k *Kite) GetKites(query protocol.KontrolQuery) ([]*Client, error) {
	if k.Kontrol == nil {
		kontrolClient, err := k.newKontrolClient()
		if err != nil {
			return nil, err
		}

		k.Kontrol = kontrolClient
	}

	clients, _, err := k.getKites(protocol.GetKitesArgs{Query: query})
	if err != nil {
		return nil, err
	}

	if len(clients) == 0 {
		return nil, ErrNoKitesAvailable
	}

	return clients, nil
}

// used internally for GetKites() and WatchKites()
func (k *Kite) getKites(args protocol.GetKitesArgs) (kites []*Client, watcherID string, err error) {
	<-k.Kontrol.Ready

	response, err := k.Kontrol.Tell("getKites", args)
	if err != nil {
		return nil, "", err
	}

	var result = new(protocol.GetKitesResult)
	err = response.Unmarshal(&result)
	if err != nil {
		return nil, "", err
	}

	clients := make([]*Client, len(result.Kites))
	for i, currentKite := range result.Kites {
		_, err := jwt.Parse(currentKite.Token, k.RSAKey)
		if err != nil {
			return nil, result.WatcherID, err
		}

		// exp := time.Unix(int64(token.Claims["exp"].(float64)), 0).UTC()
		auth := &Authentication{
			Type: "token",
			Key:  currentKite.Token,
		}

		parsed, err := url.Parse(currentKite.URL)
		if err != nil {
			k.Log.Error("invalid url came from kontrol", currentKite.URL)
		}

		clients[i] = k.NewClientString(currentKite.URL)
		clients[i].Kite = currentKite.Kite
		clients[i].WSConfig.Location = parsed
		clients[i].Authentication = auth
	}

	// Renew tokens
	for _, r := range clients {
		token, err := NewTokenRenewer(r, k)
		if err != nil {
			k.Log.Error("Error in token. Token will not be renewed when it expires: %s", err.Error())
			continue
		}
		token.RenewWhenExpires()
	}

	return clients, result.WatcherID, nil
}

// GetToken is used to get a new token for a single Kite.
func (k *Kite) GetToken(kite *protocol.Kite) (string, error) {
	if k.Kontrol == nil {
		kontrolClient, err := k.newKontrolClient()
		if err != nil {
			return "", err
		}

		k.Kontrol = kontrolClient
	}

	<-k.Kontrol.Ready

	result, err := k.Kontrol.Tell("getToken", kite)
	if err != nil {
		return "", err
	}

	var tkn string
	err = result.Unmarshal(&tkn)
	if err != nil {
		return "", err
	}

	return tkn, nil
}

// Create new Client from Register events. It panics if the action is not
// Register.
func (e *Event) Client() *Client {
	if e.Action != protocol.Register {
		panic("This method can only be called for 'Register' event.")
	}

	r := e.localKite.NewClientString(e.URL)
	r.Kite = e.Kite
	r.Authentication = &Authentication{
		Type: "token",
		Key:  e.Token,
	}
	return r
}
