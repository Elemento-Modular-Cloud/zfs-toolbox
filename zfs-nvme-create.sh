#!/bin/bash

# Determine the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Directory where presets are located
PRESET_DIR="$SCRIPT_DIR/presets"

# Default mount point
DEFAULT_MOUNTPOINT="/mnt/nvme_pool"

# Dry run flag
DRY_RUN=false

# Function to display usage information
usage() {
    echo "Usage: $0 [--dry-run] [-p|--preset PRESET_NAME] [-n|--pool POOL_NAME] [-m|--mountpoint MOUNTPOINT] [DISKS...]"
    echo "  --dry-run        Perform a dry run (echo commands instead of executing them)"
    echo "  -p, --preset     Name of the preset configuration (without .json)"
    echo "  -n, --pool       Name of the ZFS pool to be created"
    echo "  -m, --mountpoint Optional: Mount point for the ZFS pool (default: $DEFAULT_MOUNTPOINT)"
    echo "  DISKS            List of NVMe disks in ZFS vdev format (e.g., /dev/nvme0n1 /dev/nvme1n1)"
    echo ""
    echo "Example: $0 --preset vm --pool myzpool --mountpoint /mnt/zpool /dev/nvme0n1 /dev/nvme1n1"
}

# Function to calculate ashift value
calculate_ashift() {
    local DISK=$1
    local BSZ=$(blockdev --getbsz "$DISK")
    local ASHIFT=$(echo "l($BSZ)/l(2)" | bc -l | xargs printf "%.0f")
    echo $ASHIFT
}

# Wrapper function to execute zfs command or echo based on DRY_RUN flag
zfs_or_echo() {
    if [ "$DRY_RUN" = true ]; then
        echo "Dry run: $@"
    else
        if ! sudo -n true 2>/dev/null; then
            echo "Please enter your sudo password to continue:"
            sudo "$@"
        else
            sudo "$@"
        fi
    fi
}

# Function to create a ZFS pool with presets
create_pool_with_preset() {
    local PRESET_NAME=
    local POOL_NAME=
    local MOUNTPOINT=$DEFAULT_MOUNTPOINT
    local DISKS=()

    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -p|--preset)
                PRESET_NAME="$2"
                shift
                shift
                ;;
            -n|--pool)
                POOL_NAME="$2"
                shift
                shift
                ;;
            -m|--mountpoint)
                MOUNTPOINT="$2"
                shift
                shift
                ;;
            *)
                DISKS+=("$1")
                shift
                ;;
        esac
    done

    if [ -z "$PRESET_NAME" ] || [ -z "$POOL_NAME" ] || [ ${#DISKS[@]} -eq 0 ]; then
        echo "Error: Missing required parameters."
        usage
        exit 1
    fi

    local PRESET_FILE="$PRESET_DIR/$PRESET_NAME.json"

    # Validate preset file
    if [ ! -f "$PRESET_FILE" ]; then
        echo "Error: Preset file '$PRESET_FILE' not found."
        usage
        exit 1
    fi

    local ASHIFT=$(calculate_ashift "${DISKS[0]}")

    echo "Creating ZFS pool $POOL_NAME with disks: ${DISKS[@]}"
    echo "Using ashift=$ASHIFT"
    echo "Using preset file: $PRESET_FILE"

    # Read preset configuration from JSON file
    local PRESET_JSON=$(cat "$PRESET_FILE")
    local COMPRESSION=$(echo "$PRESET_JSON" | jq -r '.compression')
    local DEDUPLICATION=$(echo "$PRESET_JSON" | jq -r '.deduplication')
    local XATTR=$(echo "$PRESET_JSON" | jq -r '.xattr')
    local ACLTYPE=$(echo "$PRESET_JSON" | jq -r '.acltype')
    local ATIME=$(echo "$PRESET_JSON" | jq -r '.atime')
    local RELATIME=$(echo "$PRESET_JSON" | jq -r '.relatime')
    local SYNC=$(echo "$PRESET_JSON" | jq -r '.sync')
    local RECORDSIZE=$(echo "$PRESET_JSON" | jq -r '.recordsize')
    local LOGBIAS=$(echo "$PRESET_JSON" | jq -r '.logbias')
    local CHECKSUM=$(echo "$PRESET_JSON" | jq -r '.checksum')

    # Create ZFS pool
    zfs_or_echo set compression=$COMPRESSION $POOL_NAME
    zfs_or_echo set dedup=$DEDUPLICATION $POOL_NAME
    zfs_or_echo set xattr=$XATTR $POOL_NAME
    zfs_or_echo set acltype=$ACLTYPE $POOL_NAME
    zfs_or_echo set atime=$ATIME $POOL_NAME
    zfs_or_echo set relatime=$RELATIME $POOL_NAME
    zfs_or_echo set sync=$SYNC $POOL_NAME
    zfs_or_echo set recordsize=$RECORDSIZE $POOL_NAME
    zfs_or_echo set logbias=$LOGBIAS $POOL_NAME
    zfs_or_echo set checksum=$CHECKSUM $POOL_NAME

    # Set mount point
    zfs_or_echo set mountpoint=$MOUNTPOINT $POOL_NAME
}

# Main script logic
if [ $# -lt 1 ]; then
    usage
    exit 1
fi

# Check if sudo is required for ZFS commands
if ! sudo -n true 2>/dev/null; then
    echo "This script requires elevated privileges to manage ZFS."
    echo "Please enter your sudo password to continue:"
    sudo -v || exit 1
fi

# Parse command line options
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -p|--preset|-n|--pool|-m|--mountpoint)
            PARAMS+=("$1" "$2")
            shift
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            DISKS+=("$1")
            shift
            ;;
    esac
done

create_pool_with_preset "${PARAMS[@]}" "${DISKS[@]}"
