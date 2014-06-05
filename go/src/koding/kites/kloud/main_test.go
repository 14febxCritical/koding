package main

import (
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"koding/kites/kloud/eventer"
	"koding/kites/kloud/kloud"
	"koding/kodingkite"
	"koding/tools/config"
	"log"
	"math/rand"
	"os"
	"strconv"
	"sync"
	"testing"
	"time"

	"koding/kites/kloud/kloud/machinestate"

	"github.com/fatih/color"
	"github.com/koding/kite"
	kiteconfig "github.com/koding/kite/config"
	"github.com/koding/kite/protocol"
)

var (
	conf      *kiteconfig.Config
	kloudKite *kodingkite.KodingKite
	kloudRaw  *kloud.Kloud
	remote    *kite.Client
	testuser  string
	storage   kloud.Storage

	flagTestBuilds     = flag.Int("builds", 1, "Number of builds")
	flagTestControl    = flag.Bool("control", false, "Enable control tests too (start/stop/..)")
	flagTestImage      = flag.Bool("image", false, "Create temporary image instead of using default one.")
	flagTestQuery      = flag.String("query", "", "Query as string for controller tests")
	flagTestInstanceId = flag.String("instance", "", "Instance id (such as droplet Id)")
	flagTestUsername   = flag.String("user", "", "Create machines on behalf of this user")

	DIGITALOCEAN_CLIENT_ID = "2d314ba76e8965c451f62d7e6a4bc56f"
	DIGITALOCEAN_API_KEY   = "4c88127b50c0c731aeb5129bdea06deb"

	TestProviderData = map[string]*kloud.MachineData{
		"digitalocean": &kloud.MachineData{
			Provider: "digitalocean",
			Credential: &kloud.Credential{
				Meta: map[string]interface{}{
					"clientId": DIGITALOCEAN_CLIENT_ID,
					"apiKey":   DIGITALOCEAN_API_KEY,
				},
			},
			Machine: &kloud.Machine{
				Provider: "digitalocean",
				Status: struct {
					State      string    `bson:"state"`
					ModifiedAt time.Time `bson:"modifiedAt"`
				}{
					State: machinestate.NotInitialized.String(),
				},
				Meta: map[string]interface{}{
					"type":          "digitalocean",
					"clientId":      DIGITALOCEAN_CLIENT_ID,
					"apiKey":        DIGITALOCEAN_API_KEY,
					"image":         "ubuntu-13-10-x64",
					"region":        "sfo1",
					"size":          "512mb",
					"snapshot_name": "koding-{{timestamp}}",
				},
			},
		},
		"amazon-instance": nil,
		"googlecompute":   nil,
	}
)

func init() {
	flag.Parse()

	testuser = "testuser" // same as in kite.key
	if *flagTestUsername != "" {
		os.Setenv("TESTKEY_USERNAME", *flagTestUsername)
		testuser = *flagTestUsername
	}

	kloudKite = setupKloud()
	go kloudKite.Run()
	<-kloudKite.ServerReadyNotify()

	client := kite.New("client", "0.0.1")
	client.Config = kloudKite.Config.Copy()

	kites, err := client.GetKites(protocol.KontrolQuery{
		Username:    "koding",
		Environment: "vagrant",
		Name:        "kloud",
	})
	if err != nil {
		log.Fatalln(err)
	}

	remote = kites[0]
	if err := remote.Dial(); err != nil {
		log.Fatal(err)
	}

	// To disable packer output, comment it out for debugging
	if !*flagDebug {
		log.SetOutput(ioutil.Discard)
	}

	rand.Seed(time.Now().UTC().UnixNano())
}

