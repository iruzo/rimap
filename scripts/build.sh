#!/bin/sh

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

sh "$SCRIPT_DIR/del.sh"
$CONTAINER_TOOL build -t rimap -f "$CARGO_DIR/docker/nix_glibc.Dockerfile" "$CARGO_DIR"
