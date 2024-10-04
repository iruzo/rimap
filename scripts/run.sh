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

# Create the directory if it doesn't exist
mkdir -p "$MAILS_DIR_PATH" 2> /dev/null

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

# Determine script's dir
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Find the directory containing the cargo.toml by traversing up the directory tree
find_cargo() {
    DIR="$SCRIPT_DIR"
    while [ "$DIR" != "/" ]; do
        if ls "$DIR"/Cargo.toml 1> /dev/null 2>&1; then
            echo "$DIR"
            return
        fi
        DIR=$(dirname "$DIR")
    done
    echo "Error: Solution not found in the directory hierarchy." >&2
    exit 1
}

# Locate the directory containing Cargo.toml
CARGO_DIR=$(find_cargo)

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
