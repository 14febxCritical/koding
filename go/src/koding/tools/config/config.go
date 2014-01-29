package config

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"syscall"
)

type Config struct {
	BuildNumber     int
	ProjectRoot     string
	UserSitesDomain string
	ContainerSubnet string
	VmPool          string
	Version         string
	Client          struct {
		StaticFilesBaseUrl string
	}
	Mongo        string
	MongoKontrol string
	Mq           struct {
		Host          string
		Port          int
		ComponentUser string
		Password      string
		Vhost         string
		LogLevel      string
	}
	Neo4j struct {
		Read    string
		Write   string
		Port    int
		Enabled bool
	}
	GoLogLevel string
	Broker     struct {
		IP              string
		Port            int
		CertFile        string
		KeyFile         string
		AuthExchange    string
		AuthAllExchange string
		WebProtocol     string
	}
	Loggr struct {
		Push   bool
		Url    string
		ApiKey string
	}
	Librato struct {
		Push     bool
		Email    string
		Token    string
		Interval int
	}
	Opsview struct {
		Push bool
		Host string
	}
	ElasticSearch struct {
		Host  string
		Port  int
		Queue string
	}
	NewKontrol struct {
		Host     string
		Port     int
		CertFile string
		KeyFile  string
	}
	ProxyKite struct {
		Domain   string
		CertFile string
		KeyFile  string
	}
	Etcd []struct {
		Host string
		Port int
	}
	Kontrold struct {
		Vhost    string
		Overview struct {
			ApiPort    int
			ApiHost    string
			Port       int
			SwitchHost string
		}
		Api struct {
			Port int
			URL  string
		}
		Proxy struct {
			Port    int
			PortSSL int
			FTPIP   string
		}
	}
	FollowFeed struct {
		Host          string
		Port          int
		ComponentUser string
		Password      string
		Vhost         string
	}
	Statsd struct {
		Use  bool
		Ip   string
		Port int
	}
	TopicModifier struct {
		CronSchedule string
	}
	Slack struct {
		Token   string
		Channel string
	}
	Graphite struct {
		Use  bool
		Host string
		Port int
	}
	LogLevel map[string]string
}

var Profile string
var Current Config
var LogDebug bool
var Uuid string
var Host string
var BrokerDomain string
var Region string
var VMProxies bool // used to enable ports for users
var Skip int
var Count int

func init() {
	flag.StringVar(&Profile, "c", "", "Configuration profile from file")
	flag.StringVar(&Profile, "config", "", "Alias for -c")

	flag.BoolVar(&LogDebug, "d", false, "Log debug messages")
	flag.StringVar(&Uuid, "u", "", "Enable kontrol mode")
	flag.StringVar(&Host, "h", "", "Hostname to be resolved")
	flag.StringVar(&BrokerDomain, "a", "", "Send kontrol a custom domain istead of os.Hostname")
	flag.StringVar(&BrokerDomain, "domain", "", "Alias for -a")
	flag.StringVar(&Region, "r", "", "Region")
	flag.IntVar(&Skip, "s", 0, "Define how far to skip ahead")
	flag.IntVar(&Count, "l", 1000, "Count for items to process")
	flag.BoolVar(&VMProxies, "v", false, "Enable ports for VM users (1024-10000)")

	flag.Parse()

	err := readConfig()
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	sigChannel := make(chan os.Signal)
	signal.Notify(sigChannel, syscall.SIGUSR2)
	go func() {
		for _ = range sigChannel {
			LogDebug = !LogDebug
			fmt.Printf("config.LogDebug: %v\n", LogDebug)
		}
	}()

}

// readConfig reads and unmarshalls the appropriate config into the Config
// struct (which is used in many applications). It reads the config from the
// koding-config-manager  with command line flag -c. If there is no flag
// specified it tries to get the config from the environment variable
// "CONFIG".
func readConfig() error {
	if flag.NArg() != 0 {
		return errors.New("config.go: you passed extra unused arguments.")
	}

	if Profile == "" {
		// this is needed also if you can't pass a flag into other packages, like testing.
		// otherwise it's impossible to inject the config paramater. For example:
		// this doesn't work  : go test -c "vagrant"
		// but this will work : CONFIG="vagrant" go test
		envProfile := os.Getenv("CONFIG")
		if envProfile == "" {
			return errors.New("config.go: please specify a configuration profile via -c or set a CONFIG environment.")
		}

		Profile = envProfile
	}

	configPath := fmt.Sprintf("./config/main.%s.json", Profile)
	ok, err := exists(configPath)
	if err != nil {
		return err
	}

	if ok {
		fmt.Printf("config.go: reading config from %s\n", configPath)
		err := readJson(Profile)
		if err != nil {
			return err
		}
	} else {
		fmt.Println("config.go: reading config with koding-config-manager")
		err := readConfigManager(Profile)
		if err != nil {
			return err
		}
	}

	return nil
}

func readJson(profile string) error {
	pwd, err := os.Getwd()
	if err != nil {
		return err
	}

	configPath := filepath.Join(pwd, "config", fmt.Sprintf("main.%s.json", profile))

	data, err := ioutil.ReadFile(configPath)
	if err != nil {
		return err
	}

	err = json.Unmarshal(data, &Current)
	if err != nil {
		return fmt.Errorf("Could not unmarshal configuration: %s\nConfiguration source output:\n%s\n",
			err.Error(), string(data))
	}

	return nil
}

func readConfigManager(profile string) error {
	cmd := exec.Command("node", "-e", "require('koding-config-manager').printJson('main."+profile+"')")

	config, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("Could not execute configuration source: %s\nConfiguration source output:\n%s\n",
			err.Error(), config)
	}

	err = json.Unmarshal(config, &Current)
	if err != nil {
		return fmt.Errorf("Could not unmarshal configuration: %s\nConfiguration source output:\n%s\n",
			err.Error(), string(config))
	}

	// successfully unmarshalled into Current
	return nil
}

// exists returns whether the given file or directory exists or not.
func exists(path string) (bool, error) {
	_, err := os.Stat(path)
	if err == nil {
		return true, nil
	}

	if os.IsNotExist(err) {
		return false, nil
	}

	return false, err
}
