package koding

import (
	"fmt"
	"strconv"
	"strings"
	"time"

	"koding/db/mongodb"

	"github.com/koding/kite"
	amazonClient "github.com/koding/kloud/api/amazon"
	"github.com/koding/kloud/eventer"
	"github.com/koding/kloud/machinestate"
	"github.com/koding/kloud/protocol"
	"github.com/koding/kloud/provider/amazon"
	"github.com/koding/logging"
	"github.com/mitchellh/goamz/ec2"
	"github.com/mitchellh/mapstructure"
)

var (
	DefaultCustomAMITag = "koding-stable" // Only use AMI's that have this tag
	DefaultInstanceType = "t2.micro"
	DefaultRegion       = "us-east-1"

	kodingCredential = map[string]interface{}{
		"access_key": "AKIAI6IUMWKF3F4426CA",
		"secret_key": "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",
	}
)

const (
	ProviderName = "koding"
)

// Provider implements the kloud packages Storage, Builder and Controller
// interface
type Provider struct {
	Kite         *kite.Kite
	Session      *mongodb.MongoDB
	AssigneeName string
	Log          logging.Logger
	Push         func(string, int, machinestate.State)

	// A flag saying if user permissions should be ignored
	// store negation so default value is aligned with most common use case
	Test bool

	// Contains the users home directory to be added into a image
	TemplateDir string

	// DNS is used to create/update domain recors
	DNS        *DNS
	HostedZone string
}

func (p *Provider) NewClient(machine *protocol.Machine) (*amazon.AmazonClient, error) {
	username := machine.Builder["username"].(string)

	a := &amazon.AmazonClient{
		Log: p.Log,
		Push: func(msg string, percentage int, state machinestate.State) {
			p.Log.Info("%s - %s ==> %s", machine.MachineId, username, msg)

			machine.Eventer.Push(&eventer.Event{
				Message:    msg,
				Status:     state,
				Percentage: percentage,
			})
		},
	}

	var err error

	machine.Builder["region"] = DefaultRegion

	a.Amazon, err = amazonClient.New(kodingCredential, machine.Builder)
	if err != nil {
		return nil, fmt.Errorf("koding-amazon err: %s", err)
	}

	// also apply deploy variable if there is any
	if err := mapstructure.Decode(machine.Builder, &a.Deploy); err != nil {
		return nil, fmt.Errorf("koding-amazon: couldn't decode deploy variables: %s", err)
	}

	return a, nil
}

func (p *Provider) Name() string {
	return ProviderName
}

