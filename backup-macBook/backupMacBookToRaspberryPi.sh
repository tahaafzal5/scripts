#!/bin/zsh

# Purpose: Backup MacBook to USB on Raspberry Pi via SSH
# Usage: ./backupMacBookToRaspberryPi.sh <usb-name>

# Raspberry Pi details
PI_USER="taha"
PI_HOST="raspberrypi"

# Globals
USB_NAME=""
PI_USB_MOUNT=""
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
    PI_USB_MOUNT="/media/$PI_USER/$USB_NAME"
    DESTINATION="$PI_USER@$PI_HOST:$PI_USB_MOUNT"
}

# Function to check if Raspberry Pi USB is mounted
check_usb_mounted_on_pi() {
    ssh "$PI_USER@$PI_HOST" "mount | grep -q '$PI_USB_MOUNT'" || {
        echo "USB drive '$USB_NAME' not mounted at $PI_USB_MOUNT on Raspberry Pi."
        exit 1
    }
    echo "USB drive '$USB_NAME' is mounted."
}

# Function to perform the backup
perform_backup() {
    baseDir="/Users/tahaafzal/"
    sourceDirs=("swdev" "Desktop" "Downloads" "Documents" "Movies" "Movies/TV Series" "Pictures")

    for sourceDir in "${sourceDirs[@]}"; do
        echo "Backing up $baseDir$sourceDir to Raspberry Pi..."

        if [ "$sourceDir" = "Pictures" ]; then
            # Backup Pictures without --delete flag
            rsync -azh --info=progress2 --exclude '*.photoslibrary' \
                  "$baseDir$sourceDir" "$DESTINATION"
        else
            rsync -azh --info=progress2 --delete --exclude 'TV' --exclude '*.imovielibrary' \
                    --exclude '*.theater' "$baseDir$sourceDir" "$DESTINATION"
        fi
    done
}

# Main execution
echo "Script ran at: $(date)"
validate_args "$@"

echo "Testing SSH connection to Raspberry Pi..."
if ! ssh -o ConnectTimeout=5 "$PI_USER@$PI_HOST" 'echo Connection successful'; then
    echo "Cannot connect to Raspberry Pi. Please check network and SSH access."
    exit 1
fi

check_usb_mounted_on_pi
set_display_sleep_time
perform_backup
restore_display_sleep_time

status=$?

echo "Backup completed with exit status $status"
exit $status
