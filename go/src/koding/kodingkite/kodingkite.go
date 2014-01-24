package kodingkite

import (
	"fmt"
	"koding/kite/kite"
	"koding/tools/config"
	"net/url"
	"strconv"
)

type Options kite.Options

// New returns a new kite instance based on for the given Koding configurations
func New(options Options) *kite.Kite {
	kontrolPort := strconv.Itoa(config.Current.NewKontrol.Port)
	kontrolHost := config.Current.NewKontrol.Host
	kontrolURL := &url.URL{
		Scheme: "ws",
		Host:   fmt.Sprintf("%s:%s", kontrolHost, kontrolPort),
		Path:   "/dnode",
	}

	// Update config
	options.Environment = config.Profile
	options.Region = config.FileProfile
	options.KontrolURL = kontrolURL

	o := kite.Options(options)
	return kite.New(&o)
}
