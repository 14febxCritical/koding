package main

import "runtime"

const (
	Version = "0.0.1"

	// Name is the user facing name for this binary. Internally we call it
	// klientctl to avoid confusion.
	Name = "kd"

	// KlientName is the user facing name for klient.
	KlientName = "Koding Service Connector"

	// KlientAddress is url of locally running klient to connect to send
	// user commands.
	KlientAddress = "http://127.0.0.1:56789/kite"

	// KiteHome is full path to the kite key that we will use to authenticate
	// to the given klient.
	//
	// TODO: move to OS friendly place.
	KiteHome = "/etc/kite"

	// KlientDirectory is full path to directory that holds klient.
	//
	// TODO: move to OS friendly place.
	KlientDirectory = "/opt/kite/klient"

	// KlientctlDirectory is full path to directory that holds klientctl.
	KlientctlDirectory = "/usr/local/bin"

	// KontrolUrl is the url to connect to authenticate local klient and get
	// list of VMs.
	KontrolUrl = "https://koding.com/kontrol/kite"

	// KlientctlVersion is the current version of klientctl. This number is used
	// by CheckUpdate to determine if current version is behind or equal to latest
	// version on S3 bucket.
	KlientctlVersion = 1

	osName = runtime.GOOS

	// S3UpdateLocation is publically accessible url to check for new updates.
	S3UpdateLocation = "https://koding-kd.s3.amazonaws.com/latest-version.txt"

	// S3KlientctlPath is publically accessible url for latest version of klient.
	// Each OS has its own version of binary, identifiable by OS suffix.
	S3KlientPath = "https://koding-kd.s3.amazonaws.com/klient-" + osName

	// S3KlientctlPath is publically accessible url for latest version of
	// klientctl. Each OS has its own version of binary, identifiable by suffix.
	S3KlientctlPath = "https://koding-kd.s3.amazonaws.com/klientctl-" + osName
)
