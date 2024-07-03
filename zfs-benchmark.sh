#!/bin/bash

# Function to disable ZFS caching
disable_zfs_cache() {
    echo "Disabling ZFS caching..."
    sudo zfs set primarycache=none $selected_pool
    sudo zfs set secondarycache=none $selected_pool
}

# Function to enable ZFS caching
enable_zfs_cache() {
    echo "Enabling ZFS caching..."
    sudo zfs set primarycache=all $selected_pool
    sudo zfs set secondarycache=all $selected_pool
}

# Function to handle cleanup on script exit
cleanup() {
    echo "Restoring ZFS caching settings..."
    enable_zfs_cache
    exit 0
}

# Function to select a ZFS pool interactively
select_zfs_pool() {
    pools=$(zpool list -H -o name)
    echo "Available ZFS pools:"
    echo "$pools"
    read -p "Select a ZFS pool to benchmark: " selected_pool
    mountpoint=$(zfs get -H -o value mountpoint $selected_pool)
}

# Generic benchmark function for fio
benchmark_generic_fio() {
    local target_dir=$1
    local result_dir="fio_results"
    local fio_job_file="fio-jobs/fio_generic.ini"

    echo "Benchmarking generic workloads on ZFS pool $selected_pool with fio..."
    mkdir -p $result_dir

    echo "Running fio command: fio $fio_job_file"
    fio $fio_job_file --output=$result_dir/fio_generic_$selected_pool.log --directory=$target_dir

    echo "Generic workloads benchmarking with fio complete. Results saved in $result_dir/fio_generic_$selected_pool.log"
}

# Generic benchmark function for iozone
benchmark_generic_iozone() {
    local target_dir=$1
    local result_dir="iozone_results"

    echo "Benchmarking generic workloads on ZFS pool $selected_pool with iozone..."
    mkdir -p $result_dir

    iozone -i 0 -i 1 -i 2 -r 4k -s 10G -t 4 -F $target_dir/testfile > $result_dir/iozone_generic_$selected_pool.log

    echo "Generic workloads benchmarking with iozone complete. Results saved in $result_dir/iozone_generic_$selected_pool.log"
}

# Function to benchmark VM volumes with fio
benchmark_vm_volumes_fio() {
    local target_dir=$1
    local result_dir="fio_results"
    local fio_job_file="fio-jobs/fio_vm_volumes.ini"

    echo "Benchmarking VM volumes on ZFS pool $selected_pool with fio..."
    mkdir -p $result_dir

    echo "Running fio command for VM volumes: fio $fio_job_file"
    fio $fio_job_file --output=$result_dir/fio_vm_volumes_$selected_pool.log --directory=$target_dir

    echo "VM volumes benchmarking with fio complete. Results saved in $result_dir/fio_vm_volumes_$selected_pool.log"
}

# Function to benchmark VM volumes with iozone
benchmark_vm_volumes_iozone() {
    local target_dir=$1
    local result_dir="iozone_results"

    echo "Benchmarking VM volumes on ZFS pool $selected_pool with iozone..."
    mkdir -p $result_dir

    iozone -i 0 -i 1 -i 2 -r 4k -r 64k -r 1024k -s 50G -t 8 -F $target_dir/testfile > $result_dir/iozone_vm_volumes_$selected_pool.log

    echo "VM volumes benchmarking with iozone complete. Results saved in $result_dir/iozone_vm_volumes_$selected_pool.log"
}

# Function to benchmark data workloads with fio
benchmark_data_fio() {
    local target_dir=$1
    local result_dir="fio_results"
    local fio_job_file="fio-jobs/fio_data.ini"

    echo "Benchmarking data workloads on ZFS pool $selected_pool with fio..."
    mkdir -p $result_dir

    echo "Running fio command for data workloads: fio $fio_job_file"
    fio $fio_job_file --output=$result_dir/fio_data_$selected_pool.log --directory=$target_dir

    echo "Data workloads benchmarking with fio complete. Results saved in $result_dir/fio_data_$selected_pool.log"
}