// listenEvent calls the event method of kloud with the given arguments until
// the desiredState is received. It times out if the desired state is not
// reached in 5 miunuts.
func listenEvent(args interface{}, desiredState machinestate.State) error {
	tryUntil := time.Now().Add(time.Minute * 10)
	for {
		resp, err := remote.Tell("event", args)
		if err != nil {
			return err
		}

		var event eventer.Event
		if err := resp.Unmarshal(&event); err != nil {
			return err
		}

		fmt.Printf("event %+v\n", event)

		if event.Status == desiredState {
			return nil
		}

		if event.Status == machinestate.Unknown {
			return errors.New(event.Message)
		}

		if time.Now().After(tryUntil) {
			return fmt.Errorf("Timeout while waiting for state %s", desiredState)
		}

		time.Sleep(2 * time.Second)
		continue // still pending
	}

	return nil
}

// build builds a single machine with the given client and data. Use this
// function to invoke concurrent and multiple builds.
func build(i int, client *kite.Client, data *kloud.MachineData) error {
	uniqueId := strconv.FormatInt(time.Now().UTC().UnixNano(), 10)

	imageName := "" // an empty argument causes to use the standard library.
	if *flagTestImage {
		imageName = testuser + "-" + uniqueId + "-" + strconv.Itoa(i)
	}

	instanceName := "testkloud-" + uniqueId + "-" + strconv.Itoa(i)

	testlog := func(msg string, args ...interface{}) {
		// mimick it like packer's own log
		color.Cyan("==> %s: %s", data.Provider, fmt.Sprintf(msg, args...))
	}

	bArgs := &kloud.Controller{
		MachineId:    data.Provider,
		InstanceName: instanceName,
		ImageName:    imageName,
	}

	start := time.Now()
	resp, err := client.Tell("build", bArgs)
	if err != nil {
		return err
	}

	var result kloud.ControlResult
	err = resp.Unmarshal(&result)
	if err != nil {
		return err
	}

	fmt.Printf("result %+v\n", result)

	eArgs := &kloud.EventArgs{
		EventId: bArgs.MachineId,
		Type:    "build",
	}

	if err := listenEvent(eArgs, machinestate.Running); err != nil {
		return err
	}
	testlog("Building the machine. Elapsed time %f seconds", time.Since(start).Seconds())

	if *flagTestControl {
		cArgs := &kloud.Controller{
			MachineId: data.Provider,
		}

		methodPairs := []struct {
			method       string
			desiredState machinestate.State
		}{
			{method: "stop", desiredState: machinestate.Stopped},
			{method: "start", desiredState: machinestate.Running},
			{method: "restart", desiredState: machinestate.Running},
			{method: "destroy", desiredState: machinestate.Terminated},
		}

		// do not change the order
		for _, pair := range methodPairs {
			if _, err := client.Tell(pair.method, cArgs); err != nil {
				return fmt.Errorf("%s: %s", pair.method, err)
			}

			eArgs := &kloud.EventArgs{
				EventId: bArgs.MachineId,
				Type:    pair.method,
			}

			start := time.Now()
			if err := listenEvent(eArgs, pair.desiredState); err != nil {
				return err
			}
			testlog("%s finished. Elapsed time %f seconds", pair.method, time.Since(start).Seconds())
		}
	}

	return nil
}

func TestBuild(t *testing.T) {
	numberOfBuilds := *flagTestBuilds

	for provider, data := range TestProviderData {
		if data == nil {
			color.Yellow("==> %s skipping test. test data is not available.", provider)
			continue
		}

		var wg sync.WaitGroup
		for i := 0; i < numberOfBuilds; i++ {
			wg.Add(1)

			go func(i int) {
				defer wg.Done()
				time.Sleep(time.Millisecond * time.Duration(rand.Intn(2500))) // wait 0-2500 milliseconds
				if err := build(i, remote, data); err != nil {
					t.Error(err)
				}
			}(i)
		}

		wg.Wait()
	}
}

