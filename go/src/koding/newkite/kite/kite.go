package kite

import (
	"flag"
	"fmt"
	"github.com/op/go-logging"
	"koding/newkite/dnode/rpc"
	"koding/newkite/protocol"
	"koding/newkite/utils"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"time"
)

// Debugging helper.
func init() {
	// Print stacktrace on SIGUSR1.
	c := make(chan os.Signal)
	signal.Notify(c, syscall.SIGUSR1)
	go func() {
		for {
			s := <-c
			fmt.Println("Got signal:", s)
			buf := make([]byte, 1<<16)
			runtime.Stack(buf, true)
			fmt.Println(string(buf))
			fmt.Println("Number of goroutines:", runtime.NumGoroutine())
		}
	}()
}

// Kite defines a single process that enables distributed service messaging
// amongst the peers it is connected. A Kite process acts as a Client and as a
// Server. That means it can receive request, process them, but it also can
// make request to other kites. A Kite can be anything. It can be simple Image
// processing kite (which would process data), it could be a Chat kite that
// enables peer-to-peer chat. For examples we have FileSystem kite that expose
// the file system to a client, which in order build the filetree.
type Kite struct {
	protocol.Kite

	// KodingKey is used for authenticate to Kontrol.
	KodingKey string

	// Is this Kite Public or Private? Default is Private.
	Visibility protocol.Visibility

	// Points to the Kontrol instance if enabled
	Kontrol *Kontrol

	// Wheter we want to connect to Kontrol on startup, true by default.
	KontrolEnabled bool

	// Wheter we want to register our Kite to Kontrol, true by default.
	RegisterToKontrol bool

	// method map for exported methods
	handlers map[string]HandlerFunc

	// Dnode rpc server
	server *rpc.Server

	// Handlers to call when a Kite opens a connection to this Kite.
	onConnectHandlers []func(*RemoteKite)

	// Handlers to call when a client has disconnected.
	onDisconnectHandlers []func(*RemoteKite)

	// Contains different functions for authenticating user from request.
	// Keys are the authentication types (options.authentication.type).
	Authenticators map[string]func(*Request) error

	// Used to signal if the kite is ready to start and make calls to
	// other kites.
	ready chan bool

	// Prints logging messages to stderr and syslog.
	Log *logging.Logger
}

// New creates, initialize and then returns a new Kite instance. It accepts
// a single options argument that is a config struct that needs to be filled
// with several informations like Name, Port, IP and so on.
func New(options *Options) *Kite {
	var err error
	if options == nil {
		options, err = ReadKiteOptions("manifest.json")
		if err != nil {
			log.Fatal("error: could not read config file", err)
		}
	}

	options.validate() // exits if validating fails

	hostname, _ := os.Hostname()
	kiteID := utils.GenerateUUID()
	kodingKey, err := utils.GetKodingKey()
	if err != nil {
		log.Fatal("Couldn't find koding.key. Please run 'kd register'.")
	}

	k := &Kite{
		Kite: protocol.Kite{
			Name:        options.Kitename,
			Username:    options.Username,
			ID:          kiteID,
			Version:     options.Version,
			Hostname:    hostname,
			Port:        options.Port,
			Environment: options.Environment,
			Region:      options.Region,
			Visibility:  options.Visibility,

			// PublicIP will be set by Kontrol after registering if it is not set.
			PublicIP: options.PublicIP,
		},
		KodingKey:         kodingKey,
		server:            rpc.NewServer(),
		KontrolEnabled:    true,
		RegisterToKontrol: true,
		Authenticators:    make(map[string]func(*Request) error),
		handlers:          make(map[string]HandlerFunc),
		ready:             make(chan bool),
	}

	k.Log = newLogger(k.Name, k.hasDebugFlag())
	k.Kontrol = k.NewKontrol(options.KontrolAddr)

	// Call registered handlers when a client has disconnected.
	k.server.OnDisconnect(func(c *rpc.Client) {
		if r, ok := c.Properties()["remoteKite"]; ok {
			// Run OnDisconnect handlers.
			k.notifyRemoteKiteDisconnected(r.(*RemoteKite))
		}
	})

	// Every kite should be able to authenticate the user from token.
	k.Authenticators["token"] = k.AuthenticateFromToken
	// A kite accepts requests from Kontrol.
	k.Authenticators["kodingKey"] = k.AuthenticateFromKodingKey

	// Register our internal methods
	k.HandleFunc("systemInfo", new(Status).Info)
	k.HandleFunc("heartbeat", k.handleHeartbeat)
	k.HandleFunc("log", k.handleLog)

	return k
}

// Run is a blocking method. It runs the kite server and then accepts requests
// asynchronously.
func (k *Kite) Run() {
	k.Start()
	select {}
}

