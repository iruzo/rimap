#!/bin/sh

# Extract the local_dir value from the config file
MAILS_DIRECTORY="./mails"
# Create the directory if it doesn't exist
mkdir -p "$MAILS_DIRECTORY" 2> /dev/null

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

# Find the directory containing the cargo.toml by traversing up the directory tree
find_cargo() {
    DIR=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
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

# Run the container with the specified configuration and directory volumes
sh "$CARGO_DIR/scripts/stop_compose.sh"
$CONTAINER_TOOL container prune -f
$CONTAINER_TOOL image prune -f
$CONTAINER_TOOL volume prune -f
$CONTAINER_TOOL compose -p rimap -f "$CARGO_DIR/docker-compose.yml" up --build
sh "$CARGO_DIR/scripts/stop_compose.sh"
$CONTAINER_TOOL image rm rimap:latest
