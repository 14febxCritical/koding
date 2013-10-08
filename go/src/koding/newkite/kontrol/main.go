package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"github.com/gorilla/mux"
	zmq "github.com/pebbe/zmq3"
	"koding/db/models"
	"koding/db/mongodb/modelhelper"
	"koding/newkite/protocol"
	"koding/newkite/utils"
	"koding/tools/slog"
	"net/http"
	"os"
	"time"
)

// Storage is an interface that encapsulates basic operations on the kite
// struct. Uuid is an unique string that belongs to the kite.
type Storage interface {
	// Add inserts the kite into the storage with the kite.Uuid key. If there
	// is already a kite available with this uuid, it should update/replace it.
	Add(kite *models.Kite)

	// Get returns the specified kite struct with the given uuid
	Get(uuid string) *models.Kite

	// Remove deletes the kite with the given uuid
	Remove(uuid string)

	// Has checks whether the kite with the given uuid exist
	Has(uiid string) bool

	// Size returns the total number of kites in the storage
	Size() int

	// List returns a slice of all kites in the storage
	List() []*models.Kite
}

// Dependency is an interface that encapsulates basic dependency operations
// between a source item and their dependencies. A source's dependency list
// contains no duplicates and all items are unique.
type Dependency interface {
	// Add defines and inserts a new dependency (with the name target) to the
	// source.
	Add(source, target string)

	// Remove deletes source together with all their dependencies. Basically is
	// purges it completely.
	Remove(source string)

	// Has checks whether the dependency tree with the given source name exist.
	Has(source string) bool

	// List returns a slice of all dependencies that depends on the source.
	List(source string) []string
}

type Kontrol struct {
	Publisher *zmq.Socket
	Router    *zmq.Socket
	PubAddr   string
	RepAddr   string
	Hostname  string
}

var (
	self       string
	storage    Storage
	dependency Dependency
)

func main() {
	router, _ := zmq.NewSocket(zmq.ROUTER)
	router.Bind("tcp://*:5556")

	pub, _ := zmq.NewSocket(zmq.PUB)
	pub.Bind("tcp://*:5557")

	hostname, _ := os.Hostname()

	// storage = peers.New()  // in-memory, map based, non-persistence storage
	storage = NewMongoDB()
	dependency = NewDependency()

	k := &Kontrol{
		Hostname:  hostname,
		Publisher: pub,
		Router:    router,
	}

	slog.SetPrefixName("kontrol")
	slog.SetPrefixTimeStamp(time.Stamp)
	slog.Println("started")
	k.Start()
}

func (k *Kontrol) Start() {
	// This is used for two reasons
	// 1. HeartBeat mechanism for kite (Node Coordination)
	// 2. Triggering kites to register themself to kontrol (Synchronize PUB/SUB)
	ticker := time.NewTicker(protocol.HEARTBEAT_INTERVAL)
	go func() {
		for _ = range ticker.C {
			k.Ping()
		}
	}()

	// HeartBeat pool checker. Checking for kites if they are live or dead.
	go k.heartBeatChecker()

	// This is used for kite coordination. Will be replaced soon via an HTTP one.
	go k.zmqMessageRouting()

	rout := mux.NewRouter()
	rout.HandleFunc("/", homeHandler).Methods("GET")
	rout.HandleFunc("/request", prepareHandler(requestHandler)).Methods("POST")
	http.Handle("/", rout)
	slog.Println(http.ListenAndServe(":4000", nil)) // TODO: make port configurable
}

func (k *Kontrol) zmqMessageRouting() {
	for {
		msg, _ := k.Router.RecvMessageBytes(0)
		if len(msg) != 3 { // msg is malformed
			continue
		}

		identity := msg[0]
		result, err := k.handle(msg[2])
		if err != nil {
			slog.Println(err)
		}

		k.Router.SendBytes(identity, zmq.SNDMORE)
		k.Router.SendBytes([]byte(""), zmq.SNDMORE)
		k.Router.SendBytes(result, 0)
	}
}

func (k *Kontrol) Ping() {
	m := protocol.Request{
		Base: protocol.Base{
			Hostname: k.Hostname,
		},
		Action: "ping",
	}

	msg, _ := json.Marshal(&m)
	k.Publish("all", msg)
}

