#!/bin/bash

# Function to disable ZFS caching
disable_zfs_cache() {
    echo "Disabling ZFS caching..."
    arcstats_before=$(awk '/^size/ {print $3}' /proc/spl/kstat/zfs/arcstats)
    arcmax_before=$(awk '/^c_max/ {print $3}' /proc/spl/kstat/zfs/arcstats)

    echo 1 > /sys/module/zfs/parameters/zfs_prefetch_disable

    arcstats_after=$(awk '/^size/ {print $3}' /proc/spl/kstat/zfs/arcstats)
    arcmax_after=$(awk '/^c_max/ {print $3}' /proc/spl/kstat/zfs/arcstats)

    echo "ARC size reduced from $arcstats_before to $arcstats_after"
    echo "ARC c_max reduced from $arcmax_before to $arcmax_after"
}

# Function to enable ZFS caching
enable_zfs_cache() {
    echo "Enabling ZFS caching..."
    echo 0 > /sys/module/zfs/parameters/zfs_prefetch_disable
}

# Function to cleanup on script exit
cleanup() {
    echo "Performing cleanup..."
    enable_zfs_cache
    exit
}

# Function to list ZFS pools and prompt user to choose one
select_zfs_pool() {
    local pools=($(zpool list -H -o name))
    
    echo "Available ZFS pools:"
    for (( i=0; i<${#pools[@]}; i++ )); do
        echo "[$((i+1))] ${pools[$i]}"
    done
    
    local choice
    read -p "Enter the number corresponding to the ZFS pool you want to benchmark: " choice
    
    if [[ $choice -ge 1 && $choice -le ${#pools[@]} ]]; then
        selected_pool=${pools[$((choice-1))]}
        echo "Selected ZFS pool: $selected_pool"
    else
        echo "Invalid choice. Exiting."
        exit 1
    fi
}

# Function to perform generic benchmarks (random read/write, sequential read/write, latency) with fio
benchmark_generic_fio() {
    local pool_name=$1
    local result_dir="fio_results"
    local fio_random_rw="fio_random_rw.ini"
    local fio_sequential_rw="fio_sequential_rw.ini"
    local fio_latency="fio_latency.ini"

    echo "Benchmarking generic workloads on ZFS pool $pool_name with fio..."
    mkdir -p $result_dir
    cd $result_dir || exit

    # Create fio job file for random read/write
    cat << EOF > $fio_random_rw
[global]
rw=randrw
direct=1
ioengine=libaio
bs=4k
size=10G
numjobs=4
runtime=180
directory=$pool_name
EOF

    # Create fio job file for sequential read/write
    cat << EOF > $fio_sequential_rw
[global]
rw=rw
direct=1
ioengine=libaio
bs=1M
size=50G
numjobs=4
runtime=300
directory=$pool_name
EOF

    # Create fio job file for latency test
    cat << EOF > $fio_latency
[global]
rw=randrw
direct=1
ioengine=libaio
bs=4k
size=1G
numjobs=1
runtime=60
directory=$pool_name
EOF

    echo "Running fio command for random read/write: fio $fio_random_rw"
    fio $fio_random_rw > fio_random_rw_$pool_name.log

    echo "Running fio command for sequential read/write: fio $fio_sequential_rw"
    fio $fio_sequential_rw > fio_sequential_rw_$pool_name.log

    echo "Running fio command for latency test: fio $fio_latency"
    fio $fio_latency > fio_latency_$pool_name.log

    cd ..
    echo "Generic benchmarks with fio complete. Results saved in $result_dir"
}

# Function to perform generic benchmarks (random read/write, sequential read/write, latency) with iozone
benchmark_generic_iozone() {
    local pool_name=$1
    local result_dir="iozone_results"

    echo "Benchmarking generic workloads on ZFS pool $pool_name with iozone..."
    mkdir -p $result_dir
    cd $result_dir || exit

    iozone -i 0 -i 1 -i 2 -i 8 -i 9 -s 10G -r 4k -r 64k -r 1024k -t 4 -F $pool_name/testfile > iozone_generic_$pool_name.log

    cd ..
    echo "Generic benchmarks with iozone complete. Results saved in $result_dir"
}

# Function to benchmark random read/write for VM volumes with fio
benchmark_vm_volumes_fio() {
    local pool_name=$1
    local result_dir="fio_results"
    local fio_job_file="fio_vm_volumes.ini"

    echo "Benchmarking VM volumes on ZFS pool $pool_name with fio..."
    mkdir -p $result_dir
    cd $result_dir || exit

    # Create a fio job file for VM volumes
    cat << EOF > $fio_job_file
[global]
rw=randrw
direct=1
ioengine=libaio
bs=4k
size=10G  # Adjust size according to your VM volume size
numjobs=4
runtime=180  # Adjust runtime as needed
directory=$pool_name
EOF

    # Add offsets to each job to avoid prefetching
    for (( i=0; i<4; i++ )); do
        echo "[$i]" >> $fio_job_file
        echo "offset=$((i * 256))k" >> $fio_job_file
    done

    echo "Running fio command for VM volumes: fio $fio_job_file"
    fio $fio_job_file > fio_vm_volumes_$pool_name.log

    cd ..
    echo "VM volumes benchmarking with fio complete. Results saved in $result_dir/fio_vm_volumes_$pool_name.log"
}

# Function to benchmark random read/write for VM volumes with iozone
benchmark_vm_volumes_iozone() {
    local pool_name=$1
    local result_dir="iozone_results"

    echo "Benchmarking VM volumes on ZFS pool $pool_name with iozone..."
    mkdir -p $result_dir
    cd $result_dir || exit

    iozone -i 0 -i 1 -i 2 -i 8 -i 9 -s 10G -r 4k -r 64k -r 1024k -t 4 -F $pool_name/testfile > iozone_vm_volumes_$pool_name.log

    cd ..
    echo "VM volumes benchmarking with iozone complete. Results saved in $result_dir/iozone_vm_volumes_$pool_name.log"
}

# Function to benchmark data workloads with fio
benchmark_data_fio() {
    local pool_name=$1
    local result_dir="fio_results"
    local fio_job_file="fio_data.ini"

    echo "Benchmarking data workloads on ZFS pool $pool_name with fio..."
    mkdir -p $result_dir
    cd $result_dir || exit

    # Create a fio job file for data workloads
    cat << EOF > $fio_job_file
[global]
rw=rw
direct=1
ioengine=libaio
bs=1M
size=50G  # Adjust size according to your typical data file size
numjobs=4
runtime=300  # Adjust runtime as needed
directory=$pool_name
EOF

    # Add offsets to each job to avoid prefetching
    for (( i=0; i<4; i++ )); do
        echo "[$i]" >> $fio_job_file
        echo "offset=$((i * 1024))k" >> $fio_job_file
    done

    echo "Running fio command for data workloads: fio $fio_job_file"
    fio $fio_job_file > fio_data_$pool_name.log

    cd ..
    echo "Data workloads benchmarking with fio complete. Results saved in $result_dir/fio_data_$pool_name.log"
}

# Function to benchmark data workloads with iozone
benchmark_data_iozone() {
    local pool_name=$1
    local result_dir="iozone_results"

    echo "Benchmarking data workloads on ZFS pool $pool_name with iozone..."
    mkdir -p $result_dir
    cd $result_dir || exit

    iozone -i 0 -i 1 -i 2 -i 8 -i 9 -s 50G -r 4k -r 64k -r 1024k -t 4 -F $pool_name/testfile > iozone_data_$pool_name.log

    cd ..
    echo "Data workloads benchmarking with iozone complete. Results saved in $result_dir/iozone_data_$pool_name.log"
}

# Function to benchmark database workloads with fio
benchmark_database_fio() {
    local pool_name=$1
    local result_dir="fio_results"
    local fio_job_file="fio_database.ini"

    echo "Benchmarking database workloads on ZFS pool $pool_name with fio..."
    mkdir -p $result_dir
    cd $result_dir || exit

    # Create a fio job file for database workloads
    cat << EOF > $fio_job_file
[global]
rw=randrw
direct=1
ioengine=libaio
bs=8k  # Adjust block size based on database requirements
size=100G  # Adjust size according to database working set size
numjobs=16  # Increase numjobs for database concurrency
runtime=600  # Adjust runtime as needed
directory=$pool_name
EOF

    # Add offsets to each job to avoid prefetching
    for (( i=0; i<16; i++ )); do
        echo "[$i]" >> $fio_job_file
        echo "offset=$((i * 64))k" >> $fio_job_file
    done

    echo "Running fio command for database workloads: fio $fio_job_file"
    fio $fio_job_file > fio_database_$pool_name.log

    cd ..
    echo "Database workloads benchmarking with fio complete. Results saved in $result_dir/fio_database_$pool_name.log"
}

# Function to benchmark database workloads with iozone
benchmark_database_iozone() {
    local pool_name=$1
    local result_dir="iozone_results"

    echo "Benchmarking database workloads on ZFS pool $pool_name with iozone..."
    mkdir -p $result_dir
    cd $result_dir || exit

    iozone -i 0 -i 1 -i 2 -i 8 -i 9 -s 100G -r 4k -r 64k -r 1024k -t 16 -F $pool_name/testfile > iozone_database_$pool_name.log

    cd ..
    echo "Database workloads benchmarking with iozone complete. Results saved in $result_dir/iozone_database_$pool_name.log"
}

# Function to output synthetic benchmark results
output_benchmark_results() {
    local result_dir=$1
    echo "==========================="
    echo "Fio Benchmark Results:"
    echo "==========================="
    grep -A 20 "fio.*WRITE" $result_dir/fio_random_rw_$selected_pool.log
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

# Trap Ctrl+C and perform cleanup
trap cleanup SIGINT

# Main script logic
select_zfs_pool

# Disable ZFS caching before benchmarking
disable_zfs_cache

# Perform generic benchmarks
benchmark_generic_fio $selected_pool
benchmark_generic_iozone $selected_pool

# Perform benchmarks for VM volumes
benchmark_vm_volumes_fio $selected_pool
benchmark_vm_volumes_iozone $selected_pool

# Perform benchmarks for data workloads
benchmark_data_fio $selected_pool
benchmark_data_iozone $selected_pool

# Perform benchmarks for database workloads
benchmark_database_fio $selected_pool
benchmark_database_iozone $selected_pool

# Output benchmark results
output_benchmark_results "fio_results"
output_benchmark_results "iozone_results"

# Enable ZFS caching back
enable_zfs_cache

echo "Benchmarking for ZFS pool $selected_pool completed."
