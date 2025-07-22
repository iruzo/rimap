#!/bin/sh

if [ "$#" -lt 2 ]; then
    printf "Usage: %s <config_file_path> <mails_dir_path>\n" "$0"
    show_help
    exit 1
fi


get_absolute_path() {
    # Check if the argument is provided
    if [ -z "$1" ]; then
        echo "No path provided."
        return 1
    fi

    # Store the input path
    INPUT_PATH="$1"

    # Check if the path is absolute
    case "$INPUT_PATH" in
        /*)
            echo "$INPUT_PATH"  # Return absolute path
            ;;
        *)
            # Convert relative path to absolute
            ABSOLUTE_PATH=$(cd "$(dirname "$INPUT_PATH")"; pwd)/$(basename "$INPUT_PATH")
            echo "$ABSOLUTE_PATH"  # Return the converted absolute path
            ;;
    esac
}

CONFIG_FILE_PATH=$(get_absolute_path "$1")
MAILS_DIR_PATH=$(get_absolute_path "$2")

echo $CONFIG_FILE_PATH
echo $MAILS_DIR_PATH

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

CONTAINER_TOOL=$(find_container_tool)

# build image
$CONTAINER_TOOL build -t rimap:latest https://github.com/iruzo/rimap.git#main

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
$CONTAINER_TOOL run --rm -v "$CONFIG_FILE_PATH:/config$SELINUX" -v "$MAILS_DIR_PATH:/mails$SELINUX" rimap