func (k *Kontrol) heartBeatChecker() {
	ticker := time.NewTicker(protocol.HEARTBEAT_INTERVAL)
	go func() {
		for _ = range ticker.C {
			for _, kite := range storage.List() {
				// Delay is needed to fix network delays, otherwise kites are
				// marked as death even if they are sending 'pongs' to us
				if time.Now().Before(kite.UpdatedAt.Add(protocol.HEARTBEAT_DELAY)) {
					continue // still alive, pick up the next one
				}

				removeLog := fmt.Sprintf("[%s (%s)] dead at '%s' - '%s'",
					kite.Kitename,
					kite.Version,
					kite.Hostname,
					kite.Uuid,
				)
				slog.Println(removeLog)

				storage.Remove(kite.Uuid)

				// notify kites of the same type
				msg := createByteResponse(protocol.RemoveKite, kite)
				k.Publish(kite.Kitename, msg)

				// then notify kites that depends on me..
				for _, c := range k.getRelationship(kite.Kitename) {
					k.Publish(c.Kitename, msg)
				}

				// Am I the latest of my kind ? if yes remove me from the dependencies list
				// and remove any tokens if I have some
				if dependency.Has(kite.Kitename) {
					var found bool
					for _, t := range storage.List() {
						if t.Kitename == kite.Kitename {
							found = true
						}
					}

					if !found {
						deleteToken(kite.Kitename)
						dependency.Remove(kite.Kitename)
					}
				}
			}
		}
	}()
}

func (k *Kontrol) handle(msg []byte) ([]byte, error) {
	req, err := unmarshalRequest(msg)
	if err != nil {
		return nil, err
	}

	k.updateKite(req.Uuid)

	switch req.Action {
	case "pong":
		return k.handlePong(req)
	case "register":
		return k.handleRegister(req)
	case "getKites":
		return k.handleGetKites(req)
	case "getPermission":
		return k.handleGetPermission(req)
	}

	return []byte("handle error"), nil
}

func (k *Kontrol) updateKite(Uuid string) error {
	kite := storage.Get(Uuid)
	if kite == nil {
		return errors.New("not registered")
	}
	kite.UpdatedAt = time.Now().Add(protocol.HEARTBEAT_INTERVAL)
	storage.Add(kite)
	return nil
}

func unmarshalRequest(msg []byte) (*protocol.Request, error) {
	req := new(protocol.Request)
	err := json.Unmarshal(msg, &req)
	if err != nil {
		return nil, err
	}

	return req, nil
}

func (k *Kontrol) handlePong(req *protocol.Request) ([]byte, error) {
	err := k.updateKite(req.Uuid)
	if err != nil {
		return []byte("UPDATE"), nil
	}

	return []byte("OK"), nil
}

func (k *Kontrol) handleRegister(req *protocol.Request) ([]byte, error) {
	slog.Printf("[%s (%s)] at '%s' wants to be registered\n", req.Kitename, req.Version, req.Hostname)
	kite, err := k.RegisterKite(req)
	if err != nil {
		response := protocol.RegisterResponse{Addr: self, Result: protocol.PermitKite}
		resp, _ := json.Marshal(response)
		return resp, err
	}

	// disable this for now
	// go addToProxy(kite)

	// first notify myself
	k.Publish(req.Uuid, createByteResponse(protocol.AddKite, kite))

	// then notify dependencies of this kite, if any available
	k.NotifyDependencies(kite)

	startLog := fmt.Sprintf("[%s (%s)] starting at '%s' - '%s'",
		kite.Kitename,
		kite.Version,
		kite.Hostname,
		kite.Uuid,
	)
	slog.Println(startLog)

	// send response back to the kite, also identify him with the new name
	response := protocol.RegisterResponse{
		Addr:     self,
		Result:   protocol.AllowKite,
		Username: kite.Username,
	}
	resp, _ := json.Marshal(response)
	return resp, nil

}
func (k *Kontrol) handleGetKites(req *protocol.Request) ([]byte, error) {
	kites, err := searchForKites(req.Username, req.RemoteKite)
	if err != nil {
		return nil, err
	}

	for _, kite := range kites {
		msg, _ := json.Marshal(kite)
		k.Publish(req.Uuid, msg)
	}

	// Add myself as an dependency to the kite itself (to the kite I
	// request above). This is needed when new kites of that type appear
	// on kites that exist dissapear.
	slog.Printf("adding '%s' as a dependency to '%s' \n", req.Kitename, req.RemoteKite)
	dependency.Add(req.RemoteKite, req.Kitename)

	resp, err := json.Marshal(protocol.RegisterResponse{Addr: self, Result: "kitesPublished"})
	if err != nil {
		return nil, err
	}

	return resp, nil
}

func (k *Kontrol) handleGetPermission(req *protocol.Request) ([]byte, error) {
	slog.Printf("[%s] asks if token '%s' is valid\n", req.Kitename, req.Token)

	msg := protocol.RegisterResponse{}

	token := getToken(req.Username)
	if token == nil || token.ID != req.Token {
		slog.Printf("token '%s' is invalid for '%s' \n", req.Token, req.Kitename)
		msg = protocol.RegisterResponse{Addr: self, Result: protocol.PermitKite}
	} else {
		slog.Printf("token '%s' is valid for '%s' \n", req.Token, req.Kitename)
		msg = protocol.RegisterResponse{Addr: self, Result: protocol.AllowKite, Token: *token}
	}

	resp, err := json.Marshal(msg)
	if err != nil {
		return nil, err
	}

	return resp, nil
}

