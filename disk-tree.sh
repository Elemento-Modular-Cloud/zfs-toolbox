#!/bin/bash

# Function to run lshw command and capture output
run_lshw() {
    sudo lshw -class storage -class disk
}

# Function to parse lshw output and organize into a structured array
parse_lshw() {
    local output="$1"
    local current_controller=""
    local current_disk=""
    local controllers=()

    echo "$output"

    while IFS= read -r line; do
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//')

        if [[ $line =~ \*-([a-zA-Z0-9]+) ]]; then
            current_controller=${BASH_REMATCH[1]}
            controllers+=("$current_controller")
        elif [[ $line =~ \*-namespace:([0-9]+) ]]; then
            current_disk=$(echo "$line" | awk '{print $2}')
            printf "├── %s:\n" "$current_controller"
            printf "    └── %s\n" "$current_disk"
        elif [[ $line =~ \*-disk:([0-9]+) ]]; then
            current_disk=$(echo "$line" | awk -F ': ' '{print $2}')
            printf "├── %s:\n" "$current_controller"
            printf "    └── %s\n" "$current_disk"
        fi
    done <<< "$output"
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
