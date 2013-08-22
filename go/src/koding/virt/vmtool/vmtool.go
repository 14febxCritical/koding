package main

import (
	"bufio"
	"fmt"
	"io"
	"io/ioutil"
	"koding/tools/utils"
	"koding/virt"
	"labix.org/v2/mgo"
	"labix.org/v2/mgo/bson"
	"net"
	"os"
	"os/exec"
	"runtime"
	"sort"
	"strconv"
	"strings"
)

type PackageWithCount struct {
	pkg   string
	count int
}

type PackageWithCountSlice []PackageWithCount

func (s PackageWithCountSlice) Len() int {
	return len(s)
}

func (s PackageWithCountSlice) Less(i, j int) bool {
	return s[i].count > s[j].count
}

func (s PackageWithCountSlice) Swap(i, j int) {
	s[i], s[j] = s[j], s[i]
}

var actions = map[string]func(){
	"start": func() {
		for _, vm := range selectVMs(os.Args[2]) {
			err := vm.Start()
			fmt.Printf("%v: %v\n%s", vm, err)
		}
	},

	"shutdown": func() {
		for _, vm := range selectVMs(os.Args[2]) {
			err := vm.Shutdown()
			fmt.Printf("%v: %v\n%s", vm, err)
		}
	},

	"stop": func() {
		for _, vm := range selectVMs(os.Args[2]) {
			err := vm.Stop()
			fmt.Printf("%v: %v\n%s", vm, err)
		}
	},

	"unprepare": func() {
		for _, vm := range selectVMs(os.Args[2]) {
			err := vm.Unprepare()
			fmt.Printf("%v: %v\n", vm, err)
		}
	},

	"create-test-vms": func() {
		startIP := net.IPv4(172, 16, 0, 2)
		if len(os.Args) >= 4 {
			startIP = net.ParseIP(os.Args[3])
		}
		ipPoolFetch, _ := utils.NewIntPool(utils.IPToInt(startIP), nil)
		count, _ := strconv.Atoi(os.Args[2])
		done := make(chan int)
		for i := 0; i < count; i++ {
			go func(i int) {
				vm := virt.VM{
					Id: bson.NewObjectId(),
					IP: utils.IntToIP(<-ipPoolFetch),
				}
				vm.Prepare(false, func(text string, data ...interface{}) { fmt.Println(text) })
				done <- i
			}(i)
		}
		for i := 0; i < count; i++ {
			fmt.Println(<-done)
		}
	},

	"backup": func() {
		for _, vm := range selectVMs(os.Args[2]) {
			err := vm.Backup()
			fmt.Printf("%v: %v\n", vm, err)
		}
	},

	"dpkg-statistics": func() {
		entries, err := ioutil.ReadDir("/var/lib/lxc/dpkg-statuses")
		if err != nil {
			panic(err)
		}

		counts := make(map[string]int)
		for _, entry := range entries {
			packages, err := virt.ReadDpkgStatus("/var/lib/lxc/dpkg-statuses/" + entry.Name())
			if err != nil {
				panic(err)
			}
			for pkg := range packages {
				counts[pkg] += 1
			}
		}

		packages, err := virt.ReadDpkgStatus("/var/lib/lxc/vmroot/rootfs/var/lib/dpkg/status")
		if err != nil {
			panic(err)
		}
		for pkg := range packages {
			delete(counts, pkg)
		}

		list := make(PackageWithCountSlice, 0, len(counts))
		for pkg, count := range counts {
			list = append(list, PackageWithCount{pkg, count})
		}
		sort.Sort(list)

		fmt.Println("Top 10 installed packages not in vmroot:")
		for i, entry := range list {
			if i == 10 {
				break
			}
			fmt.Printf("%s: %d\n", entry.pkg, entry.count)
		}
	},

	"rbd-orphans": func() {
		session, err := mgo.Dial(os.Args[2])
		if err != nil {
			panic(err)
		}
		session.SetSafe(&mgo.Safe{})
		database := session.DB("")
		iter := database.C("jVMs").Find(bson.M{}).Select(bson.M{"_id": 1}).Iter()
		var vm struct {
			Id bson.ObjectId `bson:"_id"`
		}
		ids := make(map[string]bool)
		for iter.Next(&vm) {
			ids["vm-"+vm.Id.Hex()] = true
		}
		if err := iter.Close(); err != nil {
			panic(err)
		}

		cmd := exec.Command("/usr/bin/rbd", "ls", "--pool", "vms")
		pipe, _ := cmd.StdoutPipe()
		r := bufio.NewReader(pipe)
		if err := cmd.Start(); err != nil {
			panic(err)
		}
		fmt.Println("RBD images without corresponding database entry:")
		for {
			image, err := r.ReadString('\n')
			if err != nil {
				if err != io.EOF {
					panic(err)
				}
				break
			}
			image = image[:len(image)-1]

			if !ids[image] {
				fmt.Println(image)
			}
		}
	},
}

func main() {
	runtime.GOMAXPROCS(runtime.NumCPU())
	if err := virt.LoadTemplates("templates"); err != nil {
		panic(err)
	}

	action := actions[os.Args[1]]
	action()
}

func selectVMs(selector string) []*virt.VM {
	if selector == "all" {
		dirs, err := ioutil.ReadDir("/var/lib/lxc")
		if err != nil {
			panic(err)
		}
		vms := make([]*virt.VM, 0)
		for _, dir := range dirs {
			if strings.HasPrefix(dir.Name(), "vm-") {
				vms = append(vms, &virt.VM{Id: bson.ObjectIdHex(dir.Name()[3:])})
			}
		}
		return vms
	}

	if strings.HasPrefix(selector, "vm-") {
		_, err := os.Stat("/var/lib/lxc/" + selector)
		if err != nil {
			if !os.IsNotExist(err) {
				panic(err)
			}
			fmt.Println("No prepared VM with name: " + selector)
			os.Exit(1)
		}
		return []*virt.VM{&virt.VM{Id: bson.ObjectIdHex(selector[3:])}}
	}

	fmt.Println("Invalid selector: " + selector)
	os.Exit(1)
	return nil
}
