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

# Delete repository dir
rm -rf rimap

# Clone repository
git clone https://github.com/iruzo/rimap

# Copy config inside repository
cp config rimap/

# Execute script
sh rimap/scripts/build_compose.sh "$CONFIG_FILE_PATH" "$MAILS_DIR_PATH"

# Delete repository dir
rm -rf rimap
