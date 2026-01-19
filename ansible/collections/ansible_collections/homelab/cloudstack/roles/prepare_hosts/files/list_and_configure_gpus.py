#!/usr/bin/env python3

import subprocess
import re


def execute_local_command(command):
    """Execute a local shell command and return its output."""
    try:
        result = subprocess.run(command, shell=True, text=True, capture_output=True)
        result.check_returncode()
        return result.stdout
    except subprocess.CalledProcessError:
        return ""


def list_all_gpus():
    """List all NVIDIA GPU IDs on the local system using lspci.

    Uses the lspci command to identify NVIDIA GPUs and extracts their
    PCI vendor:device IDs in the format 'XXXX:XXXX'.

    Returns:
        list[str]: List of GPU IDs in the format ['XXXX:XXXX', ...]
    """
    command = "lspci -nn | grep -Ei 'vga compatible controller.*nvidia'"
    lspci_output = execute_local_command(command)
    ids = []

    # Regular expression to extract the ID in format XXXX:XXXX
    id_pattern = re.compile(r"\[(\w{4}:\w{4})\]")

    for line in lspci_output.splitlines():
        match = id_pattern.search(line)
        if match:
            ids.append(match.group(1))

    return ids


def write_vfio_conf(gpu_ids):
    """Write GPU IDs to the VFIO configuration file.

    Updates /etc/modprobe.d/vfio.conf with the provided GPU IDs for VFIO-PCI
    passthrough configuration. If no IDs are provided, writes an empty ID list.

    Args:
        gpu_ids (list[str]): List of GPU IDs to write to the config file
    """
    vfio_conf_path = "/etc/modprobe.d/vfio.conf"

    if gpu_ids:
        ids_line = "options vfio-pci ids=" + ",".join(gpu_ids)
    else:
        ids_line = "options vfio-pci ids="

    with open(vfio_conf_path, "w") as file:
        file.write(ids_line + "\n")

    print(f"Updated {vfio_conf_path} with GPU IDs.")


def main():
    """Main function to identify GPUs and configure VFIO passthrough.

    Lists all NVIDIA GPUs on the system and updates the VFIO configuration
    file with their IDs for PCI passthrough setup.
    """
    gpu_ids = list_all_gpus()

    if gpu_ids:
        # Write GPU IDs to vfio.conf
        write_vfio_conf(gpu_ids)
    else:
        print("===> No NVIDIA GPUs detected.")


if __name__ == "__main__":
    main()
