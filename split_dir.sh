#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 --parent-dir <parent_dir> --files-per-dir <files_per_dir> --process-num <process_num>"
    exit 1
}

# Function to split files into subdirectories
split_files_into_subdirs() {
    local child_dir=$1
    local files_per_dir=$2

    # Check if the child dir exists
    if [ ! -d "$child_dir" ]; then
        echo "Child dir '$child_dir' does not exist."
        return
    fi

    # Get a list of all .jpg and .png files in the child dir
    files=($(ls "$child_dir" | grep -E "\.jpg$|\.png$" | sort))

    local dir_index=1
    local file_count=0

    for file in "${files[@]}"; do
        # Determine the current subdir with zero-padded dir index
        current_subdir=$(printf "%s/%03d" "$child_dir" "$dir_index")
        mkdir -p "$current_subdir"

        # Move the file to the current subdir
        mv "$child_dir/$file" "$current_subdir/"

        file_count=$((file_count + 1))
        if [ "$file_count" -ge "$files_per_dir" ]; then
            dir_index=$((dir_index + 1))
            file_count=0
        fi
    done
}

# Function to process the parent directory
process_parent_dir() {
    local parent_dir=$1
    local files_per_dir=$2
    local process_num=$3

    # Check if the parent dir exists
    if [ ! -d "$parent_dir" ]; then
        echo "Parent dir '$parent_dir' does not exist."
        return
    fi

    # Initialize commands for each process
    declare -A process_commands
    for ((i = 0; i < process_num; i++)); do
        process_commands[$i]=""
    done

    # Iterate through each child dir in the parent dir
    local child_dir_index=0
    for child_dir_name in "$parent_dir"/*; do
        if [ -d "$child_dir_name" ]; then
            local process_index=$((child_dir_index % process_num))
            process_commands[$process_index]+="split_files_into_subdirs \"$child_dir_name\" \"$files_per_dir\";"
            child_dir_index=$((child_dir_index + 1))
        fi
    done

    # Execute the commands in parallel
    for ((i = 0; i < process_num; i++)); do
        if [ -n "${process_commands[$i]}" ]; then
            eval "(${process_commands[$i]}) &"
            sleep 1
        fi
    done

    # Wait for all background processes to exit
    wait
}

# Main script execution
main() {
    echo "Starting Splitting Directories..."

    # Parse arguments using getopt
    PARAMS=$(getopt -o '' --long parent-dir:,files-per-dir:,process-num: -- "$@")
    if [ $? -ne 0 ]; then
        usage
    fi

    eval set -- "$PARAMS"

    while true; do
        case "$1" in
            --parent-dir)
                parent_dir="$2"
                shift 2
                ;;
            --files-per-dir)
                files_per_dir="$2"
                shift 2
                ;;
            --process-num)
                process_num="$2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                usage
                ;;
        esac
    done

    if [ -z "$parent_dir" ] || [ -z "$files_per_dir" ] || [ -z "$process_num" ]; then
        usage
    fi

    process_parent_dir "$parent_dir" "$files_per_dir" "$process_num"
}

main "$@"
