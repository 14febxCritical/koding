package main

import (
	"flag"
	"io/ioutil"
	"koding/tools/config"
	"log"

	kiteconfig "github.com/koding/kite/config"
	"github.com/koding/kite/proxy"
)

func main() {
	var (
		profile    = flag.String("c", "", "Configuration profile")
		ip         = flag.String("ip", "0.0.0.0", "")
		port       = flag.Int("port", 3999, "")
		publicHost = flag.String("public-host", "127.0.0.1:3999", "")
		region     = flag.String("r", "", "Region")
	)

	flag.Parse()

	conf := config.MustConfig(*profile)

	publicKey, err := ioutil.ReadFile(conf.NewKontrol.PublicKeyFile)
	if err != nil {
		log.Fatalln("cannot read public key file")
	}

	privateKey, err := ioutil.ReadFile(conf.NewKontrol.PrivateKeyFile)
	if err != nil {
		log.Fatalln("cannot read private key file")
	}

	kiteConf := kiteconfig.MustGet()
	kiteConf.Environment = conf.Environment
	kiteConf.Region = *region
	kiteConf.IP = *ip
	kiteConf.Port = *port

	p := proxy.New(kiteConf, string(publicKey), string(privateKey))
	p.PublicHost = *publicHost

	p.Run()
}
