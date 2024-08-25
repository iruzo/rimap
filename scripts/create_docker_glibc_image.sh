#!/bin/sh

# Script to build rimap image using a Dockerfile found relative to a Cargo.toml file

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

# Find the directory containing Cargo.toml by traversing up the directory tree
find_cargo_toml() {
    DIR=$(pwd)
    while [ "$DIR" != "/" ]; do
        if [ -f "$DIR/Cargo.toml" ]; then
            echo "$DIR"
            return
        fi
        DIR=$(dirname "$DIR")
    done
    echo "Error: Cargo.toml not found in the directory hierarchy." >&2
    exit 1
}

# Locate the directory containing Cargo.toml
CARGO_DIR=$(find_cargo_toml)

# Set the Dockerfile path relative to the Cargo.toml directory
DOCKERFILE_PATH="$CARGO_DIR/docker/nix_glibc.Dockerfile"

# Build the container image using the determined Dockerfile
$CONTAINER_TOOL build -f "$DOCKERFILE_PATH" -t rimap .
