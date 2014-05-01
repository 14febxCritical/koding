package main

import (
	"flag"
	"fmt"
	"github.com/koding/worker"
	"socialapi/config"
	"socialapi/workers/followingfeed/followingfeed"
	"socialapi/workers/helper"
)

var (
	flagConfFile = flag.String("c", "", "Configuration profile from file")
	flagDebug    = flag.Bool("d", false, "Debug mode")
)

func main() {
	flag.Parse()
	if *flagConfFile == "" {
		fmt.Println("Please define config file with -c", "Exiting...")
		return
	}

	conf := config.MustRead(*flagConfFile)

	// create logger for our package
	log := helper.CreateLogger("FollowingFeedWorker", *flagDebug)

	// panics if not successful
	bongo := helper.MustInitBongo(conf, log)
	// do not forgot to close the bongo connection
	defer bongo.Close()

	// create message handler
	handler := followingfeed.NewFollowingFeedController(log)

	listener := worker.NewListener("FollowingFeed", conf.EventExchangeName, log)
	// blocking
	// listen for events
	listener.Listen(helper.NewRabbitMQ(conf, log), handler)
	// close consumer
	defer listener.Close()
}
