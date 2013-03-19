package main

import (
	"koding/tools/config"
	"koding/tools/db"
	"koding/tools/dnode"
	"koding/tools/kite"
	"koding/tools/lifecycle"
	"koding/tools/log"
	"koding/tools/utils"
	"koding/virt"
	"labix.org/v2/mgo/bson"
	"net"
	"os"
	"path"
	"strconv"
	"strings"
	"sync"
	"time"
)

type VMInfo struct {
	vmId          bson.ObjectId
	sessions      map[*kite.Session]bool
	timeout       *time.Timer
	totalCpuUsage int

	State       string `json:"state"`
	CpuUsage    int    `json:"cpuUsage"`
	CpuShares   int    `json:"cpuShares"`
	MemoryUsage int    `json:"memoryUsage"`
	MemoryLimit int    `json:"memoryLimit"`
}

var ipPoolFetch <-chan int
var ipPoolRelease chan<- int
var infos = make(map[bson.ObjectId]*VMInfo)
var infosMutex sync.Mutex

func main() {
	lifecycle.Startup("kite.os", true)
	virt.LoadTemplates(config.Current.ProjectRoot + "/go/templates")

	takenIPs := make([]int, 0)
	iter := db.VMs.Find(bson.M{"ip": bson.M{"$ne": nil}}).Iter()
	var vm virt.VM
	for iter.Next(&vm) {
		switch vm.GetState() {
		case "RUNNING":
			info := newInfo(&vm)
			infos[vm.Id] = info
			info.startTimeout()
			takenIPs = append(takenIPs, utils.IPToInt(vm.IP))
		case "STOPPED":
			vm.Unprepare()
			db.VMs.UpdateId(vm.Id, bson.M{"$set": bson.M{"ip": nil}})
		default:
			panic("Unhandled VM state.")
		}
	}
	if iter.Err() != nil {
		panic(iter.Err())
	}
	ipPoolFetch, ipPoolRelease = utils.NewIntPool(utils.IPToInt(net.IPv4(172, 16, 0, 2)), takenIPs)

	go LimiterLoop()
	k := kite.New("os")

	k.Handle("vm.start", false, func(args *dnode.Partial, session *kite.Session) (interface{}, error) {
		_, vm := findSession(session)
		return vm.Start()
	})

	k.Handle("vm.shutdown", false, func(args *dnode.Partial, session *kite.Session) (interface{}, error) {
		_, vm := findSession(session)
		return vm.Shutdown()
	})

	k.Handle("vm.stop", false, func(args *dnode.Partial, session *kite.Session) (interface{}, error) {
		_, vm := findSession(session)
		return vm.Stop()
	})

	k.Handle("vm.info", false, func(args *dnode.Partial, session *kite.Session) (interface{}, error) {
		_, vm := findSession(session)
		info := infos[vm.Id]
		info.State = vm.GetState()
		return info, nil
	})

	k.Handle("vm.reinitialize", false, func(args *dnode.Partial, session *kite.Session) (interface{}, error) {
		_, vm := findSession(session)
		vm.Prepare(getUsers(vm), true)
		return vm.Start()
	})

	k.Handle("spawn", true, func(args *dnode.Partial, session *kite.Session) (interface{}, error) {
		var command []string
		if args.Unmarshal(&command) != nil {
			return nil, &kite.ArgumentError{Expected: "array of strings"}
		}

		user, vm := findSession(session)
		return vm.AttachCommand(user.Uid, "", command...).CombinedOutput()
	})

	k.Handle("exec", true, func(args *dnode.Partial, session *kite.Session) (interface{}, error) {
		var line string
		if args.Unmarshal(&line) != nil {
			return nil, &kite.ArgumentError{Expected: "string"}
		}

		user, vm := findSession(session)
		return vm.AttachCommand(user.Uid, "", "/bin/bash", "-c", line).CombinedOutput()
	})

	k.Handle("watch", false, func(args *dnode.Partial, session *kite.Session) (interface{}, error) {
		var params struct {
			Path     string         `json:"path"`
			OnChange dnode.Callback `json:"onChange"`
		}
		if args.Unmarshal(&params) != nil || params.OnChange == nil {
			return nil, &kite.ArgumentError{Expected: "{ path: [string], onChange: [function] }"}
		}

		user, vm := findSession(session)
		vmPath := params.Path
		if !path.IsAbs(vmPath) {
			vmPath = "/home/" + user.Name + "/" + vmPath
		}
		fullPath, err := vm.ResolveRootfsFile(vmPath, user)
		if err != nil {
			return nil, err
		}

		watch, err := NewWatch(fullPath, params.OnChange)
		if err != nil {
			return nil, err
		}
		session.OnDisconnect(func() { watch.Close() })

		dir, err := os.Open(fullPath)
		defer dir.Close()
		if err != nil {
			return nil, err
		}

		infos, err := dir.Readdir(0)
		if err != nil {
			return nil, err
		}

		entries := make([]FileEntry, len(infos))
		for i, info := range infos {
			entries[i] = makeFileEntry(info, vmPath+"/"+info.Name())
		}

		return map[string]interface{}{"files": entries, "stopWatching": func() { watch.Close() }}, nil
	})

	k.Handle("webterm.getSessions", false, func(args *dnode.Partial, session *kite.Session) (interface{}, error) {
		user, _ := findSession(session)
		dir, err := os.Open("/var/run/screen/S-" + user.Name)
		if err != nil {
			if os.IsNotExist(err) {
				return make(map[string]string), nil
			}
			panic(err)
		}
		names, err := dir.Readdirnames(0)
		if err != nil {
			panic(err)
		}
		sessions := make(map[string]string)
		for _, name := range names {
			segements := strings.SplitN(name, ".", 2)
			sessions[segements[0]] = segements[1]
		}
		return sessions, nil
	})

	k.Handle("webterm.createSession", false, func(args *dnode.Partial, session *kite.Session) (interface{}, error) {
		var params struct {
			Remote       WebtermRemote
			Name         string
			SizeX, SizeY int
		}
		if args.Unmarshal(&params) != nil || params.Name == "" || params.SizeX <= 0 || params.SizeY <= 0 {
			return nil, &kite.ArgumentError{Expected: "{ remote: [object], name: [string], sizeX: [integer], sizeY: [integer] }"}
		}

		user, vm := findSession(session)
		server := newWebtermServer(vm, user, params.Remote, []string{"-S", params.Name}, params.SizeX, params.SizeY)
		session.OnDisconnect(func() { server.Close() })
		return server, nil
	})

	k.Handle("webterm.joinSession", false, func(args *dnode.Partial, session *kite.Session) (interface{}, error) {
		var params struct {
			Remote       WebtermRemote
			SessionId    int
			SizeX, SizeY int
		}
		if args.Unmarshal(&params) != nil || params.SessionId <= 0 || params.SizeX <= 0 || params.SizeY <= 0 {
			return nil, &kite.ArgumentError{Expected: "{ remote: [object], sessionId: [integer], sizeX: [integer], sizeY: [integer] }"}
		}

		user, vm := findSession(session)
		server := newWebtermServer(vm, user, params.Remote, []string{"-x", strconv.Itoa(int(params.SessionId))}, params.SizeX, params.SizeY)
		session.OnDisconnect(func() { server.Close() })
		return server, nil
	})

	k.Run()
}

