#!/bin/bash

# Function to print the tree-like structure
print_tree() {
    local prefix="$1"
    local class="$2"
    local label="$3"
    local indent="|-- "
    local sub_indent="|   "

    echo "${prefix}${indent}${label}"
    
    if [[ "$class" == "storage" ]]; then
        local devices=$(echo "$lshw_output" | awk "/$label/,/\*-disk/")
    else
        local devices=$(echo "$lshw_output" | awk "/$label/,/^\*-/")
    fi
    
    echo "$devices" | grep -E "product:|serial:" | sed "s/^/${prefix}${sub_indent}/"
}

# Get lshw output for storage and disk class
lshw_output=$(sudo lshw -class storage -class disk)

# Process the output to build the tree structure
while IFS= read -r line; do
    if [[ "$line" =~ \*-storage ]]; then
        storage_label=$(echo "$line" | sed 's/.*-storage //')
        print_tree "" "storage" "$storage_label"
    elif [[ "$line" =~ \*-disk ]]; then
        disk_label=$(echo "$line" | sed 's/.*-disk //')
        print_tree "    " "disk" "$disk_label"
    fi
done <<< "$lshw_output"
