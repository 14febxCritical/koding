package main

import (
	"flag"
	"fmt"

	"socialapi/config"
	"socialapi/workers/helper"
	"socialapi/workers/populartopic/populartopic"
	"github.com/koding/redis"
	"github.com/koding/worker"
)

var (
	flagProfile = flag.String("c", "", "Configuration profile from file")
	flagDebug   = flag.Bool("d", false, "Debug mode")
)

func main() {
	flag.Parse()
	if *flagProfile == "" {
		fmt.Println("Please define config file with -c", "Exiting...")
		return
	}

	conf := config.MustRead(*flagProfile)

	// create logger for our package
	log := helper.CreateLogger("PopularTopicsWorker", *flagDebug)

	// panics if not successful
	bongo := helper.MustInitBongo(conf, log)
	// do not forgot to close the bongo connection
	defer bongo.Close()

	redis, err := redis.NewRedisSession(conf.Redis)
	if err != nil {
		log.Error(err.Error())
		return
	}

	// create message handler
	handler := populartopic.NewPopularTopicsController(log, redis)

	listener := worker.NewListener("PopularTopicsFeed", conf.EventExchangeName, log)
	// blocking
	// listen for events
	listener.Listen(helper.NewRabbitMQ(conf, log), handler)
	// close consumer
	defer listener.Close()
}
