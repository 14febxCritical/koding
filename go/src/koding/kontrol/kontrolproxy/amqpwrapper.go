package main

import (
	"github.com/streadway/amqp"
	"koding/kontrol/helper"
)

type AmqpStream struct {
	channel *amqp.Channel
	input   <-chan amqp.Delivery
	uuid    string
}

func setupAmqp() *AmqpStream {
	appId := helper.CustomHostname()
	connection := helper.CreateAmqpConnection()
	channel := helper.CreateChannel(connection)
	stream := helper.CreateStream(channel, "topic", "infoExchange", "proxy-handler-"+appId, "output.proxy."+appId, true, false)

	return &AmqpStream{
		channel: channel,
		input:   stream,
		uuid:    appId,
	}
}

func (a *AmqpStream) Publish(exchange, routingKey string, data []byte) {
	appId := helper.CustomHostname()
	msg := amqp.Publishing{
		Headers:         amqp.Table{},
		ContentType:     "text/plain",
		ContentEncoding: "",
		Body:            data,
		DeliveryMode:    1, // 1=non-persistent, 2=persistent
		AppId:           appId,
	}

	a.channel.Publish(exchange, routingKey, false, false, msg)
}
