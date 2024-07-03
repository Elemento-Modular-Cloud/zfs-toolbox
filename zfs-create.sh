#!/bin/bash

# Determine the directory where the script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Directory where presets are located
SSD_PRESET_DIR="$SCRIPT_DIR/ssd-presets"
HDD_PRESET_DIR="$SCRIPT_DIR/hdd-presets"

# Default mount point
DEFAULT_MOUNTPOINT="/mnt/zpool"

# Dry run flag
DRY_RUN=false

# Function to display usage information
usage() {
    echo "Usage: $0 [--dry-run] [-p|--preset PRESET_NAME] [-n|--pool POOL_NAME] [-m|--mountpoint MOUNTPOINT] [DISKS...]"
    echo "       $0 --hdd|--ssd [-p PRESET_NAME] [-n POOL_NAME] [-m MOUNTPOINT] [DISKS...]"
    echo ""
    echo "Options:"
    echo "  --dry-run        Perform a dry run (echo commands instead of executing them)"
    echo "  -p, --preset     Name of the preset configuration (without .json)"
    echo "  -n, --pool       Name of the ZFS pool to be created"
    echo "  -m, --mountpoint Optional: Mount point for the ZFS pool (default: $DEFAULT_MOUNTPOINT)"
    echo "  --hdd            Assume all disks are HDDs"
    echo "  --ssd            Assume all disks are SSDs"
    echo "  DISKS            List of disks in ZFS vdev format (e.g., /dev/disk/by-id/...)"
    echo ""
    echo "Examples:"
    echo "  $0 --ssd --preset vm --pool myzpool --mountpoint /mnt/zpool /dev/disk/by-id/..."
    echo "  $0 /dev/disk/by-id/..."
}

# Function to calculate ashift value
calculate_ashift() {
    local DISK=$1
    local BSZ=$(blockdev --getbsz "$DISK")
    local ASHIFT=$(echo "l($BSZ)/l(2)" | bc -l | xargs printf "%.0f")
    echo $ASHIFT
}

# Wrapper function to execute commands or echo based on DRY_RUN flag
run_or_echo() {
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

# Function to determine if a disk is an SSD
is_ssd() {
    local DISK=$1
    local ROTA=$(lsblk -no rota "$DISK" | head -n 1)
    if [ "$ROTA" -eq 0 ]; then
        return 0  # SSD
    else
        return 1  # HDD
    fi
}

# Function to interactively ask user to choose between SSD or HDD assumption
ask_disk_type() {
    local DISK=$1
    local TYPE=
    while true; do
        read -p "Disk $DISK is detected as SSD. Is this correct? [Y/n]: " answer
        case $answer in
            [Yy]*)
                TYPE="ssd"
                break
                ;;
            [Nn]*)
                TYPE="hdd"
                break
                ;;
            *)
                echo "Please answer Y or n."
                ;;
        esac
    done
    echo "$TYPE"
}

# Function to create a ZFS pool with presets based on disk type
create_pool_with_preset() {
    local PRESET_NAME=
    local POOL_NAME=
    local MOUNTPOINT=$DEFAULT_MOUNTPOINT
    local DISKS=()
    local ASSUMED_TYPE=

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
            --ssd)
                ASSUMED_TYPE="ssd"
                shift
                ;;
            --hdd)
                ASSUMED_TYPE="hdd"
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

    # Determine the type of each disk
    local FIRST_DISK="${DISKS[0]}"
    if [ ! -e "$FIRST_DISK" ] ; then
        FIRST_DISK="${DISKS[1]}"
    fi

    echo "First valid disk is $FIRST_DISK"

    if [ -z "$ASSUMED_TYPE" ]; then
        local ALL_SAME_TYPE=true
        local ASSUMED_TYPE=""

        for disk in "${DISKS[@]}"; do
            echo "Checking disk $disk"
            if [ -e "$disk" ] ; then
                if is_ssd "$disk"; then
                    echo "Is SSD"
                    if [ "$ASSUMED_TYPE" = "hdd" ]; then
                        ALL_SAME_TYPE=false
                        break
                    elif [ -z "$ASSUMED_TYPE" ]; then
                        ASSUMED_TYPE="ssd"
                    fi
                else
                    echo "Is HDD"
                    if [ "$ASSUMED_TYPE" = "ssd" ]; then
                        ALL_SAME_TYPE=false
                        break
                    elif [ -z "$ASSUMED_TYPE" ]; then
                        ASSUMED_TYPE="hdd"
                    fi
                fi
            fi
        done

        if ! $ALL_SAME_TYPE; then
            # Prompt user to choose SSD or HDD assumption
            ASSUMED_TYPE=$(ask_disk_type "$FIRST_DISK")
        fi
    fi

    # Select preset directory based on assumed disk type
    if [ "$ASSUMED_TYPE" = "ssd" ]; then
        local PRESET_FILE="$SSD_PRESET_DIR/$PRESET_NAME.json"
    elif [ "$ASSUMED_TYPE" = "hdd" ]; then
        local PRESET_FILE="$HDD_PRESET_DIR/$PRESET_NAME.json"
    else
        echo "Error: Unable to determine disk type assumption."
        exit 1
    fi

    # Validate preset file
    if [ ! -f "$PRESET_FILE" ]; then
        echo "Error: Preset file '$PRESET_FILE' not found."
        usage
        exit 1
    fi

    local ASHIFT=$(calculate_ashift "$FIRST_DISK")

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

    # Create ZFS pool with preset configurations
    run_or_echo zpool create -o ashift=$ASHIFT $POOL_NAME $DISKS
    run_or_echo zfs set compression=$COMPRESSION $POOL_NAME
    run_or_echo zfs set compression=$COMPRESSION $POOL_NAME
    run_or_echo zfs set dedup=$DEDUPLICATION $POOL_NAME
    run_or_echo zfs set xattr=$XATTR $POOL_NAME
    run_or_echo zfs set acltype=$ACLTYPE $POOL_NAME
    run_or_echo zfs set atime=$ATIME $POOL_NAME
    run_or_echo zfs set relatime=$RELATIME $POOL_NAME
    run_or_echo zfs set sync=$SYNC $POOL_NAME
    run_or_echo zfs set recordsize=$RECORDSIZE $POOL_NAME
    run_or_echo zfs set logbias=$LOGBIAS $POOL_NAME
    run_or_echo zfs set checksum=$CHECKSUM $POOL_NAME

    # Set autotrim on for SSDs
    if [ "$ASSUMED_TYPE" = "ssd" ]; then
        run_or_echo set autotrim=on $POOL_NAME
    fi

    # Set mount point
    run_or_echo set mountpoint=$MOUNTPOINT $POOL_NAME
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
        --ssd)
            ASSUMED_TYPE="ssd"
            shift
            ;;
        --hdd)
            ASSUMED_TYPE="hdd"
            shift
            ;;
        *)
            DISKS+=("$1")
            shift
            ;;
    esac
done

create_pool_with_preset "${PARAMS[@]}" "${DISKS[@]}"
