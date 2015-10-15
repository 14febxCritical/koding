package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/codegangsta/cli"
	"github.com/koding/klient/cmd/klientctl/errors"
	"github.com/koding/klient/cmd/klientctl/util"
)

// MountCommand mounts a folder on remote machine to local folder by machine
// name.
func MountCommand(c *cli.Context) int {
	if len(c.Args()) < 2 {
		cli.ShowCommandHelp(c, "mount")
		return 1
	}

	var (
		name       = c.Args()[0]
		localPath  = c.Args()[1]
		remotePath = c.String("remotepath") // note the lowercase of all chars
	)

	// allow scp like declaration, ie `<machine name>:/path/to/remote`
	if strings.Contains(name, ":") {
		names := strings.Split(name, ":")
		name, remotePath = names[0], names[1]
	}

	// send absolute local path to klient unless local path is empty
	if strings.TrimSpace(localPath) != "" {
		absoluteLocalPath, err := filepath.Abs(localPath)
		if err == nil {
			localPath = absoluteLocalPath
		}
	}

	// Ask the user if they want the localPath created, if it does not exist.
	if err := askToCreate(localPath, os.Stdout, os.Stdin); err != nil {
		fmt.Printf(
			"Error: Unable to create specified localPath '%s'",
			localPath)
		return 1
	}

	// Check if the local path exists, and ask the user if they want to create it

	mountRequest := struct {
		Name       string `json:"name"`
		LocalPath  string `json:"localPath"`
		RemotePath string `json:"remotePath"`
	}{
		Name:      name,
		LocalPath: localPath,
	}

	// RemotePath is optional
	if remotePath != "" {
		mountRequest.RemotePath = remotePath
	}

	k, err := CreateKlientClient(NewKlientOptions())
	if err != nil {
		fmt.Printf("Error connecting to remove machine: '%s'\n", err)
		return 1
	}

	if err := k.Dial(); err != nil {
		fmt.Printf("Error connecting to remove machine: '%s'\n", err)
		return 1
	}

	resp, err := k.Tell("remote.mountFolder", mountRequest)
	if err != nil {
		fmt.Printf("Error mounting folder: '%s'\n", err)
		return 1
	}

	// response can be nil even when there's no err
	if resp != nil {
		var warning string
		if err := resp.Unmarshal(&warning); err != nil {
			return 0
		}

		if len(warning) > 0 {
			fmt.Printf("Warning: %s\n\n", warning)
		}
	}

	fmt.Println("Successfully mounted:", localPath)

	return 0
}

// askToCreate checks if the folder does not exist, and creates it
// if the user chooses to. If the user does *not* choose to create it,
// we return an IsNotExist error.
func askToCreate(p string, w io.Writer, r io.Reader) error {
	_, err := os.Stat(p)

	// If we fail to stat the file, and it's *not* IsNotExist, we may be
	// having permission issues or some other related issue. Return
	// the error.
	if err != nil && !os.IsNotExist(err) {
		return err
	}

	// If there was no error stating the path, it already exists -
	// we can return, as there's nothing we need to do.
	if err == nil {
		return nil
	}

	fmt.Fprintln(w,
		"The mount folder does not exist, would you like to create it? [Y/n]",
	)

	// Retry YesNo confirmation 3 times if needed
	var createFolder bool
	for i := 0; i < 3; {
		createFolder, err = util.YesNoConfirmWithDefault(r, true)
		// If the user supplied an accepted value, stop trying
		if err == nil {
			break
		}
		// If err != nil, then the error did not provide an understood
		// response.
		fmt.Fprintln(w, "Invalid response, please type 'yes' or 'no'")
	}

	// If the retry loop exited with an error, the user failed to give
	// a meaningful response to the YesNo confirmation.
	if err != nil {
		return err
	}

	// The user chose not to create the folder. We cannot mount something that
	// doesn't exist - so we must fail here with an error.
	if !createFolder {
		return errs.UserCancelled
	}

	err = os.Mkdir(p, 0655)
	if err != nil {
		return err
	}

	return nil
}
