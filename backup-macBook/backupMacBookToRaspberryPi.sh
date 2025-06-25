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
    echo "Checking if USB '$USB_NAME' is mounted on Raspberry Pi..."
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
        rsync -azh --info=progress2 --delete --exclude 'TV' --exclude '*.imovielibrary' \
              --exclude '*.photoslibrary' --exclude '*.theater' \
              "$baseDir$sourceDir" "$DESTINATION"
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
perform_backup
status=$?

echo "Backup completed with exit status $status"
exit $status
