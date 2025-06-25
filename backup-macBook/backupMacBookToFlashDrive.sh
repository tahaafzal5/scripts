#!/bin/zsh

# Purpose: Backup MacBook to flash drive
# Usage: From any directory, run: ./backupMacBookToFlashDrive.sh <flash drive name>

# Function to check if flash drive is mounted
check_flash_drive_mounted() {
    if [ ! -d /Volumes/$1 ]; then
        echo "Flash drive named '$1' not mounted"
        exit 1
    fi
}

# Function to perform the backup
perform_backup() {
    baseDir="/Users/tahaafzal/"
    sourceDirs=("swdev" "Desktop" "Downloads" "Documents" "Movies" "Movies/TV Series" "Pictures")
    destination="/Volumes/$1"

    for sourceDir in "${sourceDirs[@]}"; do
        echo "Backing up $baseDir$sourceDir..."
        rsync -azh --info=progress2 --delete --exclude 'TV' --exclude '*.imovielibrary' --exclude '*.photoslibrary' \
              --exclude '*.theater' "$baseDir$sourceDir" "$destination"
    done
}

# Function to unmount flash drive
unmount_flash_drive() {
    echo "Unmounting flash drive..."
    diskutil unmount /Volumes/$1
}

# Check if script is being run with incorrect number of arguments
if [ $# -ne 1 ]; then
    echo "Usage: backupMacBookToFlashDrive.sh <flash drive name>"
    exit 1
fi

check_flash_drive_mounted $1
perform_backup $1
unmount_flash_drive $1
status=$?

echo "Backup completed with exit status $status"
exit $status