# Function to benchmark data workloads with iozone
benchmark_data_iozone() {
    local target_dir=$1
    local result_dir="iozone_results"

    echo "Benchmarking data workloads on ZFS pool $selected_pool with iozone..."
    mkdir -p $result_dir

    iozone -i 0 -i 1 -i 2 -s 200G -r 1M -t 1 -F $target_dir/testfile > $result_dir/iozone_data_$selected_pool.log

    echo "Data workloads benchmarking with iozone complete. Results saved in $result_dir/iozone_data_$selected_pool.log"
}

# Function to benchmark database workloads with fio
benchmark_database_fio() {
    local target_dir=$1
    local result_dir="fio_results"
    local fio_job_file="fio-jobs/fio_database.ini"

    echo "Benchmarking database workloads on ZFS pool $selected_pool with fio..."
    mkdir -p $result_dir

    echo "Running fio command for database workloads: fio $fio_job_file"
    fio $fio_job_file --output=$result_dir/fio_database_$selected_pool.log --directory=$target_dir

    echo "Database workloads benchmarking with fio complete. Results saved in $result_dir/fio_database_$selected_pool.log"
}

# Function to benchmark database workloads with iozone
benchmark_database_iozone() {
    local target_dir=$1
    local result_dir="iozone_results"

    echo "Benchmarking database workloads on ZFS pool $selected_pool with iozone..."
    mkdir -p $result_dir

    iozone -i 0 -i 1 -i 2 -i 8 -i 9 -s 100G -r 4k -r 64k -r 1024k -t 16 -F $target_dir/testfile > $result_dir/iozone_database_$selected_pool.log

    echo "Database workloads benchmarking with iozone complete. Results saved in $result_dir/iozone_database_$selected_pool.log"
}

# Function to output synthetic benchmark results
output_benchmark_results() {
    local result_dir=$1
    echo "==========================="
    echo "Fio Benchmark Results:"
    echo "==========================="
    grep -A 20 "fio.*WRITE" $result_dir/fio_generic_$selected_pool.log
    grep -A 20 "fio.*READ" $result_dir/fio_sequential_rw_$selected_pool.log
    grep -A 20 "fio.*WRITE" $result_dir/fio_vm_volumes_$selected_pool.log
    grep -A 20 "fio.*WRITE" $result_dir/fio_data_$selected_pool.log
    grep -A 20 "fio.*READ" $result_dir/fio_database_$selected_pool.log
    grep -A 20 "fio.*latency" $result_dir/fio_latency_$selected_pool.log

    echo "==========================="
    echo "Iozone Benchmark Results:"
    echo "==========================="
    grep "^\s*Children" $result_dir/iozone_generic_$selected_pool.log
    grep "^\s*Children" $result_dir/iozone_vm_volumes_$selected_pool.log
    grep "^\s*Children" $result_dir/iozone_data_$selected_pool.log
    grep "^\s*Children" $result_dir/iozone_database_$selected_pool.log
}

# Trap script exit to restore ZFS caching settings
trap cleanup EXIT

# Select the ZFS pool to benchmark
select_zfs_pool

# Disable ZFS caching
disable_zfs_cache

# Run generic benchmarks
benchmark_generic_fio $mountpoint
# benchmark_generic_iozone $mountpoint

# Run VM volumes benchmarks
# benchmark_vm_volumes_fio $mountpoint
# benchmark_vm_volumes_iozone $mountpoint

# Run data workloads benchmarks
# benchmark_data_fio $mountpoint
# benchmark_data_iozone $mountpoint

# Run database workloads benchmarks
# benchmark_database_fio $mountpoint
# benchmark_database_iozone $mountpoint

# Output synthetic benchmark results
output_benchmark_results "fio_results"
# output_benchmark_results "iozone_results"

# Enable ZFS caching
enable_zfs_cache

echo "Benchmarking complete!"
