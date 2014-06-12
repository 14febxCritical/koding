package digitalocean

import (
	"errors"
	do "koding/kites/kloud/api/digitalocean"
	"koding/kites/kloud/eventer"
	"koding/kites/kloud/kloud/machinestate"
	"koding/kites/kloud/kloud/protocol"

	"github.com/koding/logging"
)

const ProviderName = "digitalocean"

type Provider struct {
	Log      logging.Logger
	SignFunc func(string) (string, string, error)
	Push     func(string, int, machinestate.State)
}

type Droplet struct {
	Droplet    *do.Droplet
	PrivateKey string
	KeyId      uint
}

func (p *Provider) NewClient(opts *protocol.MachineOptions) (*Client, error) {
	d, err := do.New(opts.Credential, opts.Builder)
	if err != nil {
		return nil, err
	}

	if opts.Eventer == nil {
		return nil, errors.New("Eventer is not defined.")
	}

	push := func(msg string, percentage int, state machinestate.State) {
		p.Log.Info("[machineId: '%s': username: '%s' dropletName: '%s' snapshotName: '%s'] - %s",
			opts.MachineId, opts.Username, opts.InstanceName, opts.ImageName, msg)

		opts.Eventer.Push(&eventer.Event{
			Message:    msg,
			Status:     state,
			Percentage: percentage,
		})
	}

	c := &Client{
		Push:     push,
		Log:      p.Log,
		SignFunc: p.SignFunc,
	}

	p.Push = push
	c.DigitalOcean = d
	return c, nil
}

func (p *Provider) Name() string {
	return ProviderName
}

// Build is building an image and creates a droplet based on that image. If the
// given snapshot/image exist it directly skips to creating the droplet. It
// acceps two string arguments, first one is the snapshotname, second one is
// the dropletName.
func (p *Provider) Build(opts *protocol.MachineOptions) (*protocol.BuildResponse, error) {
	doClient, err := p.NewClient(opts)
	if err != nil {
		return nil, err
	}

	if opts.ImageName == "" {
		return nil, errors.New("snapshotName is empty")
	}

	if opts.InstanceName == "" {
		return nil, errors.New("dropletName is empty")
	}

	if opts.Username == "" {
		return nil, errors.New("username is empty")
	}

	return doClient.Build(opts.ImageName, opts.InstanceName, opts.Username)
}

func (p *Provider) Start(opts *protocol.MachineOptions) error {
	doClient, err := p.NewClient(opts)
	if err != nil {
		return err
	}

	return doClient.Start()
}

func (p *Provider) Stop(opts *protocol.MachineOptions) error {
	doClient, err := p.NewClient(opts)
	if err != nil {
		return err
	}

	return doClient.Stop()
}

func (p *Provider) Restart(opts *protocol.MachineOptions) error {
	doClient, err := p.NewClient(opts)
	if err != nil {
		return err
	}

	return doClient.Restart()
}

func (p *Provider) Destroy(opts *protocol.MachineOptions) error {
	doClient, err := p.NewClient(opts)
	if err != nil {
		return err
	}

	return doClient.Destroy()
}

func (p *Provider) Info(opts *protocol.MachineOptions) (*protocol.InfoResponse, error) {
	doClient, err := p.NewClient(opts)
	if err != nil {
		return nil, err
	}

	return doClient.Info()
}
