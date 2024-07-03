#!/bin/bash

# Function to run lshw command and capture output
run_lshw() {
    sudo lshw -class storage -class disk
}

# Function to parse lshw output and organize into a structured array
parse_lshw() {
    local output="$1"
    local current_controller=""
    local disk_number=1

    # Array to hold structured information
    declare -A controllers

    while IFS= read -r line; do
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//')

        if [[ $line =~ \*-([a-zA-Z0-9]+) ]]; then
            current_controller=${BASH_REMATCH[1]}
            controllers[$current_controller]=""
            disk_number=1
        elif [[ $line =~ disk([0-9]+):[[:space:]]+(.*) ]]; then
            disk_info="${BASH_REMATCH[2]}"
            controllers[$current_controller]+="disk$disk_number: $disk_info\n"
            (( disk_number++ ))
        fi
    done <<< "$output"

    # Print structured information
    for controller in "${!controllers[@]}"; do
        printf "├── %s:\n" "$controller"
        printf "%s\n" "${controllers[$controller]}"
    done
}

# Main function
main() {
    lshw_output=$(run_lshw)
    if [[ -n "$lshw_output" ]]; then
        parse_lshw "$lshw_output"
    else
        echo "Failed to retrieve lshw output."
    fi
}

# Execute main function
main
