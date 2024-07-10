#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 --input-dir <INPUT_DIR> --output-dir <OUTPUT_DIR> --process-num <process_num>"
    exit 1
}

# Parse command line options using getopts
while getopts ":--input-dir:--output-dir:--process-num:" opt; do
    case $opt in
        --input-dir) INPUT_DIR="$OPTARG" ;;
        --output-dir) OUTPUT_DIR="$OPTARG" ;;
        --process-num) process_num="$OPTARG" ;;
        *) echo "Unknown parameter passed: $opt"; usage ;;
    esac
done

# Check if all required options are provided
if [ -z "$INPUT_DIR" ] || [ -z "$OUTPUT_DIR" ] || [ -z "$process_num" ]; then
    usage
fi

move_and_rename_files() {
    local video_dir="$1"
    local OUTPUT_DIR="$2"

    video_dir_name=$(basename "$video_dir")
    target_video_dir="$OUTPUT_DIR/$video_dir_name"
    mkdir -p "$target_video_dir"

    # Loop through each subdirectory within the video directory
    for sub_dir in "$video_dir"/*; do
        if [ -d "$sub_dir" ]; then
            sub_dir_name=$(basename "$sub_dir")

            # Define the path to the inpaint_out.mp4 file
            inpaint_out_file="$sub_dir/inpaint_out.mp4"

            # Check if the inpaint_out.mp4 file exists and move it
            if [ -f "$inpaint_out_file" ]; then
                new_name="${sub_dir_name}.mp4"
                target_file_path="$target_video_dir/$new_name"
                mv "$inpaint_out_file" "$target_file_path"
            else
                echo "File $inpaint_out_file does not exist in $sub_dir"
            fi
        fi
    done
}

process_input_dir() {
    local INPUT_DIR="$1"
    local OUTPUT_DIR="$2"
    local process_num="$3"

    # Create the parent output directory if it doesn't exist
    mkdir -p "$OUTPUT_DIR"

    # Initialize commands for each process
    declare -A process_commands
    for ((i = 0; i < process_num; i++)); do
        process_commands[$i]=""
    done

    # Loop through each video directory in the input directory
    local video_dir_index=0
    for video_dir in "$INPUT_DIR"/*; do
        if [ -d "$video_dir" ]; then
            local process_index=$((video_dir_index % process_num))
            process_commands[$process_index]+="move_and_rename_files \"$video_dir\" \"$OUTPUT_DIR\";"
            video_dir_index=$((video_dir_index + 1))
        fi
    done

    # Execute the commands in parallel
    for ((i = 0; i < process_num; i++)); do
        if [ -n "${process_commands[$i]}" ]; then
            eval "$({process_commands[$i]}) &"
            sleep 1
        fi
    done

    # Wait for all background processes to exit
    wait
}

# Main script execution
main() {
    echo "Starting Extracting videos..."
    process_input_dir "$INPUT_DIR" "$OUTPUT_DIR" "$process_num"
}

main "$@"
