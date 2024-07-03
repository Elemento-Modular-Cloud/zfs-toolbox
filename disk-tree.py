#!python3

import subprocess
import re

def parse_lshw():
    # Run lshw command and capture its output
    cmd = ["sudo", "lshw", "-class", "disk", "-class", "storage"]
    try:
        output = subprocess.check_output(cmd, universal_newlines=True)
    except subprocess.CalledProcessError as e:
        print(f"Error running lshw command: {e}")
        return None

    return output

def extract_info(output):
    controllers = {}
    current_controller = None
    disk_pattern = re.compile(r'\s+disk(\d+):\s+(.*)\s*$')

    lines = output.splitlines()
    for line in lines:
        line = line.strip()
        if line.startswith('*-'):
            # Found a new controller
            current_controller = line[2:].strip()
            controllers[current_controller] = {}
        elif current_controller and line.startswith('disk'):
            # Found a disk under the current controller
            match = disk_pattern.match(line)
            if match:
                disk_number = match.group(1)
                disk_info = match.group(2).strip()
                controllers[current_controller][f"disk{disk_number}"] = disk_info

    return controllers

def format_tree(controllers):
    tree = ""

    for controller, disks in controllers.items():
        tree += f"├── {controller}\n"
        for disk, info in disks.items():
            tree += f"│   └── {disk}: {info}\n"
        tree += "\n"

    return tree

def main():
    lshw_output = parse_lshw()
    if lshw_output:
        controllers = extract_info(lshw_output)
        formatted_tree = format_tree(controllers)
        print(formatted_tree)
    else:
        print("Failed to get lshw output.")

if __name__ == "__main__":
    main()
