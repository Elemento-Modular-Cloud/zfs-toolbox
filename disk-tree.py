import subprocess

def parse_lshw():
    # Run lshw command and capture its output
    cmd = ["sudo", "lshw", "-class", "disk", "-class", "storage"]
    try:
        output = subprocess.check_output(cmd, universal_newlines=True)
    except subprocess.CalledProcessError as e:
        print(f"Error running lshw command: {e}")
        return None

    return output

def parse_output(output):
    sections = []
    current_section = {}
    current_controller_id = None
    type = None

    lines = output.strip().split('\n')
    for line in lines:
        line = line.strip().rstrip()
        if line.startswith('*-'):
            # New section detected
            if current_section:
                sections.append(current_section)
                current_section = {}
            type = line.strip().replace('*-', '')
            current_section = {'type': type.replace("sata", "controller").split(':',1)[0]}
            if type.startswith("disk"):
                current_section["controller id"] = current_controller_id.strip().rstrip()
        else:
            # Parse key-value pairs
            if line.strip() != '':
                key, value = line.split(':', 1)
                if key == "bus info" and type.startswith("sata"):
                    current_controller_id = value
                current_section[key.strip()] = value.strip()

    # Append the last section
    if current_section:
        sections.append(current_section)

    return sections


def group_by_controller_and_disks(parsed_data):
    grouped_data = {}

    for section in parsed_data:
        if section['type'] == 'controller':
            controller_info = {
                'product': section.get('product', ''),
                'vendor': section.get('vendor', ''),
                'bus_info': section.get('bus info', '')
            }
            # Use physical id as key for each controller
            grouped_data[section['bus info']] = {
                'controller_info': controller_info,
                'disks': []
            }
    for section in parsed_data:
        if section['type'] == 'disk':
            disk_info = {
                'description': section.get('description', ''),
                'product': section.get('product', ''),
                'vendor': section.get('vendor', ''),
                'serial': section.get('serial', ''),
                'logical_name': section.get('logical name', ''),
                'size': section.get('size', '')
            }
            controller_id = section.get('controller id', '')
            grouped_data[controller_id]['disks'].append(disk_info)

    return grouped_data


def main():
    # # Example output given
    # output_short = """
    # *-sata
    #     description: SATA controller
    #     product: ASM1064 Serial ATA Controller
    #     vendor: ASMedia Technology Inc.
    #     physical id: 0
    #     bus info: pci@0000:03:00.0
    #     logical name: scsi81
    #     logical name: scsi83
    #     version: 02
    #     width: 32 bits
    #     clock: 33MHz
    #     capabilities: sata pm msi pciexpress ahci_1.0 bus_master cap_list rom emulated
    #     configuration: driver=ahci latency=0
    #     resources: irq:236 memory:f2882000-f2883fff memory:f2880000-f2881fff memory:f2800000-f287ffff
    #     *-disk:0
    #         description: ATA Disk
    #         product: WDC  WUH722020AL
    #         vendor: Western Digital
    #         physical id: 0
    #         bus info: scsi@81:0.0.0
    #         logical name: /dev/sdf
    #         version: W108
    #         serial: 2LGLYJNF
    #         size: 18TiB (20TB)
    #         capabilities: gpt-1.00 partitioned partitioned:gpt
    #         configuration: ansiversion=5 guid=8f5f3da4-8138-f64a-8e25-d1c1f795107f logicalsectorsize=512 sectorsize=4096
    #     *-disk:1
    #         description: ATA Disk
    #         product: WDC  WUH722020BL
    #         vendor: Western Digital
    #         physical id: 1
    #         bus info: scsi@83:0.0.0
    #         logical name: /dev/sdg
    #         version: W540
    #         serial: 9AG9WZHS
    #         size: 18TiB (20TB)
    #         capabilities: gpt-1.00 partitioned partitioned:gpt
    #         configuration: ansiversion=5 guid=8fe782f6-ea11-8648-bdff-b5450994906e logicalsectorsize=512 sectorsize=4096
    # """

    # # Open the file and read its contents
    # with open('lshw_sample.txt', 'r') as f:
    #     output_long = f.read()

    parsed_data = parse_output(parse_lshw())

    grouped_data = group_by_controller_and_disks(parsed_data)

    # Output formatted as requested
    for controller_id, data in grouped_data.items():
        controller_info = data['controller_info']
        disks = data['disks']
        print(f"{controller_info['product']} {controller_info['vendor']} @{controller_info['bus_info']}")
        for idx, disk in enumerate(disks):
            disk_name = f"disk{idx}: ATA Disk {disk['product']} {disk['serial']} with device {disk['logical_name']} and size {disk['size']}"
            print(f"    {disk_name}")


if __name__ == "__main__":
    main()
