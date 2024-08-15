#!/bin/sh

# Script to run rimap container with a specified configuration file

# Ensure exactly one argument (config file) is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <config_file>"
    exit 1
fi

CONFIG_FILE="$1"

# Extract the local_dir value from the config file
MAILS_DIRECTORY=$(awk -F'=' '/local_dir/ {printf $NF}' "$CONFIG_FILE")
# Create the directory if it doesn't exist
mkdir -p "$MAILS_DIRECTORY" 2> /dev/null

# Modify the `local_dir` line in the config file and save to a temporary file
sed 's|^local_dir=.*|local_dir=/mails|' "$CONFIG_FILE" > "./.rimap_tmp_config_file"
CONFIG_FILE="./.rimap_tmp_config_file"

# Find an available container tool (docker or podman)
find_container_tool() {
    if command -v docker > /dev/null 2>&1; then
        echo "sudo docker"
    elif command -v podman > /dev/null 2>&1; then
        echo "podman"
    else
        echo "Error: Neither docker nor podman is available." >&2
        exit 1
    fi
}

# Determine which container tool to use
CONTAINER_TOOL=$(find_container_tool)

# Check SELinux status and set appropriate mount option
check_selinux() {
    if command -v getenforce > /dev/null 2>&1; then
        SELINUX_STATUS=$(getenforce)
        if [ "$SELINUX_STATUS" = "Enforcing" ] || [ "$SELINUX_STATUS" = "Permissive" ]; then
            echo ":z"
        else
            echo ""
        fi
    elif [ -f /sys/fs/selinux/enforce ]; then
        if [ "$(cat /sys/fs/selinux/enforce)" = "1" ]; then
            echo ":z"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

# Get the SELinux option for volume mounts if SELinux is enforcing or permissive
SELINUX=$(check_selinux)

# Run the container with the specified configuration and directory volumes
$CONTAINER_TOOL run -v "$CONFIG_FILE:/config$SELINUX" -v "$MAILS_DIRECTORY:/mails$SELINUX" rimap

# Clean up by removing the temporary config file
rm "$CONFIG_FILE"
