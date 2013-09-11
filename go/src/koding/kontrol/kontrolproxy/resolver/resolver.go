package resolver

import (
	"errors"
	"fmt"
	"koding/db/models"
	"koding/db/mongodb/modelhelper"
	"koding/kontrol/kontrolproxy/utils"
	"labix.org/v2/mgo"
	"log"
	"math"
	"math/rand"
	"net"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Target is returned for every incoming request host.
type Target struct {
	// Url contains the final target
	Url *url.URL

	// Mode contains the information get via model.ProxyTable.Mode
	Mode string

	// Persistence contains the information get via
	// model.LoadBalancer.Persistence
	Persistence string

	// FetchedAt contains the time the target was fetched and stored. Useful
	// for caching
	FetchedAt time.Time

	// UseCache is a switch to enable the cache for that target. By default
	// it's set to true by resolver.
	UseCache bool
}

func NewTarget(url *url.URL, mode, persistence string) *Target {
	if url == nil {
		url, _ = url.Parse("http://localhost/maintenance")
	}

	return &Target{
		Url:         url,
		Mode:        mode,
		Persistence: persistence,
		FetchedAt:   time.Now(),
		UseCache:    true,
	}
}

var ErrGone = errors.New("target is gone")

// used for inmemory lookup
var targets = make(map[string]Target)
var targetsLock sync.RWMutex
var cacheTimeout = time.Second * 20

// used for loadbalance modes, like roundrobin or random
var indexes = make(map[string]int)
var indexesLock sync.RWMutex

// GetMemTarget is like GetTarget with a difference, that it f first makes a
// lookup from the in-memory lookup, if not found it returns the result from
// GetTarget()
func GetMemTarget(host string) (*Target, string, error) {
	var err error
	var target = &Target{}
	dataSource := "cache"
	target, ok := getCacheTarget(host)
	if !ok {
		dataSource = "db"
		target, err = GetTarget(host)
		if err != nil {
			return nil, "", err
		}

		if target.UseCache {
			go registerCacheTarget(host, target)
		}
	}

	return target, dataSource, nil
}

// GetTarget is used to resolve any hostname to their final target destination
// together with the mode of the domain. Any incoming domain can have multiple
// different target destinations. GetTarget returns the ultimate target
// destinations. Some examples:
//
// koding.com -> "http://webserver-build-koding-813a.in.koding.com:3000", mode:internal
// arslan.kd.io -> "http://10.128.2.25:80", mode:vm
// y.koding.com -> "http://localhost/maintenance", mode:maintenance
func GetTarget(host string) (*Target, error) {
	var target *url.URL
	var domain models.Domain
	var hostname string
	var err error
	var port string

	if !utils.HasPort(host) {
		port = "80"
	} else {
		host, port, err = net.SplitHostPort(host)
		if err != nil {
			log.Println(err)
		}
	}

	domain, err = modelhelper.GetDomain(host)
	if err != nil {
		// Lookup didn't found anything, move on to .x.koding.com and .kd.io
		// domains. This is fallback mechanism, you can overide those domains
		// always by adding a new entry for the domain itself into to jDomains
		// collection. (hence the lookup via modelhelper.GetDomain will not fail)
		if err != mgo.ErrNotFound {
			return nil, fmt.Errorf("incoming req host: %s, domain lookup error '%s'\n", host, err.Error())
		}

		h := strings.SplitN(host, ".", 2) // input: xxxxx.kd.io, output: [xxxxx kd.io]

		if len(h) != 2 {
			return nil, fmt.Errorf("not valid req host", host)
		}

		var servicename, key, username string
		s := strings.Split(h[0], "-") // input: service-key-username, output: [service key username]

		switch h[1] {
		case "x.koding.com":
			// in form of: server-123.x.koding.com, assuming the user is 'koding'
			fmt.Println("X.KODING.COM", host)
			if c := strings.Count(h[0], "-"); c != 1 {
				return nil, fmt.Errorf("not valid req host", host)
			}
			servicename, key, username = s[0], s[1], "koding"
		case "kd.io":
			// in form of: chatkite-1-arslan.kd.io
			//           : webserver-917-fatih.kd.io
			fmt.Println("KD.IO", host)
			if c := strings.Count(h[0], "-"); c != 2 {
				return nil, fmt.Errorf("not valid req host", host)
			}
			servicename, key, username = s[0], s[1], s[2]
		default:
			// any other domains are discarded
			return nil, fmt.Errorf("not valid req host", host)
		}

		if servicename == "" || key == "" || username == "" {
			return nil, fmt.Errorf("not valid req host", host)
		}

		domain = *modelhelper.NewDomain(host, "internal", username, servicename, key, "", []string{})
	}

	if domain.Proxy == nil {
		return nil, fmt.Errorf("proxy field is empty for %s", host)
	}

	mode := domain.Proxy.Mode
	persistence := domain.LoadBalancer.Persistence

	switch mode {
	case "maintenance":
		// for avoiding nil pointer referencing
		return NewTarget(nil, mode, persistence), nil
	case "redirect":
		target, err := url.Parse(utils.CheckScheme(domain.Proxy.FullUrl))
		if err != nil {
			return nil, err
		}

		return NewTarget(target, mode, persistence), nil
	case "vm":
		if len(domain.HostnameAlias) == 0 {
			return nil, fmt.Errorf("domain for hostname %s is not active")
		}

		switch domain.LoadBalancer.Mode {
		case "roundrobin": // equal weights
			index := getIndex(host) // gives 0 if not available
			N := float64(len(domain.HostnameAlias))
			n := int(math.Mod(float64(index+1), N))
			hostname = domain.HostnameAlias[n]

			addOrUpdateIndex(host, n)
		case "random":
			randomIndex := rand.Intn(len(domain.HostnameAlias) - 1)
			hostname = domain.HostnameAlias[randomIndex]
		default:
			hostname = domain.HostnameAlias[0]
		}

		vm, err := modelhelper.GetVM(hostname)
		if err != nil {
			return nil, err
		}

		if vm.IP == nil {
			return nil, fmt.Errorf("vm for hostname %s is not active", hostname)
		}

		vmAddr := vm.IP.String()
		if !utils.HasPort(vmAddr) {
			vmAddr = utils.AddPort(vmAddr, port)
		}

		target, err = url.Parse("http://" + vmAddr)
		if err != nil {
			return nil, err
		}
	case "internal":
		// we only opened ports between those, therefore other ports are not used
		portInt, _ := strconv.Atoi(port)
		if portInt >= 1024 && portInt <= 10000 {
			return nil, fmt.Errorf("port range is not allowed for internal usages")
		}

		username := domain.Proxy.Username
		servicename := domain.Proxy.Servicename
		key := domain.Proxy.Key
		latestKey := modelhelper.GetLatestKey(username, servicename)
		if latestKey == "" {
			latestKey = key
		}

		keyData, err := modelhelper.GetKey(username, servicename, key)
		if err != nil {
			currentVersion, _ := strconv.Atoi(key)
			latestVersion, _ := strconv.Atoi(latestKey)
			if currentVersion < latestVersion {
				return nil, ErrGone
			} else {
				return nil, fmt.Errorf("no keyData for username '%s', servicename '%s' and key '%s'", username, servicename, key)
			}
		}

		switch keyData.LoadBalancer.Mode {
		case "roundrobin":
			var n int
			index := getIndex(host) // gives 0 if not available
			hostname, n = roundRobin(keyData.Host, index, 0)
			addOrUpdateIndex(host, n)
			if hostname == "" { // means all servers are dead, show maintenance page
				return NewTarget(nil, "maintenance", persistence), nil
			}
		case "random":
			randomIndex := rand.Intn(len(keyData.Host) - 1)
			hostname = keyData.Host[randomIndex]
		default:
			hostname = keyData.Host[0]
		}

		hostname := utils.CheckScheme(hostname)
		target, err = url.Parse(hostname)
		if err != nil {
			return nil, err
		}
	default:
		return nil, fmt.Errorf("ERROR: proxy mode is not supported: %s", domain.Proxy.Mode)
	}

	return NewTarget(target, mode, persistence), nil
}

// roundRobin is doing roundrobin between between the servers in the hosts
// array. If picks the next item in the array, specified with index and then
// checks for aliveness. If the server is dead it checks for the next item,
// until all servers are checked. If all servers are dead it returns an empty
// string, otherwise it returns the correct server name.
func roundRobin(hosts []string, index, iter int) (string, int) {
	if iter == len(hosts) {
		fmt.Printf("[%s] ALL HOSTNAMES ARE DEAD. List of hostnames: '%v'\n",
			time.Now().Format(time.Stamp),
			hosts,
		)

		return "", 0 // all hosts are dead
	}

	N := float64(len(hosts))
	n := int(math.Mod(float64(index+1), N))
	hostname := hosts[n]

	fmt.Printf("[%s] trying : hostname '%s' index '%d' \n",
		time.Now().Format(time.Stamp),
		hostname,
		index+1,
	)

	if err := utils.CheckServer(hostname); err != nil {
		fmt.Printf("[%s] dead   : hostname '%s', index '%d' error: '%s'\n",
			time.Now().Format(time.Stamp),
			hostname,
			index,
			err.Error(),
		)

		hostname, n = roundRobin(hosts, index+1, iter+1)
		fmt.Printf("[%s] new    : hostname '%s' index '%d' \n",
			time.Now().Format(time.Stamp),
			hostname,
			index+1,
		)
	}

	return hostname, n
}

/***********************************************************
*
*  in-memory lookup functions for cache lookups and actions
*
************************************************************/

// getCacheTarget is used to get the cached Target for the incoming host. It's
// concurrent safe.
func getCacheTarget(host string) (*Target, bool) {
	targetsLock.RLock()
	defer targetsLock.RUnlock()
	target, ok := targets[host]
	return &target, ok
}

// registerCacheTarget is used to register target for the incoming host to the
// cache. It's concurrent safe. It also starts the cacheCleaner immediately
// after the first registering, which is used for cache invalidation.
func registerCacheTarget(host string, target *Target) {
	targetsLock.Lock()
	defer targetsLock.Unlock()
	targets[host] = *target
	if len(targets) == 1 {
		go cacheCleaner()
	}
}

// deleteCacheTarget is used to remove the incoming host from the cache. It's
// concurrent safe.
func deleteCacheTarget(host string) {
	targetsLock.Lock()
	defer targetsLock.Unlock()
	delete(targets, host)
}

// cacheCleaner is used for cache invalidation. It is started whenever you call
// registerCacheTarget().
// It basically does this: as long as there are targets in the map, it
// finds the one it should be deleted next, sleeps until it's time to delete it
// (one hour - time since target is fetched ) and deletes it.  If there are no
// targets, the goroutine exits and a new one is created the next time a user
// is registered. The time.Sleep goes toward zero, thus it will not lock the
// for iterator forever.
func cacheCleaner() {
	targetsLock.RLock()
	for len(targets) > 0 {
		var nextTime time.Time
		var nextTarget string
		for ip, c := range targets {
			if nextTime.IsZero() || c.FetchedAt.Before(nextTime) {
				nextTime = c.FetchedAt
				nextTarget = ip
			}
		}
		targetsLock.RUnlock()
		// negative duration is no-op, means it will not panic
		time.Sleep(cacheTimeout - time.Now().Sub(nextTime))
		deleteCacheTarget(nextTarget)
		targetsLock.RLock()
	}
	targetsLock.RUnlock()
}

/*******************************************************
*
*  loadbalance index functions for roundrobin or random
*
********************************************************/

// getIndex is used to get the current index for current the loadbalance
// algorithm/mode. It's concurrent-safe.
func getIndex(host string) int {
	indexesLock.RLock()
	defer indexesLock.RUnlock()
	index, _ := indexes[host]
	return index
}

// addOrUpdateIndex is used to add the current index for the current loadbalacne
// algorithm. The index number is changed according to to the loadbalance mode.
// When used roundrobin, the next items index is saved, for random a random
// number is assigned, and so on. It's concurrent-safe.
func addOrUpdateIndex(host string, index int) {
	indexesLock.Lock()
	defer indexesLock.Unlock()
	indexes[host] = index
}

// deleteIndex is used to remove the current index from the indexes. It's
// concurrent-safe.
func deleteIndex(host string) {
	indexesLock.Lock()
	defer indexesLock.Unlock()
	delete(indexes, host)
}
