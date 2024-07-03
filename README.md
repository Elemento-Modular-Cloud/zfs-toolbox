# ZFS Pool Creation and Benchmarking Scripts

This repository contains two scripts to simplify the process of creating ZFS pools and benchmarking their performance. The first script focuses on creating ZFS pools using preset configurations optimized for SSDs or HDDs. The second script benchmarks ZFS pools using `fio` and `iozone` to assess performance across various workloads.

## Background

ZFS is a powerful file system and logical volume manager designed to provide high storage capacity, data integrity, and various performance features. Configuring and benchmarking ZFS optimally can be complex, especially when dealing with different types of storage devices like SSDs and HDDs. These scripts automate the setup and performance evaluation processes, ensuring optimal settings and comprehensive benchmarks for different use cases.

## Features

### ZFS Pool Creation Script

- **Automatic Disk Type Detection**: Detects whether the disks are SSDs or HDDs and applies appropriate settings.
- **Preset Configurations**: Uses JSON files to define presets optimized for various use cases.
- **Dry Run Mode**: Allows you to see the commands that would be executed without making any changes.
- **Interactive User Prompts**: Asks for user input when disk types are mixed or unclear.
- **Customizable Mount Points**: Allows specifying a custom mount point for the ZFS pool.

### ZFS Benchmarking Script

- **Interactive ZFS Pool Selection**: Prompts the user to select a ZFS pool from a list of available pools.
- **Automatic Caching Control**: Disables and re-enables ZFS caching before and after benchmarks to test actual performance.
- **Comprehensive Workload Benchmarks**: Performs benchmarks for generic workloads (random read/write, sequential read/write, latency) as well as specific workloads (VM volumes, data, databases) using `fio` and `iozone`.
- **Synthetic Benchmark Results**: Outputs synthetic benchmark results in the terminal by grepping relevant data from the results.
- **Prefetch Avoidance**: Adds offsets to multiple workers to avoid prefetching during benchmarks.

## Requirements

- `jq`: A command-line JSON processor.
- `bc`: An arbitrary precision calculator language.
- `lsblk`: Utility to list information about block devices.
- `sudo`: To ensure the script can run ZFS commands with necessary permissions.
- `fio`: Flexible I/O tester for benchmarking and stress testing.
- `iozone`: Filesystem benchmark tool.

## Installation

1. Clone the repository or download the scripts.
2. Ensure the scripts are executable:

   ```bash
   chmod +x zfs-create.sh zfs-benchmark.sh
   ```

3. Install required dependencies:

    ```bash
    sudo apt-get install jq bc fio iozone3
    ```

## Usage

### ZFS Pool Creation Script
```bash
Usage: zfs-create-pool.sh [OPTIONS] [DISKS...]

Options:
  --dry-run        Perform a dry run (echo commands instead of executing them)
  -p, --preset     Name of the preset configuration (without .json)
  -n, --pool       Name of the ZFS pool to be created
  -m, --mountpoint Optional: Mount point for the ZFS pool (default: /mnt/zpool)
  --hdd            Assume all disks are HDDs
  --ssd            Assume all disks are SSDs
  DISKS            List of disks in ZFS vdev format (e.g., /dev/disk/by-id/...)

Examples:
  zfs-create-pool.sh --ssd --preset vm --pool myzpool --mountpoint /mnt/zpool
```

### ZFS Benchmarking Script
Run the script.

```bash
./zfs-benchmark.sh
```

Follow the prompts to select the ZFS pool you want to benchmark.

The script will disable ZFS caching, perform generic benchmarks (random read/write, sequential read/write, latency), specific benchmarks for VM volumes, data workloads, and database workloads using both fio and iozone, and then re-enable ZFS caching.

Finally, it will output synthetic benchmark results for each benchmark type.

By using these scripts, you can automate the creation and benchmarking of ZFS pools, ensuring optimal configuration and comprehensive performance evaluation for different storage scenarios.