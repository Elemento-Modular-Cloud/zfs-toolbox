#!/bin/bash

# Run the lshw command to get storage and disk information
output=$(sudo lshw -class storage -class disk)

# Initialize variables
controller_count=0
disk_count=0
declare -A controllers

# Parse the lshw output
while IFS= read -r line; do
    line=$(echo "$line" | sed 's/^[ \t]*//')
    
    if [[ "$line" == *-nvme* || "$line" == *-sata* ]]; then
        if [[ $controller_count -ne 0 ]]; then
            controllers["controller$controller_count"]="$disk_count"
        fi
        ((controller_count++))
        disk_count=0
    elif [[ "$line" == description:*ATA*Disk* || "$line" == description:*NVMe*disk* ]]; then
        ((disk_count++))
    fi
done <<< "$output"

# Add the last controller to the array
controllers["controller$controller_count"]="$disk_count"

# Display the hierarchical relationship
for ((i=1; i<=controller_count; i++)); do
    echo "controller$i"
    echo "|"
    disk_count=${controllers["controller$i"]}
    for ((j=1; j<=disk_count; j++)); do
        echo "_____disk$j"
    done
done
