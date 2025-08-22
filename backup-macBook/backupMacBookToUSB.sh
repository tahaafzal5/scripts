#!/bin/zsh

# Purpose: Backup MacBook to local USB drive
# Usage: ./backupMacBookToUSB.sh <usb-name>

# Globals
USB_NAME=""
USB_MOUNT="/Volumes"
DESTINATION=""
DISPLAY_SLEEP_TIME=""
POWER_SOURCE=""

# Function to save and set display sleep time based on power source
set_display_sleep_time() {
    DISPLAY_SLEEP_TIME=$(pmset -g | grep " displaysleep" | awk '{print $2}')
    POWER_SOURCE=$(pmset -g batt | grep "Now drawing from" | awk '{print $4}' | tr -d "'")

    if [ $POWER_SOURCE = "AC" ]; then
        echo "MacBook is currently charging."
        sudo pmset -c displaysleep 0
        echo "displaysleep set to 0 for AC power."
    else
        echo "MacBook is currently on battey power."
        sudo pmset -b displaysleep 0
        echo "displaysleep set to 0 for battery power."
    fi
}

# Function to restore display sleep time settings
restore_display_sleep_time() {
    if [ $POWER_SOURCE = "AC" ]; then
        sudo pmset -c displaysleep $DISPLAY_SLEEP_TIME
        echo "displaysleep set to $DISPLAY_SLEEP_TIME for AC power."
    else
        sudo pmset -b displaysleep $DISPLAY_SLEEP_TIME
        echo "displaysleep set to $DISPLAY_SLEEP_TIME for battery power."
    fi
}

# Function to validate arguments
validate_args() {
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <usb-name>"
        exit 1
    fi
    USB_NAME=$1
    DESTINATION="$USB_MOUNT/$USB_NAME"
}

# Function to check if USB is mounted
check_usb_mounted() {
    if [ ! -d "$DESTINATION" ]; then
        echo "USB drive '$USB_NAME' not mounted at $DESTINATION"
        exit 1
    fi
    echo "USB drive '$USB_NAME' is mounted at $DESTINATION"
}

# Function to perform the backup
perform_backup() {
    baseDir="/Users/tahaafzal/"
    sourceDirs=("swdev" "Desktop" "Downloads" "Documents" "Movies" "Movies/TV Series" "Pictures")

    for sourceDir in "${sourceDirs[@]}"; do
        echo "Backing up $baseDir$sourceDir to USB drive..."

        if [ "$sourceDir" = "Movies" ] || [ "$sourceDir" = "Movies/TV Series" ] || [ "$sourceDir" = "Pictures" ]; then
            # Backup these directories without the --delete flag
            rsync -azh --info=progress2 --exclude 'TV' --exclude '*.imovielibrary' --exclude '*.photoslibrary' --exclude '*.theater' \
                  "$baseDir$sourceDir" "$DESTINATION"
        else
            rsync -azh --info=progress2 --delete "$baseDir$sourceDir" "$DESTINATION"
        fi
    done
}

# Main execution
echo "Script ran at: $(date)"
validate_args "$@"
check_usb_mounted
set_display_sleep_time
perform_backup
restore_display_sleep_time

status=$?

echo "Backup completed with exit status $status"
exit $status
