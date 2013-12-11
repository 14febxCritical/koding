// Package protocol defines the communication between the components
// of the Kite infrastructure. It defines some constants and structures
// designed to be sent between those components.
package protocol

import (
	"net"
)

// Kite is the base struct containing the public fields. It is usually embeded
// in other structs, including the db model. The access model is in the form:
// username.environment.name.version.region.hostname.id
type Kite struct {
	// Short name identifying the type of the kite. Example: fs, terminal...
	Name string `bson:"name" json:"name"`

	// Owner of the Kite
	Username string `bson:"username" json:"username"`

	// Every Kite instance has different identifier.
	// If a kite is restarted, it's id will change.
	// This is generated on the Kite.
	ID string `bson:"_id" json:"id"`

	// Environment is defines as something like "production", "testing",
	// "staging" or whatever.  This allows you to differentiate between a
	// cluster of kites.
	Environment string `bson:"environment" json:"environment"`

	// Region of the kite it is running. Like "Europe", "Asia" or some other
	// locations.
	Region string `bson:"region" json:"region"`

	// Is this Kite public or private?
	Visibility Visibility

	Version  string `bson:"version" json:"version"`
	Hostname string `bson:"hostname" json:"hostname"`
	PublicIP string `bson:"publicIP" json:"publicIP"`
	Port     string `bson:"port" json:"port"`
}

func (k *Kite) Addr() string {
	return net.JoinHostPort(k.PublicIP, k.Port)
}

type Visibility string

const (
	Public  Visibility = "PUBLIC"
	Private Visibility = "PRIVATE"
)

// RegisterResult is a response to Register request from Kite to Kontrol.
type RegisterResult struct {
	Result RegisterAction `json:"result"`

	// Username is sent in response because the kite does not know
	// it's own user's name on start.
	Username string `json:"username"`

	// PublicIP is the IP address visible to Kontrol.
	PublicIP string
}

type RegisterAction string

const (
	AllowKite  RegisterAction = "ALLOW"
	RejectKite RegisterAction = "REJECT"
)

type KiteWithToken struct {
	Kite  Kite  `json:"kite"`
	Token Token `json:"token"`
}

// KiteEvent is the struct that is sent as an argument in watchCallback of
// getKites method of Kontrol.
type KiteEvent struct {
	Action KiteAction `json:"action"`
	Kite   Kite       `json:"kite"`

	// Required when Action == Register
	Token *Token `json:"token,omitempty"`
}

type KiteAction string

const (
	Register   KiteAction = "REGISTER"
	Deregister KiteAction = "DEREGISTER"
)

// Token is the type of the struct given to a Kite in order to authenticate
// itself to the remote Kite.
type Token struct {
	Key string
	TTL int
}

// KontrolQuery is a structure of message sent to Kontrol. It is used for
// querying kites based on the incoming field parameters. Missing fields are
// not counted during the query (for example if the "version" field is empty,
// any kite with different version is going to be matched).
// Order of the fields is from general to specific.
type KontrolQuery struct {
	Username    string `json:"username"`
	Environment string `json:"environment"`
	Name        string `json:"name"`
	Version     string `json:"version"`
	Region      string `json:"region"`
	Hostname    string `json:"hostname"`
	ID          string `json:"id"`
}
