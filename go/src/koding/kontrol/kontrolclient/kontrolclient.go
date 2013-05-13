package main

import (
	"encoding/json"
	"github.com/streadway/amqp"
	"koding/kontrol/helper"
	"koding/kontrol/kontroldaemon/clientconfig"
	"koding/kontrol/kontroldaemon/workerconfig"
	"koding/tools/process"
	"log"
)

func init() {
	log.SetPrefix("kontrold-client ")
}

var producer *helper.Producer

func main() {
	var err error
	producer, err = helper.CreateProducer("client")
	if err != nil {
		log.Fatalf(err.Error())
	}

	data, err := gatherData()
	if err != nil {
		log.Fatalf(err.Error())
	}

	deliver(data)
}

func gatherData() ([]byte, error) {
	log.Println("gathering information...")
	buildNumber := helper.ReadVersion()
	configused := helper.ReadConfigname()
	gitbranch := helper.ReadGitbranch()
	publicHostname := helper.CustomHostname()

	localHostname, err := process.RunCmd("ec2metadata", "--local-hostname")
	if err != nil {
		log.Println(err.Error())
	}

	publicIP, err := process.RunCmd("ec2metadata", "--public-ipv4")
	if err != nil {
		log.Println(err.Error())
	}

	localIp, err := process.RunCmd("ec2metadata", "--local-ipv4")
	if err != nil {
		log.Println(err.Error())
	}

	configJSON, err := process.RunCmd("node", "-e", "require('koding-config-manager').printJson('main."+configused+"')")
	if err != nil {
		log.Println(err.Error())
	}

	config := &clientconfig.ConfigFile{}
	err = json.Unmarshal(configJSON, &config)
	if err != nil {
		log.Fatalf("Could not unmarshal configuration: %s\nConfiguration source output:\n%s\n", err.Error(), configJSON)
	}

	s := &clientconfig.ServerInfo{
		BuildNumber: buildNumber,
		GitBranch:   gitbranch,
		ConfigUsed:  configused,
		Config:      config,
		Hostname: clientconfig.Hostname{
			Public: publicHostname,
			Local:  string(localHostname),
		},
		IP: clientconfig.IP{
			Public: string(publicIP),
			Local:  string(localIp),
		},
	}

	data, err := json.Marshal(s)
	if err != nil {
		log.Println(err.Error())
	}

	log.Println(".. I'm done")
	log.Println("Data is: ", string(data))

	return data, nil
}

func startConsuming() {
	connection := helper.CreateAmqpConnection()
	channel := helper.CreateChannel(connection)

	err := channel.ExchangeDeclare("clientExchange", "fanout", true, false, false, false, nil)
	if err != nil {
		log.Fatal("info exchange.declare: %s", err)
	}

	if _, err := channel.QueueDeclare("", false, true, false, false, nil); err != nil {
		log.Fatal("clientProducer queue.declare: %s", err)
	}

	if err := channel.QueueBind("", "", "clientExchange", false, nil); err != nil {
		log.Fatal("clientProducer queue.bind: %s", err)
	}

	stream, err := channel.Consume("", "", true, false, false, false, nil)
	if err != nil {
		log.Fatal("clientProducer basic.consume: %s", err)
	}

	log.Println("starting to listen for requests...")
	for d := range stream {
		log.Printf("handle got %dB message data: [%v] %s %s",
			len(d.Body),
			d.DeliveryTag,
			d.Body,
			d.AppId)

		var req workerconfig.ClientRequest
		err := json.Unmarshal(d.Body, &req)
		if err != nil {
			log.Print("bad json incoming msg: ", err)
		}

		matchAction(req.Action, req.Cmd, req.Hostname, req.Pid)

	}
}

func matchAction(action, cmd, hostname string, pid int) {
	funcs := map[string]func(cmd, hostname string, pid int) error{
		"start": start,
		"check": check,
		"kill":  kill,
		"stop":  stop,
	}

	if hostname != "" && hostname != helper.CustomHostname() {
		log.Println("command is for a different machine")
		return
	}

	if pid == 0 && action != "start" {
		log.Println("please provide pid number for '%s'", action)
	}

	err := funcs[action](cmd, hostname, pid)
	if err != nil {
		log.Println("call function err", err)
	}

}

func start(cmd, hostname string, pid int) error {
	log.Printf("trying to start command '%s'", cmd)

	_, err := process.RunCmd(cmd)
	if err != nil {
		return err
	}

	log.Printf("cmd '%s' started", cmd)
	return nil
}

func check(cmd, hostname string, pid int) error {
	err := process.CheckPid(pid)
	if err != nil {
		return err
	}

	log.Printf("local process with %s pid is alive", pid)
	return nil
}

func kill(cmd, hostname string, pid int) error {
	err := process.KillCmd(pid)
	if err != nil {
		return err
	}

	log.Printf("local process with %s pid is killed", pid)
	return nil
}

func stop(cmd, hostname string, pid int) error {
	err := process.StopPid(pid)
	if err != nil {
		return err
	}

	log.Printf("local process with %s pid is get SIGSTOP", pid)
	return nil
}

func deliver(data []byte) {
	msg := amqp.Publishing{
		Headers:         amqp.Table{},
		ContentType:     "text/plain",
		ContentEncoding: "",
		Body:            data,
		DeliveryMode:    1, // 1=non-persistent, 2=persistent
	}

	err := producer.Channel.Publish("clientExchange", "kontrol-client", false, false, msg)
	if err != nil {
		log.Printf("error while publishing client message: %s", err)
	}
}
