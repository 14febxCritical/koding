package fastproxy

import (
	"bufio"
	"bytes"
	"crypto/tls"
	"errors"
	"io"
	"net"
	"strconv"
)

type FTPRequest struct {
	User      string
	privateIP net.IP
	publicIP  net.IP
	source    net.Conn
	buffer    *bytes.Buffer
}

func ListenFTP(privateAddr *net.TCPAddr, publicIP net.IP, cert *tls.Certificate, handler func(*FTPRequest)) error {
	return listen(privateAddr, cert, func(source net.Conn) {
		defer source.Close()
		req := FTPRequest{
			privateIP: privateAddr.IP,
			publicIP:  publicIP,
			source:    source,
			buffer:    bytes.NewBuffer(nil),
		}

		source.Write([]byte("220 Welcome to Koding!\r\n"))

		r := bufio.NewReaderSize(source, 128)
		line, err := r.ReadSlice('\n')
		if err != nil {
			return
		}

		if !bytes.HasPrefix(line, []byte("USER ")) {
			source.Write([]byte("500 Syntax error.\r\n"))
			return
		}
		req.User = string(bytes.TrimSpace(line[5:]))
		req.buffer.Next(len(line)) // USER line will be sent by FTPRequest.Relay

		handler(&req)
	})
}

func btoi(b byte) string {
	return strconv.Itoa(int(b))
}

func (req *FTPRequest) Relay(addr *net.TCPAddr, user string) error {
	target, err := connect(addr)
	if err != nil {
		return err
	}
	defer target.Close()

	targetReader := bufio.NewReaderSize(target, 128)

	// skip welcome lines
	for {
		line, err := targetReader.ReadSlice('\n')
		if err != nil {
			return err
		}
		if !bytes.HasPrefix(line, []byte("220")) {
			return errors.New("Invalid server response.")
		}

		if line[3] != '-' {
			break
		}
	}

	target.Write([]byte("USER " + user + "\n"))
	target.Write(req.buffer.Bytes())
	passiveAddress := make(chan *net.TCPAddr)
	defer close(passiveAddress)
	go func() {
		defer target.CloseWrite()
		for {
			sourceReader := bufio.NewReader(req.source)
			line, readErr := sourceReader.ReadSlice('\n')
			if bytes.HasPrefix(line, []byte("PASV")) {
				target.Write([]byte("PASV\r\n"))
				targetConn, err := net.DialTCP("tcp", nil, <-passiveAddress)
				if err != nil {
					return
				}

				sourceListener, err := net.ListenTCP("tcp", &net.TCPAddr{IP: req.privateIP})
				if err != nil {
					return
				}
				ip := req.publicIP.To4()
				port := sourceListener.Addr().(*net.TCPAddr).Port
				commaSeparatedAddress := btoi(ip[0]) + "," + btoi(ip[1]) + "," + btoi(ip[2]) + "," + btoi(ip[3]) + "," + btoi(byte(port>>8)) + "," + btoi(byte(port))
				req.source.Write([]byte("227 Entering Passive Mode (" + commaSeparatedAddress + ").\r\n"))

				sourceConn, err := sourceListener.AcceptTCP()
				if err != nil {
					return
				}

				go func() {
					io.Copy(sourceConn, targetConn)
					targetConn.CloseRead()
					sourceConn.CloseWrite()
				}()
				go func() {
					io.Copy(targetConn, sourceConn)
					sourceConn.CloseRead()
					targetConn.CloseWrite()
				}()

				continue
			}
			_, writeErr := target.Write(line)
			if readErr != nil || writeErr != nil {
				return
			}
		}
	}()
	for {
		line, readErr := targetReader.ReadSlice('\n')
		if bytes.HasPrefix(line, []byte("227")) {
			start := bytes.IndexByte(line, '(') + 1
			end := bytes.IndexByte(line, ')')
			parts := bytes.Split(line[start:end], []byte{','})
			passiveAddress <- &net.TCPAddr{IP: net.IPv4(parseByte(parts[0]), parseByte(parts[1]), parseByte(parts[2]), parseByte(parts[3])), Port: int(parseByte(parts[4]))<<8 + int(parseByte(parts[5]))}
			continue
		}
		_, writeErr := req.source.Write(line)
		if readErr != nil || writeErr != nil {
			break
		}
	}

	return nil
}

func parseByte(s []byte) byte {
	b, _ := strconv.Atoi(string(s))
	return byte(b)
}

func (req *FTPRequest) Respond(data string) {
	req.source.Write([]byte(data))
}
