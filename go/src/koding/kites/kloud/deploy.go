package main

import (
	"errors"
	"fmt"
	"koding/db/mongodb"
	"koding/kites/kloud/klient"
	"path/filepath"
	"strings"
	"time"

	"github.com/koding/kite"
	"github.com/koding/kloud"
	"github.com/koding/kloud/protocol"
	"github.com/koding/kloud/sshutil"
	"github.com/koding/logging"
	uuid "github.com/nu7hatch/gouuid"

	kiteprotocol "github.com/koding/kite/protocol"
	"github.com/pkg/sftp"
)

type KodingDeploy struct {
	Kite *kite.Kite
	Log  logging.Logger

	// needed for signing/generating kite tokens
	KontrolPublicKey  string
	KontrolPrivateKey string
	KontrolURL        string

	Bucket *Bucket
	DB     *mongodb.MongoDB
}

// apacheConfig is used to generate a new apache config file that is deployed
// to remote machine
type apacheConfig struct {
	// Defines the base apache running port, should be 80 or 443
	ApachePort int

	// Defines the running kite port, like 3000
	KitePort int
}

// defaultApacheConfig contains a default apache config
var defaultApacheConfig = &apacheConfig{
	ApachePort: 80,
	KitePort:   3000,
}

func (k *KodingDeploy) ServeKite(r *kite.Request) (interface{}, error) {
	data, err := r.Context.Get("buildArtifact")
	if err != nil {
		return nil, errors.New("koding-deploy: build artifact is not available")
	}

	artifact, ok := data.(*protocol.Artifact)
	if !ok {
		return nil, fmt.Errorf("koding-deploy: build artifact is malformed: %+v", data)
	}

	username := artifact.Username
	ipAddress := artifact.IpAddress
	privateKey := artifact.SSHPrivateKey
	sshusername := artifact.SSHUsername

	// make a custom logger which just prepends our machineid
	infoLog := func(format string, formatArgs ...interface{}) {
		format = "[%s] " + format
		args := []interface{}{artifact.MachineId}
		args = append(args, formatArgs...)
		k.Log.Info(format, args...)
	}

	sshAddress := ipAddress + ":22"
	sshConfig, err := sshutil.SshConfig(sshusername, privateKey)
	if err != nil {
		return nil, err
	}

	infoLog("Connecting to SSH: %s", sshAddress)
	client, err := sshutil.ConnectSSH(sshAddress, sshConfig)
	if err != nil {
		return nil, err
	}
	defer client.Close()

	sftpClient, err := sftp.NewClient(client.Client)
	if err != nil {
		return nil, err
	}

	infoLog("Creating a kite.key directory")
	err = sftpClient.Mkdir("/etc/kite")
	if err != nil {
		return nil, err
	}

	tknID, err := uuid.NewV4()
	if err != nil {
		return nil, kloud.NewError(kloud.ErrSignGenerateToken)
	}

	infoLog("Creating user account")
	out, err := client.StartCommand(createUserCommand(username))
	if err != nil {
		fmt.Println("out", out)
		return nil, err
	}

	infoLog("Changing hostname to %s", username)
	if err := changeHostname(client, username); err != nil {
		return nil, err
	}

	infoLog("Creating user migration script")
	if err = k.setupMigrateScript(sftpClient, username); err != nil {
		return nil, err
	}

	infoLog("Creating a key with kontrolURL: %s", k.KontrolURL)
	kiteKey, err := k.createKey(username, tknID.String())
	if err != nil {
		return nil, err
	}

	remoteFile, err := sftpClient.Create("/etc/kite/kite.key")
	if err != nil {
		return nil, err
	}

	infoLog("Copying kite.key to remote machine")
	_, err = remoteFile.Write([]byte(kiteKey))
	if err != nil {
		return nil, err
	}

	infoLog("Fetching latest klient.deb binary")
	latestDeb, err := k.Bucket.LatestDeb()
	if err != nil {
		return nil, err
	}

	// splitted => [klient 0.0.1 environment arch.deb]
	splitted := strings.Split(latestDeb, "_")
	if len(splitted) != 4 {
		// should be a valid deb
		return nil, fmt.Errorf("invalid deb file: %v", latestDeb)
	}

	// signedURL allows us to have public access for a limited time frame
	signedUrl := k.Bucket.SignedURL(latestDeb, time.Now().Add(time.Minute*3))

	infoLog("Downloading '" + filepath.Base(latestDeb) + "' to /tmp inside the machine")
	out, err = client.StartCommand(fmt.Sprintf("wget -O /tmp/klient-latest.deb '%s'", signedUrl))
	if err != nil {
		fmt.Println("out", out)
		return nil, err
	}

	infoLog("Installing klient deb on the machine")
	out, err = client.StartCommand("dpkg -i /tmp/klient-latest.deb")
	if err != nil {
		fmt.Println("out", out)
		return nil, err
	}

	infoLog("Chowning klient directory")
	out, err = client.StartCommand(fmt.Sprintf("chown -R %[1]s:%[1]s /opt/kite/klient", username))
	if err != nil {
		fmt.Println("out", out)
		return nil, err
	}

	infoLog("Removing leftover klient deb from the machine")
	out, err = client.StartCommand("rm -f /tmp/klient-latest.deb")
	if err != nil {
		fmt.Println("out", out)
		return nil, err
	}

	infoLog("Patching klient.conf")
	out, err = client.StartCommand(patchConfCommand(username))
	if err != nil {
		fmt.Println("out", out)
		return nil, err
	}

	infoLog("Restarting klient with kite.key")
	out, err = client.StartCommand("service klient restart")
	if err != nil {
		return nil, err
	}

	infoLog("Making user's default directories")
	out, err = client.StartCommand(fmt.Sprintf("cp -r /opt/koding/userdata/* /home/%s/ && rm -rf /opt/koding/userdata ", username))
	if err != nil {
		fmt.Println("out", out)
		return nil, err
	}

	infoLog("Chowning user's default directories")
	out, err = client.StartCommand(fmt.Sprintf("chown -R %[1]s:%[1]s /home/%[1]s/", username))
	if err != nil {
		fmt.Println("out", out)
		return nil, err
	}

	infoLog("Tweaking apache config")
	if err := changeApacheConf(client, defaultApacheConfig); err != nil {
		return nil, err
	}

	infoLog("Setting up users' Web/ directory to be served by apache")
	out, err = client.StartCommand(webSetupCommand(username))
	if err != nil {
		fmt.Println("out", out)
		return nil, err
	}

	infoLog("Restarting apache2 with new config")
	out, err = client.StartCommand("a2enmod cgi && service apache2 restart")
	if err != nil {
		fmt.Println("out", out)
		return nil, err
	}

	query := kiteprotocol.Kite{ID: tknID.String()}

	infoLog("Connecting to remote Klient instance")
	klientRef, err := klient.NewWithTimeout(k.Kite, query.String(), time.Minute)
	if err != nil {
		k.Log.Warning("Connecting to remote Klient instance err: %s", err)
	} else {
		defer klientRef.Close()
		infoLog("Sending a ping message")
		if err := klientRef.Ping(); err != nil {
			k.Log.Warning("Sending a ping message err:", err)
		}
	}

	artifact.KiteQuery = query.String()
	return artifact, nil
}