func (p *Provider) Build(opts *protocol.Machine) (protocolArtifact *protocol.Artifact, err error) {
	a, err := p.NewClient(opts)
	if err != nil {
		return nil, err
	}

	username := opts.Builder["username"].(string)

	instanceName := opts.Builder["instanceName"].(string)

	machineData, ok := opts.CurrentData.(*Machine)
	if !ok {
		return nil, fmt.Errorf("current data is malformed: %v", opts.CurrentData)
	}

	// this can happen when an Info method is called on a terminated instance.
	// This updates the DB records with the name that EC2 gives us, which is a
	// "terminated-instance"
	if instanceName == "terminated-instance" {
		instanceName = username + "-" + strconv.FormatInt(time.Now().UTC().UnixNano(), 10)
		a.Log.Info("Instance name is an artifact (terminated), changing to %s", instanceName)
	}

	groupName := "koding-kloud" // TODO: make it from the package level and remove it from here
	a.Log.Info("Checking if security group '%s' exists", groupName)
	group, err := a.SecurityGroup(groupName)
	if err != nil {
		a.Log.Info("No security group with name: '%s' exists. Creating a new one...", groupName)
		vpcs, err := a.ListVPCs()
		if err != nil {
			return nil, err
		}

		group = ec2.SecurityGroup{
			Name:        groupName,
			Description: "Koding Kloud Security Group",
			VpcId:       vpcs.VPCs[0].VpcId,
		}

		a.Log.Info("Creating security group for this instance...")
		// TODO: remove it after we are done
		groupResp, err := a.Client.CreateSecurityGroup(group)
		if err != nil {
			return nil, err
		}
		group = groupResp.SecurityGroup

		// Authorize the SSH access
		perms := []ec2.IPPerm{
			ec2.IPPerm{
				Protocol:  "tcp",
				FromPort:  22,
				ToPort:    22,
				SourceIPs: []string{"0.0.0.0/0"},
			},
		}

		// We loop and retry this a few times because sometimes the security
		// group isn't available immediately because AWS resources are eventaully
		// consistent.
		a.Log.Info("Authorizing SSH access on the security group: '%s'", group.Id)
		for i := 0; i < 5; i++ {
			_, err = a.Client.AuthorizeSecurityGroup(group, perms)
			if err == nil {
				break
			}

			a.Log.Warning("Error authorizing. Will sleep and retry. %s", err)
			time.Sleep((time.Duration(i) * time.Second) + 1)
		}
		if err != nil {
			return nil, fmt.Errorf("Error creating temporary security group: %s", err)
		}
	}

	// add now our security group
	a.Builder.SecurityGroupId = group.Id

	// Use koding plans instead of those later
	a.Builder.InstanceType = DefaultInstanceType

	// needed for vpc instances, go and grap one from one of our Koding's own
	// subnets
	a.Log.Info("Searching for subnets")
	subs, err := a.ListSubnets()
	if err != nil {
		return nil, err
	}
	a.Builder.SubnetId = subs.Subnets[0].SubnetId

	a.Log.Info("Checking if AMI with tag '%s' exists", DefaultCustomAMITag)
	image, err := a.ImageByTag(DefaultCustomAMITag)
	if err != nil {
		return nil, err
	}

	// Use this ami id, which is going to be a stable one
	a.Builder.SourceAmi = image.Id

	cloudConfig := `
#cloud-config
disable_root: false
disable-ec2-metadata: true
hostname: %s`

	// use a simple hostname, previously we were using instanceName which was
	// is long and more detailed
	hostname := username

	cloudStr := fmt.Sprintf(cloudConfig, hostname)

	a.Builder.UserData = []byte(cloudStr)

	buildArtifact, err := a.Build(instanceName)
	if err != nil {
		return nil, err
	}

	// cleanup build if something goes wrong here
	defer func() {
		if err != nil {
			p.Log.Warning("Cleaning up instance for machine id: %s. Terminating instance: %s",
				opts.MachineId, buildArtifact.InstanceId)

			if _, err := a.Client.TerminateInstances([]string{buildArtifact.InstanceId}); err != nil {
				p.Log.Warning("Cleaning up instance failed: %v", err)
			}
		}
	}()

	// Add user specific tag to make it easier  simplfying easier
	a.Log.Info("Adding username tag '%s' to the instance '%s'", username, buildArtifact.InstanceId)
	if err := a.AddTag(buildArtifact.InstanceId, "koding-user", username); err != nil {
		return nil, err
	}

	/////// ROUTE 53 /////////////////
	if err := p.InitDNS(opts); err != nil {
		return nil, err
	}

	domainName := machineData.Label + "." + username + "." + p.HostedZone

	// Check if the record exist, if not return an error
	record, err := p.DNS.Domain(domainName)
	if err != nil && err != ErrNoRecord {
		return nil, err
	} else {
		if strings.Contains(record.Name, domainName) {
			return nil, fmt.Errorf("domain %s already exists", domainName)
		}
	}

	if err := p.DNS.CreateDomain(domainName, buildArtifact.IpAddress); err != nil {
		return nil, err
	}

	defer func() {
		if err != nil {
			p.Log.Warning("Cleaning up domain record for machine id: %s. Deleting domain record: %s",
				opts.MachineId, domainName)
			if err := p.DNS.DeleteDomain(domainName, buildArtifact.IpAddress); err != nil {
				p.Log.Warning("Cleaning up domain failed: %v", err)
			}

		}
	}()

	a.Log.Info("Adding user domain tag '%s' to the instance '%s'", domainName, buildArtifact.InstanceId)
	if err := a.AddTag(buildArtifact.InstanceId, "koding-domain", domainName); err != nil {
		return nil, err
	}

	///// ROUTE 53 /////////////////
	return buildArtifact, nil
}

// CleanZoneID is used to remove the leading /hostedzone/
func CleanZoneID(ID string) string {
	if strings.HasPrefix(ID, "/hostedzone/") {
		ID = strings.TrimPrefix(ID, "/hostedzone/")
	}
	return ID
}

