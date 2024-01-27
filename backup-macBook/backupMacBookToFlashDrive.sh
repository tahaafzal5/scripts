#!/bin/zsh

# Purpose: Backup MacBook to flash drive
# Usage: From any directory, run: ./backupMacBookToFlashDrive.sh <flash drive name>

# Declare global variable
displaySleepTime=""
power_source=""

# Function to check if flash drive is mounted
check_flash_drive_mounted() {
    if [ ! -d /Volumes/$1 ]; then
        echo "Flash drive named '$1' not mounted"
        exit 1
    fi
}

# Function to save and set display sleep time based on power source
set_display_sleep_time() {
    displaySleepTime=$(pmset -g | grep " displaysleep" | awk '{print $2}')
    power_source=$(pmset -g batt | grep "Now drawing from" | awk '{print $4}' | tr -d "'")

    if [ $power_source = "AC" ]; then
        echo "MacBook is currently charging."
        sudo pmset -c displaysleep 0
        echo "displaysleep set to 0 for AC power."
    else
        echo "MacBook is currently on battey power."
        sudo pmset -b displaysleep 0
        echo "displaysleep set to 0 for battery power."
    fi
}

# Function to perform the backup
perform_backup() {
    baseDir="/Users/tahaafzal/"
    sourceDirs=("swdev" "Desktop" "Downloads" "Documents" "Movies" "Movies/TV Series" "Pictures")
    destination="/Volumes/$1"

    for sourceDir in "${sourceDirs[@]}"; do
        echo "Backing up $baseDir$sourceDir..."
        rsync -azvPh --delete --exclude 'TV' --exclude '*.imovielibrary' --exclude '*.photoslibrary' \
              --exclude '*.theater' "$baseDir$sourceDir" "$destination"
    done
}

# Function to unmount flash drive
unmount_flash_drive() {
    echo "Unmounting flash drive..."
    diskutil unmount /Volumes/$1
}

# Function to restore display sleep time settings
restore_display_sleep_time() {
    if [ $power_source = "AC" ]; then
        sudo pmset -c displaysleep $displaySleepTime
        echo "displaysleep set to $displaySleepTime for AC power."
    else
        sudo pmset -b displaysleep $displaySleepTime
        echo "displaysleep set to $displaySleepTime for battery power."
    fi
}

# Check if script is being run with incorrect number of arguments
if [ $# -ne 1 ]; then
    echo "Usage: backupMacBookToFlashDrive.sh <flash drive name>"
    exit 1
fi

check_flash_drive_mounted $1
set_display_sleep_time
perform_backup $1
unmount_flash_drive $1
restore_display_sleep_time

# Print exit status
echo "Backup completed with exit status $?"
exit 0