func findSession(session *kite.Session) (*virt.User, *virt.VM) {
	var user virt.User
	if err := db.Users.Find(bson.M{"username": session.Username}).One(&user); err != nil {
		panic(err)
	}
	if user.Uid < virt.UserIdOffset {
		panic("User with too low uid.")
	}
	vm := getDefaultVM(&user)

	infosMutex.Lock()
	info, isExistingState := infos[vm.Id]
	if !isExistingState {
		info = newInfo(vm)
		infos[vm.Id] = info
	}
	if !info.sessions[session] {
		info.sessions[session] = true
		if info.timeout != nil {
			info.timeout.Stop()
			info.timeout = nil
		}

		session.OnDisconnect(func() {
			infosMutex.Lock()
			defer infosMutex.Unlock()

			delete(info.sessions, session)
			if len(info.sessions) == 0 {
				info.startTimeout()
			}
		})
	}
	infosMutex.Unlock()

	if !isExistingState {
		ip := utils.IntToIP(<-ipPoolFetch)
		if err := db.VMs.Update(bson.M{"_id": vm.Id, "ip": nil}, bson.M{"$set": bson.M{"ip": ip}}); err != nil {
			panic(err)
		}
		vm.IP = ip

		vm.Prepare(getUsers(vm), false)
		if out, err := vm.Start(); err != nil {
			log.Err("Could not start VM.", err, out)
		}
		if out, err := vm.WaitForState("RUNNING", time.Second); err != nil {
			log.Warn("Waiting for VM startup failed.", err, out)
		}
	}

	return &user, vm
}

