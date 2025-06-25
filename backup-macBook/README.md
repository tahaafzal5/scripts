# backupMacBookToFlashDrive.sh

## Run
```
$ backupMacBookToFlashDrive.sh <name of the drive>
```

## Use on macOS and Raspberry Pi OS
* **Note:** Tested with macOS 15.5 (macOS Sequoia) & "Debian GNU/Linux 12 (bookworm)"
* Both the listed OS versions support reading and writing on a flash drive formatted as exFAT.

### Format as exFAT
```
$ diskutil unmountDisk /dev/<disk-name>
$ diskutil eraseDisk exFAT <new name of disk> /dev/<disk-name>
```