// Remove the instance if something goes wrong
// TODO: remove this after we moved deploy.go into cloud-init
func (p *Provider) Cancel(opts *protocol.Machine, artifact *protocol.Artifact) error {
	a, err := p.NewClient(opts)
	if err != nil {
		return err
	}

	p.Log.Warning("Cancelling previous action for machine id: %s. Terminating instance: %s",
		opts.MachineId, artifact.InstanceId)
	_, err = a.Client.TerminateInstances([]string{artifact.InstanceId})
	if err != nil {
		p.Log.Warning("Cleaning up instance failed: %v", err)
	}

	if err := p.InitDNS(opts); err != nil {
		return err
	}

	username := opts.Builder["username"].(string)
	machineData := opts.CurrentData.(*Machine)

	domainName := machineData.Label + "." + username + "." + p.HostedZone

	if err := p.DNS.DeleteDomain(domainName, artifact.IpAddress); err != nil {
		p.Log.Warning("Cleaning up domain failed: %v", err)
	}

	return nil
}

func (p *Provider) Start(opts *protocol.Machine) (*protocol.Artifact, error) {
	a, err := p.NewClient(opts)
	if err != nil {
		return nil, err
	}

	artifact, err := a.Start()
	if err != nil {
		return nil, err
	}

	machineData, ok := opts.CurrentData.(*Machine)
	if !ok {
		return nil, fmt.Errorf("current data is malformed: %v", opts.CurrentData)
	}

	/////// ROUTE 53 /////////////////
	if err := p.InitDNS(opts); err != nil {
		return nil, err
	}

	username := opts.Builder["username"].(string)

	domainName := machineData.Label + "." + username + "." + p.HostedZone

	if err := p.DNS.CreateDomain(domainName, artifact.IpAddress); err != nil {
		return nil, err
	}

	a.Log.Info("Updating user domain tag '%s' of instance '%s'", domainName, artifact.InstanceId)
	if err := a.AddTag(artifact.InstanceId, "koding-domain", domainName); err != nil {
		return nil, err
	}

	///// ROUTE 53 /////////////////

	return artifact, nil
}

func (p *Provider) Stop(opts *protocol.Machine) error {
	a, err := p.NewClient(opts)
	if err != nil {
		return err
	}

	err = a.Stop()
	if err != nil {
		return err
	}

	/////// ROUTE 53 /////////////////
	username := opts.Builder["username"].(string)

	machineData, ok := opts.CurrentData.(*Machine)
	if !ok {
		return fmt.Errorf("current data is malformed: %v", opts.CurrentData)
	}

	if err := p.InitDNS(opts); err != nil {
		return err
	}

	domainName := machineData.Label + "." + username + "." + p.HostedZone

	if err := p.DNS.DeleteDomain(domainName, machineData.IpAddress); err != nil {
		return err
	}

	///// ROUTE 53 /////////////////

	return nil
}

func (p *Provider) Restart(opts *protocol.Machine) error {
	a, err := p.NewClient(opts)
	if err != nil {
		return err
	}

	return a.Restart()
}

func (p *Provider) Destroy(opts *protocol.Machine) error {
	a, err := p.NewClient(opts)
	if err != nil {
		return err
	}

	err = a.Destroy()
	if err != nil {
		return err
	}

	/////// ROUTE 53 /////////////////

	username := opts.Builder["username"].(string)

	machineData, ok := opts.CurrentData.(*Machine)
	if !ok {
		return fmt.Errorf("current data is malformed: %v", opts.CurrentData)
	}

	if err := p.InitDNS(opts); err != nil {
		return err
	}

	domainName := machineData.Label + "." + username + "." + p.HostedZone

	// Check if the record exist, it can be deleted via stop, therefore just
	// return lazily
	_, err = p.DNS.Domain(domainName)
	if err == ErrNoRecord {
		return nil
	}

	// If it's something else just return it
	if err != nil {
		return err
	}

	if err := p.DNS.DeleteDomain(domainName, machineData.IpAddress); err != nil {
		return err
	}

	///// ROUTE 53 /////////////////
	return nil
}

func (p *Provider) Info(opts *protocol.Machine) (*protocol.InfoArtifact, error) {
	a, err := p.NewClient(opts)
	if err != nil {
		return nil, err
	}

	return a.Info()
}