func TestRestart(t *testing.T) {
	t.SkipNow()
	if *flagTestQuery == "" {
		t.Fatal("Query is not defined for restart")
	}

	data := TestProviderData["digitalocean"]
	cArgs := &kloud.Controller{
		MachineId: data.Provider,
	}

	kloudRaw.Storage = TestStorageFunc(func(id string, opt *kloud.GetOption) (*kloud.MachineData, error) {
		machineData := TestProviderData[id]
		machineData.Machine.Status.State = machinestate.Running.String() // assume it's running
		machineData.Machine.QueryString = *flagTestQuery
		machineData.Machine.Meta["instanceId"] = *flagTestInstanceId
		return machineData, nil
	})

	if _, err := remote.Tell("restart", cArgs); err != nil {
		t.Errorf("destroy: %s", err)
	}

}

func TestMultiple(t *testing.T) {
	t.Skip("To enable this test remove this line")

	// number of clients that will query example kites
	clientNumber := 10

	fmt.Printf("Creating %d clients\n", clientNumber)

	var cg sync.WaitGroup

	clients := make([]*kite.Client, clientNumber)
	var clientsMu sync.Mutex

	for i := 0; i < clientNumber; i++ {
		cg.Add(1)

		go func(i int) {
			defer cg.Done()

			c := kite.New("client"+strconv.Itoa(i), "0.0.1")

			clientsMu.Lock()
			clientConf := conf.Copy()
			// username := "testuser" + strconv.Itoa(i)
			// clientConf.Username = username
			c.Config = clientConf
			clientsMu.Unlock()

			c.SetupKontrolClient()

			kites, err := c.GetKites(protocol.KontrolQuery{
				Username:    testuser,
				Environment: "vagrant",
				Name:        "kloud",
			})
			if err != nil {
				t.Error(err)
				return
			}

			r := kites[0]

			if err := r.Dial(); err != nil {
				t.Error(err)
			}

			clientsMu.Lock()
			clients[i] = r
			clientsMu.Unlock()
		}(i)

	}

	cg.Wait()

	fmt.Printf("Calling with %d conccurent clients randomly. Starting after 3 seconds ...\n", clientNumber)
	time.Sleep(time.Second * 1)

	var wg sync.WaitGroup

	// every one second
	for i := 0; i < clientNumber; i++ {
		wg.Add(1)

		go func(i int) {
			defer wg.Done()

			time.Sleep(time.Millisecond * time.Duration(rand.Intn(500)))

			for provider, data := range TestProviderData {
				if data == nil {
					color.Yellow("==> %s skipping test. test data is not available.", provider)
					continue
				}

				start := time.Now()

				clientsMu.Lock()
				c := clients[i]
				clientsMu.Unlock()

				err := build(i, c, data)
				elapsedTime := time.Since(start)

				if err != nil {
					fmt.Printf("[%d] aborted, elapsed %f sec err: %s\n",
						i, elapsedTime.Seconds(), err)
				} else {
					fmt.Printf("[%d] finished, elapsed %f sec\n", i, elapsedTime.Seconds())
				}
			}
		}(i)
	}

	wg.Wait()

}

func setupKloud() *kodingkite.KodingKite {
	kloudConf := config.MustConfig("vagrant")

	pubKeyPath := *flagPublicKey
	if *flagPublicKey == "" {
		pubKeyPath = kloudConf.NewKontrol.PublicKeyFile
	}
	pubKey, err := ioutil.ReadFile(pubKeyPath)
	if err != nil {
		log.Fatalln(err)
	}
	publicKey := string(pubKey)

	privKeyPath := *flagPrivateKey
	if *flagPublicKey == "" {
		privKeyPath = kloudConf.NewKontrol.PrivateKeyFile
	}
	privKey, err := ioutil.ReadFile(privKeyPath)
	if err != nil {
		log.Fatalln(err)
	}
	privateKey := string(privKey)

	kloudRaw = &kloud.Kloud{
		Region:            "vagrant",
		Port:              3636,
		Config:            kloudConf,
		Storage:           &TestStorage{},
		KontrolURL:        "wss://kontrol.koding.com",
		KontrolPrivateKey: privateKey,
		KontrolPublicKey:  publicKey,
	}

	kt := kloudRaw.NewKloud()

	return kt
}