func getDefaultVM(user *virt.User) *virt.VM {
	if user.DefaultVM == "" {
		// create new vm
		vm := virt.VM{
			Id:           bson.NewObjectId(),
			Name:         user.Name,
			Users:        []*virt.UserEntry{{Id: user.ObjectId, Sudo: true}},
			LdapPassword: utils.RandomString(),
		}
		if err := db.VMs.Insert(vm); err != nil {
			panic(err)
		}

		if err := db.Users.Update(bson.M{"_id": user.ObjectId, "defaultVM": nil}, bson.M{"$set": bson.M{"defaultVM": vm.Id}}); err != nil {
			panic(err)
		}
		user.DefaultVM = vm.Id

		return &vm
	}

	var vm virt.VM
	if err := db.VMs.FindId(user.DefaultVM).One(&vm); err != nil {
		panic(err)
	}
	return &vm
}

func getUsers(vm *virt.VM) []virt.User {
	users := make([]virt.User, len(vm.Users))
	for i, entry := range vm.Users {
		if err := db.Users.FindId(entry.Id).One(&users[i]); err != nil {
			panic(err)
		}
		if users[i].Uid == 0 {
			panic("User with uid 0.")
		}
	}
	return users
}

func newInfo(vm *virt.VM) *VMInfo {
	return &VMInfo{
		vmId:          vm.Id,
		sessions:      make(map[*kite.Session]bool),
		totalCpuUsage: utils.MaxInt,
		CpuShares:     1000,
	}
}

func (info *VMInfo) startTimeout() {
	info.timeout = time.AfterFunc(10*time.Minute, func() {
		infosMutex.Lock()
		defer infosMutex.Unlock()

		if len(info.sessions) != 0 {
			return
		}

		var vm virt.VM
		if err := db.VMs.FindId(info.vmId).One(&vm); err != nil {
			log.Err("Could not find VM for shutdown.", err)
		}
		if out, err := vm.Shutdown(); err != nil {
			log.Err("Could not shutdown VM.", err, out)
		}

		if err := vm.Unprepare(); err != nil {
			log.Warn(err.Error())
		}
		db.VMs.UpdateId(vm.Id, bson.M{"$set": bson.M{"ip": nil}})
		ipPoolRelease <- utils.IPToInt(vm.IP)
		vm.IP = nil

		delete(infos, vm.Id)
	})
}

type FileEntry struct {
	Name     string      `json:"name"`
	IsDir    bool        `json:"isDir"`
	Size     int64       `json:"size"`
	Mode     os.FileMode `json:"mode"`
	Time     time.Time   `json:"time"`
	IsBroken bool        `json:"isBroken"`
}

func makeFileEntry(info os.FileInfo, p string) FileEntry {
	entry := FileEntry{
		Name:  info.Name(),
		IsDir: info.IsDir(),
		Size:  info.Size(),
		Mode:  info.Mode(),
		Time:  info.ModTime(),
	}

	if info.Mode()&os.ModeSymlink != 0 {
		symlinkInfo, err := os.Stat(p) // follow symlink
		if err != nil {
			entry.IsBroken = true
			return entry
		}
		entry.IsDir = symlinkInfo.IsDir()
		entry.Size = symlinkInfo.Size()
		entry.Mode = symlinkInfo.Mode()
		entry.Time = symlinkInfo.ModTime()
	}

	return entry
}