// Build the command used to create the user
func createUserCommand(username string) string {
	// 1. Create user
	// 2. Remove user's password
	// 3. Add user to sudo group
	// 4. Add user to sudoers
	return fmt.Sprintf(`
adduser --shell /bin/bash --gecos 'koding user' --disabled-password --home /home/%[1]s %[1]s && \
passwd -d %[1]s && \
gpasswd -a %[1]s sudo  && \
echo '%[1]s    ALL = NOPASSWD: ALL' > /etc/sudoers.d/%[1]s
 `, username)

}

// webSetupCommand generates a bash command configuring apache for a given user
func webSetupCommand(username string) string {
	return fmt.Sprintf(`
rm -rf /var/www; \
ln -s /home/%s/Web /var/www
`, username)
}

// Build the klient.conf patching command
func patchConfCommand(username string) string {
	return fmt.Sprintf(
		// "sudo -E", preserves the environment variables when forking
		// so KITE_HOME set by the upstart script is preserved etc ...
		"sed -i 's/\\.\\/klient/sudo -E -u %s \\.\\/klient/g' /etc/init/klient.conf",
		username,
	)
}

// makeDirectoriesCommand ensures that all the user's default folders exist and
// creates them if they don't. This is not used right now, instead we use our
// AMI which already has all those.
func makeDirectoriesCommand(username string) string {
	return fmt.Sprintf(`
sudo -u %[1]s mkdir -p /home/%[1]s/Applications && \
sudo -u %[1]s mkdir -p /home/%[1]s/Backup && \
sudo -u %[1]s mkdir -p /home/%[1]s/Documents && \
sudo -u %[1]s mkdir -p /home/%[1]s/Web
`, username)
}

// changeHostname is used to change the remote machines hostname by modifying
// their /etc/host and /etc/hostname files.
func changeHostname(client *sshutil.SSHClient, hostname string) error {
	hostFile, err := client.Create("/etc/hosts")
	if err != nil {
		return err
	}

	if err := hostsTemplate.Execute(hostFile, hostname); err != nil {
		return err
	}

	hostnameFile, err := client.Create("/etc/hostname")
	if err != nil {
		return err
	}

	_, err = hostnameFile.Write([]byte(hostname))
	if err != nil {
		return err
	}

	out, err := client.StartCommand(fmt.Sprintf("hostname %s", hostname))
	if err != nil {
		fmt.Printf("out %+v\n", out)
		return err
	}

	return nil
}

// changeApacheConf is used to change apache's default configuration
// so that it listens on the port of our choice and serves /var/www
// rather than /var/www/html (/var/www is symlinked to user's ~/Web)
func changeApacheConf(client *sshutil.SSHClient, conf *apacheConfig) error {
	apacheFile, err := client.Create("/etc/apache2/sites-available/000-default.conf")
	if err != nil {
		return err
	}

	// Write conf file
	if err := apacheTemplate.Execute(apacheFile, conf); err != nil {
		return err
	}

	apachePortsFile, err := client.Create("/etc/apache2/ports.conf")
	if err != nil {
		return err
	}

	// Write /etc/apache2/ports.conf file
	return apachePortsTemplate.Execute(apachePortsFile, conf)
}
