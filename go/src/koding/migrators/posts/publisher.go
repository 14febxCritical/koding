package main

import (
	"encoding/json"
	"github.com/streadway/amqp"
	"koding/messaging/rabbitmq"
)

var (
	Producer *rabbitmq.Producer
	Consumer *rabbitmq.Consumer
)

func initPublisher() {
	exchange := rabbitmq.Exchange{
		Name:    "MigratorExchange",
		Type:    "fanout",
		Durable: true,
	}

	queue := rabbitmq.Queue{
		Name:    "MigratorQueue",
		Durable: true,
	}

	binding := rabbitmq.BindingOptions{
		RoutingKey: "",
	}

	consumerOptions := rabbitmq.ConsumerOptions{
		Tag: "Migrator",
	}

	//used for creating exchange/queue. it would be much better if there is another solution
	var err error
	Consumer, err = rabbitmq.NewConsumer(exchange, queue, binding, consumerOptions)
	if err != nil {
		panic(err)
	}

	err = Consumer.QOS(3)
	if err != nil {
		panic(err)
	}

	publishingOptions := rabbitmq.PublishingOptions{
		Tag:        "Migrator",
		RoutingKey: "",
	}

	Producer, err = rabbitmq.NewProducer(exchange, queue, publishingOptions)
	if err != nil {
		panic(err)
	}
}

func publish(data interface{}) error {
	neoMessage, err := json.Marshal(data)
	if err != nil {
		log.Error("marshall error - %v", err)
		return err
	}

	message := amqp.Publishing{
		Body: neoMessage,
	}

	Producer.NotifyReturn(func(message amqp.Return) {
		log.Info("%v", message)
	})

	return Producer.Publish(message)
}

func shutdown() {
	Producer.Shutdown()
	Consumer.Shutdown()
}
