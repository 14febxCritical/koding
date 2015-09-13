package unmount

import (
	"fmt"
	"os/exec"
)

// Unmount un mounts Fuse mounted local folder. Mount exists separate to
// lifecycle of this program and needs to be cleaned up when this exists.
func Unmount(folder string) error {
	fmt.Println("Unmounting...\n")

	if _, err := exec.Command("sudo", "umount", folder).CombinedOutput(); err != nil {
		fmt.Printf("Unmounting failed. Please do `sudo umount %s`.\n", folder)
	}

	return err
}