// Start is like Run(), but does not wait for it to complete. It's nonblocking.
func (k *Kite) Start() {
	k.parseVersionFlag()

	go func() {
		err := k.listenAndServe()
		if err != nil {
			k.Log.Fatal(err)
		}
	}()

	<-k.ready // wait until we are ready
}

func (k *Kite) handleHeartbeat(r *Request) (interface{}, error) {
	args := r.Args.MustSliceOfLength(2)
	seconds := args[0].MustFloat64()
	ping := args[1].MustFunction()

	go func() {
		for {
			time.Sleep(time.Duration(seconds) * time.Second)
			if ping() != nil {
				return
			}
		}
	}()

	return nil, nil
}

// handleLog prints a log message to stdout.
func (k *Kite) handleLog(r *Request) (interface{}, error) {
	msg := r.Args.MustString()
	k.Log.Info(fmt.Sprintf("%s: %s", r.RemoteKite.Name, msg))
	return nil, nil
}

func init() {
	// These logging related stuff needs to be called once because stupid
	// logging library uses global variables and resets the backends every time.
	logging.SetFormatter(logging.MustStringFormatter("%{level:-8s} ▶ %{message}"))
	stderrBackend := logging.NewLogBackend(os.Stderr, "", log.LstdFlags)
	stderrBackend.Color = true
	syslogBackend, _ := logging.NewSyslogBackend("")
	logging.SetBackend(stderrBackend, syslogBackend)
}

// newLogger returns a new logger object for desired name and level.
func newLogger(name string, debug bool) *logging.Logger {
	logger := logging.MustGetLogger(name)

	level := logging.INFO
	if debug {
		level = logging.DEBUG
	}

	logging.SetLevel(level, name)
	return logger
}

// If the user wants to call flag.Parse() the flag must be defined in advance.
var _ = flag.Bool("version", false, "show version")
var _ = flag.Bool("debug", false, "print debug logs")

// parseVersionFlag prints the version number of the kite and exits with 0
// if "-version" flag is enabled.
// We did not use the "flag" package because it causes trouble if the user
// also calls "flag.Parse()" in his code. flag.Parse() can be called only once.
func (k *Kite) parseVersionFlag() {
	for _, flag := range os.Args {
		if flag == "-version" {
			fmt.Println(k.Version)
			os.Exit(0)
		}
	}
}

// hasDebugFlag returns true if -debug flag is present in os.Args.
func (k *Kite) hasDebugFlag() bool {
	for _, flag := range os.Args {
		if flag == "-debug" {
			return true
		}
	}

	// We can't use flags when running "go test" command.
	// This is another way to print debug logs.
	if os.Getenv("DEBUG") != "" {
		return true
	}

	return false
}

// listenAndServe starts our rpc server with the given addr.
func (k *Kite) listenAndServe() error {
	listener, err := net.Listen("tcp4", ":"+k.Port)
	if err != nil {
		return err
	}

	k.Log.Info("Listening: %s", listener.Addr().String())

	// Port is known here if "0" is used as port number
	_, k.Port, _ = net.SplitHostPort(listener.Addr().String())

	// We must connect to Kontrol after starting to listen on port
	if k.KontrolEnabled {
		if k.RegisterToKontrol {
			k.Kontrol.OnConnect(k.registerToKontrol)
		}

		k.Kontrol.DialForever()
	}

	k.ready <- true // listener is ready, means we are ready too
	return http.Serve(listener, k.server)
}

func (k *Kite) registerToKontrol() {
	err := k.Kontrol.Register()
	if err != nil {
		k.Log.Fatalf("Cannot register to Kontrol: %s", err)
	}
}

// OnConnect registers a function to run when a Kite connects to this Kite.
func (k *Kite) OnConnect(handler func(*RemoteKite)) {
	k.onConnectHandlers = append(k.onConnectHandlers, handler)
}

// OnDisconnect registers a function to run when a connected Kite is disconnected.
func (k *Kite) OnDisconnect(handler func(*RemoteKite)) {
	k.onDisconnectHandlers = append(k.onDisconnectHandlers, handler)
}

// notifyRemoteKiteConnected runs the registered handlers with OnConnect().
func (k *Kite) notifyRemoteKiteConnected(r *RemoteKite) {
	k.Log.Info("Client is connected to us: [%s %s]", r.Name, r.Addr())

	for _, handler := range k.onConnectHandlers {
		go handler(r)
	}
}

func (k *Kite) notifyRemoteKiteDisconnected(r *RemoteKite) {
	k.Log.Info("Client has disconnected: [%s %s]", r.Name, r.Addr())

	for _, handler := range k.onDisconnectHandlers {
		go handler(r)
	}
}
