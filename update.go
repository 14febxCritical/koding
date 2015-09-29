package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"github.com/mitchellh/cli"
)

func UpdateCommandFactory() (cli.Command, error) {
	return &UpdateCommand{}, nil
}

type UpdateCommand struct{}

func (u *UpdateCommand) Run(_ []string) int {
	checkUpdate := NewCheckUpdate()

	// by pass random checking to force checking for update
	checkUpdate.ForceCheck = true

	yesUpdate, err := checkUpdate.IsUpdateAvailable()
	if err != nil {
		fmt.Printf("Error checking if update is available: '%s'\n", err)
		return 1
	}

	if !yesUpdate {
		fmt.Println("No update available.")
		return 0
	}

	s, err := newService()
	if err != nil {
		fmt.Printf("Error stopping %s: '%s'\n", KlientName, err)
		return 1
	}

	fmt.Printf("Stopping %s...\n", KlientName)

	// stop klient before we update it
	if err := s.Stop(); err != nil {
		fmt.Printf("Error stopping %s: '%s'\n", KlientName, err)
		return 1
	}

	// download klient and kd to approprite place
	dlPaths := map[string]string{
		// /opt/kite/klient/klient
		filepath.Join(KlientDirectory, "klient"): S3KlientPath,

		// /usr/local/bin/kd
		filepath.Join(KlientctlDirectory, "kd"): S3KlientctlPath,
	}

	fmt.Println("Updating...")

	for localPath, remotePath := range dlPaths {
		if err := downloadRemoteToLocal(remotePath, localPath); err != nil {
			fmt.Printf("Error updating %s: '%s'\n", Name, err)
			return 1
		}
	}

	// start klient now that it's done updating
	if err := s.Start(); err != nil {
		fmt.Printf("Error starting %s: '%s'\n", KlientName, err)
		return 1
	}

	fmt.Printf("Successfully updated to latest version of %s.\n", Name)

	return 0
}

func (u *UpdateCommand) Help() string {
	helpText := `
Usage: sudo %s update

		Update to latest version. sudo is required.
`
	return fmt.Sprintf(helpText, Name)
}

func (u *UpdateCommand) Synopsis() string {
	return "Update to latest version. sudo required."
}

func downloadRemoteToLocal(remotePath, destPath string) error {
	// create the destination dir, if needed.
	if err := os.MkdirAll(filepath.Dir(destPath), 0755); err != nil {
		return err
	}

	// open file in specified path to write to
	perms := os.O_WRONLY | os.O_CREATE | os.O_TRUNC
	binFile, err := os.OpenFile(destPath, perms, 0755)
	if err != nil {
		if binFile != nil {
			binFile.Close()
		}

		return nil
	}

	// get from remote
	res, err := http.Get(remotePath)
	if err != nil {
		return err
	}
	defer res.Body.Close()

	// copy remote file to destination path
	if _, err := io.Copy(binFile, res.Body); err != nil {
		return err
	}

	return binFile.Close()
}
