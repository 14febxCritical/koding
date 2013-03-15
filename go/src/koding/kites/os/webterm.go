package main

import (
	"bytes"
	"koding/tools/dnode"
	"koding/tools/log"
	"koding/tools/pty"
	"koding/tools/utils"
	"koding/virt"
	"strconv"
	"syscall"
	"time"
	"unicode/utf8"
)

type WebtermServer struct {
	remote           WebtermRemote
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

func newWebtermServer(vm *virt.VM, user *virt.User, remote WebtermRemote, args []string, sizeX, sizeY int) *WebtermServer {
	server := &WebtermServer{
		remote: remote,
		pty:    pty.New(vm.PtsDir()),
	}
	server.SetSize(float64(sizeX), float64(sizeY))

	server.pty.Slave.Chown(user.Uid, -1)
	cmd := vm.AttachCommand(user.Uid, "/dev/pts/"+strconv.Itoa(server.pty.No)) // empty command is default shell

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

	return server
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
