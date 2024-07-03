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

# Display the hierarchical relationship in a tree-like format
for ((i=1; i<=controller_count; i++)); do
    if [[ $i -gt 1 ]]; then
        echo -e "│"
    fi
    echo -e "├── controller$i"
    disk_count=${controllers["controller$i"]}
    for ((j=1; j<=disk_count; j++)); do
        if [[ $j -lt $disk_count ]]; then
            echo -e "│   ├── disk$j"
        else
            echo -e "│   └── disk$j"
        fi
    done
done
