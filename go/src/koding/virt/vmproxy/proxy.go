package main

import (
	"koding/tools/db"
	"koding/tools/fastproxy"
	"koding/tools/lifecycle"
	"koding/tools/log"
	"koding/virt"
	"labix.org/v2/mgo/bson"
	"net"
	"strings"
)

func main() {
	lifecycle.Startup("proxy", true)

	// go fastproxy.ListenFTP(&net.TCPAddr{IP: net.IPv4(10, 0, 2, 15), Port: 21}, net.IPv4(10, 0, 2, 15), nil, func(req *fastproxy.FTPRequest) {
	// 	defer log.RecoverAndLog()

	// 	userName := req.User
	// 	vmName := req.User
	// 	if userParts := strings.SplitN(userName, "@", 2); len(userParts) == 2 {
	// 		userName = userParts[0]
	// 		vmName = userParts[1]
	// 	}

	// 	var vm virt.VM
	// 	if err := db.VMs.Find(bson.M{"name": vmName}).One(&vm); err != nil {
	// 		req.Respond("530 No Koding VM with name '" + vmName + "' found.\r\n")
	// 		return
	// 	}

	// 	if err := req.Relay(&net.TCPAddr{IP: vm.IP, Port: 21}, userName); err != nil {
	// 		req.Respond("530 The Koding VM '" + vmName + "' did not respond.")
	// 	}
	// })

	fastproxy.ListenHTTP(&net.TCPAddr{IP: nil, Port: 3021}, nil, false, func(req *fastproxy.HTTPRequest) {
		defer log.RecoverAndLog()

		vmName := strings.SplitN(req.Host, ".", 2)[0]

		var vm virt.VM
		if err := db.VMs.Find(bson.M{"name": vmName}).One(&vm); err != nil {
			req.Redirect("http://www.koding.com/notfound.html")
			return
		}

		if vm.IP == nil {
			req.Redirect("http://www.koding.com/notactive.html")
			return
		}

		if err := req.Relay(&net.TCPAddr{IP: vm.IP, Port: 80}); err != nil {
			req.Redirect("http://www.koding.com/notactive.html")
		}
	})
}
