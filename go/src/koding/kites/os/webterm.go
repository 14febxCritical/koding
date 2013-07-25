package main

import (
	"bytes"
	"koding/tools/dnode"
	"koding/tools/kite"
	"koding/tools/log"
	"koding/tools/pty"
	"koding/tools/utils"
	"koding/virt"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unicode/utf8"
)

type WebtermServer struct {
	Session          string `json:"session"`
	remote           WebtermRemote
	vm               *virt.VM
	user             *virt.User
	isForeignSession bool
	pty              *pty.PTY
	currentSecond    int64
	messageCounter   int
	byteCounter      int
	lineFeeedCounter int
}

type WebtermRemote struct {
	Output       dnode.Callback
	SessionEnded dnode.Callback
}

func registerWebtermMethods(k *kite.Kite) {
	registerVmMethod(k, "webterm.getSessions", false, func(args *dnode.Partial, channel *kite.Channel, vos *virt.VOS) (interface{}, error) {
		// We need to use ls here, because /var/run/screen mount is only visible from inside of container. Errors are ignored.
		out, _ := vos.VM.AttachCommand(vos.User.Uid, "", "ls", "/var/run/screen/S-"+vos.User.Name).Output()
		names := strings.Split(string(out[:len(out)-1]), "\n")
		sessions := make([]string, len(names))
		for i, name := range names {
			segements := strings.SplitN(name, ".", 2)
			sessions[i] = segements[1]
		}
		return sessions, nil
	})

	// this method is special cased in oskite.go to allow foreign access
	registerVmMethod(k, "webterm.connect", false, func(args *dnode.Partial, channel *kite.Channel, vos *virt.VOS) (interface{}, error) {
		var params struct {
			Remote       WebtermRemote
			Session      string
			SizeX, SizeY int
		}
		if args.Unmarshal(&params) != nil || params.SizeX <= 0 || params.SizeY <= 0 {
			return nil, &kite.ArgumentError{Expected: "{ remote: [object], session: [string], sizeX: [integer], sizeY: [integer] }"}
		}

		newSession := false
		if params.Session == "" {
			params.Session = utils.RandomString()
			newSession = true
		}

		server := &WebtermServer{
			Session:          params.Session,
			remote:           params.Remote,
			vm:               vos.VM,
			user:             vos.User,
			isForeignSession: vos.User.Name != channel.Username,
			pty:              pty.New(vos.VM.PtsDir()),
		}
		server.SetSize(float64(params.SizeX), float64(params.SizeY))

		cmdArgs := []string{"/usr/bin/screen", "-e^Bb", "-S", "koding." + params.Session}
		if !newSession {
			cmdArgs = append(cmdArgs, "-x")
		}
		server.pty.Slave.Chown(vos.User.Uid, -1)
		cmd := vos.VM.AttachCommand(vos.User.Uid, "/dev/pts/"+strconv.Itoa(server.pty.No), cmdArgs...)

		err := cmd.Start()
		if err != nil {
			panic(err)
		}

		go func() {
			defer log.RecoverAndLog()

			cmd.Wait()
			server.pty.Slave.Close()
			server.pty.Master.Close()
			server.remote.SessionEnded()
		}()

		go func() {
			defer log.RecoverAndLog()

			buf := make([]byte, (1<<12)-utf8.UTFMax, 1<<12)
			for {
				n, err := server.pty.Master.Read(buf)
				for n < cap(buf)-1 {
					r, _ := utf8.DecodeLastRune(buf[:n])
					if r != utf8.RuneError {
						break
					}
					server.pty.Master.Read(buf[n : n+1])
					n++
				}

				s := time.Now().Unix()
				if server.currentSecond != s {
					server.currentSecond = s
					server.messageCounter = 0
					server.byteCounter = 0
					server.lineFeeedCounter = 0
				}
				server.messageCounter += 1
				server.byteCounter += n
				server.lineFeeedCounter += bytes.Count(buf[:n], []byte{'\n'})
				if server.messageCounter > 100 || server.byteCounter > 1<<18 || server.lineFeeedCounter > 300 {
					time.Sleep(time.Second)
				}

				server.remote.Output(string(utils.FilterInvalidUTF8(buf[:n])))
				if err != nil {
					break
				}
			}
		}()

		channel.OnDisconnect(func() { server.Close() })

		return server, nil
	})
}

func (server *WebtermServer) Input(data string) {
	server.pty.Master.Write([]byte(data))
}

func (server *WebtermServer) ControlSequence(data string) {
	server.pty.MasterEncoded.Write([]byte(data))
}

func (server *WebtermServer) SetSize(x, y float64) {
	server.pty.SetSize(uint16(x), uint16(y))
}

func (server *WebtermServer) Close() error {
	server.pty.Signal(syscall.SIGHUP)
	return nil
}

func (server *WebtermServer) Terminate() error {
	server.Close()
	if !server.isForeignSession {
		server.vm.AttachCommand(server.user.Uid, "", "/usr/bin/screen", "-S", "koding."+server.Session, "-X", "quit").Run()
	}
	return nil
}
