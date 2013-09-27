package main

import (
	"errors"
	"koding/newkite/kite"
	"koding/newkite/protocol"
)

type Sample struct {
}

func main() {
	o := &protocol.Options{
		Username: "huseyin",
		Kitename: "fs-local",
		Version:  "1",
		Port:     "4005",
	}

	methods := map[string]interface{}{
		"sample.hello": Sample.Hello,
	}

	s := &Sample{}

	k := kite.New(o, s, methods)
	k.Start()
}

func (s Sample) Hello(r *protocol.KiteDnodeRequest, result *string) error {
	var params struct {
		Name string
	}
	if r.Args.Unmarshal(&params) != nil || params.Name == "" {
		return errors.New("{ name: [string] }")
	}

	*result = "Hello " + params.Name
	return nil
}
