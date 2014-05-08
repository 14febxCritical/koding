package main

import (
	"flag"
	"fmt"
	"koding/db/mongodb/modelhelper"
	"socialapi/config"
	"socialapi/workers/helper"
	"socialapi/workers/realtime/realtime"

	"github.com/koding/worker"
)

var (
	flagConfFile = flag.String("c", "", "Configuration profile from file")
	flagDebug    = flag.Bool("d", false, "Debug mode")
	Name         = "Realtime"
)

func main() {
	flag.Parse()
	if *flagConfFile == "" {
		fmt.Println("Please define config file with -c", "Exiting...")
		return
	}

	conf := config.MustRead(*flagConfFile)

	// create logger for our package
	log := helper.CreateLogger(Name, *flagDebug)

	// panics if not successful
	bongo := helper.MustInitBongo(Name, conf, log)
	// do not forgot to close the bongo connection
	defer bongo.Close()

	// init mongo connection
	modelhelper.Initialize(conf.Mongo)

	//create connection to RMQ for publishing realtime events
	rmq := helper.NewRabbitMQ(conf, log)

	handler, err := realtime.NewRealtimeWorkerController(rmq, log)
	if err != nil {
		panic(err)
	}

	listener := worker.NewListener(Name, conf.EventExchangeName, log)
	// blocking
	// listen for events
	listener.Listen(rmq, handler)
	// close consumer
	defer listener.Close()
}