func createByteResponse(action string, kite *models.Kite) []byte {
	msg, _ := json.Marshal(createResponse(action, kite))
	return msg // no way that this can produce an error
}

func createResponse(action string, kite *models.Kite) protocol.PubResponse {
	return protocol.PubResponse{
		Base: protocol.Base{
			Username: kite.Username,
			Kitename: kite.Kitename,
			Version:  kite.Version,
			Uuid:     kite.Uuid,
			Token:    kite.Token,
			Hostname: kite.Hostname,
			Addr:     kite.Addr,
			LocalIP:  kite.LocalIP,
			PublicIP: kite.PublicIP,
			Port:     kite.Port,
		},
		Action: action,
	}
}

// Notifies all kites that depends on source kite, it may be kites of the same
// type (they have the same name) or kites that depens on it (like calles,
// clients or other kites of other types)
func (k *Kontrol) NotifyDependencies(kite *models.Kite) {
	// notify kites of the same type
	for _, r := range storage.List() {
		if r.Kitename == kite.Kitename && r.Uuid != kite.Uuid {
			// send other kites to me
			k.Publish(kite.Uuid, createByteResponse(protocol.AddKite, r))

			// and then send myself to other kites. but don't send to
			// kite.Kitename, because it would send it again to me.
			k.Publish(r.Uuid, createByteResponse(protocol.AddKite, kite))
		}
	}

	// notify myself to kites that depends on me
	for _, c := range k.getRelationship(kite.Kitename) {
		k.Publish(c.Uuid, createByteResponse(protocol.AddKite, kite))
	}
}

func (k *Kontrol) Publish(filter string, msg []byte) {
	msg = []byte(filter + protocol.FRAME_SEPARATOR + string(msg))
	k.Publisher.SendBytes(msg, 0)
}

// RegisterKite returns true if the specified kite has been seen before.
// If not, it first validates the kites. If the kite has permission to run, it
// creates a new struct, stores it and returns it.
func (k *Kontrol) RegisterKite(req *protocol.Request) (*models.Kite, error) {
	kite := storage.Get(req.Uuid)
	if kite == nil {
		// in the future we'll check other things too, for now just make sure that
		// the variables are not empty
		if req.Kitename == "" && req.Version == "" && req.Addr == "" {
			return nil, fmt.Errorf("kite fields are not initialized correctly")
		}

		kite = &models.Kite{
			Base: protocol.Base{
				Username:  req.Username,
				Kitename:  req.Kitename,
				Version:   req.Version,
				PublicKey: req.PublicKey,
				Uuid:      req.Uuid,
				Hostname:  req.Hostname,
				Addr:      req.Addr,
				LocalIP:   req.LocalIP,
				PublicIP:  req.PublicIP,
				Port:      req.Port,
			},
		}

		kodingKey, err := modelhelper.GetKodingKeysByKey(kite.PublicKey)
		if err != nil {
			return nil, fmt.Errorf("register kodingkey err %s", err)
		}

		account, err := modelhelper.GetAccountById(kodingKey.Owner)
		if err != nil {
			return nil, fmt.Errorf("register get user err %s", err)
		}

		startLog := fmt.Sprintf("[%s (%s)] belong to '%s'. ready to go..",
			kite.Kitename,
			kite.Version,
			account.Profile.Nickname,
		)
		slog.Println(startLog)

		// update fields
		kite.Username = account.Profile.Nickname
		kite.Kitename = account.Profile.Nickname + "/" + kite.Kitename
		storage.Add(kite)
	}
	return kite, nil
}

// GetRelationship returns a slice of of kites that has a relationship to kite itself
func (k *Kontrol) getRelationship(kite string) []*models.Kite {
	targetKites := make([]*models.Kite, 0)
	if storage.Size() == 0 {
		return targetKites
	}

	for _, r := range storage.List() {
		for _, target := range dependency.List(kite) {
			if r.Kitename == target {
				targetKites = append(targetKites, r)
			}
		}
	}

	return targetKites
}

func addToProxy(kite *models.Kite) {
	err := utils.IsServerAlive(kite.Addr)
	if err != nil {
		slog.Printf("server not reachable: %s (%s) \n", kite.Addr, err.Error())
	} else {
		slog.Println("checking ok..", kite.Addr)
	}

	err = modelhelper.UpsertKey(
		kite.Username,     // username
		"",                // persistence, empty means disabled
		"",                // loadbalancing mode, empty means direct
		kite.Kitename,     // servicename
		kite.Version,      // key
		kite.Addr,         // host
		"FromKontrolKite", // hostdata
		"",                // rabbitkey, not used currently
	)
	if err != nil {
		slog.Println("err")
	}

}
