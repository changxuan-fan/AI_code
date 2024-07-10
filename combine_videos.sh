#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -i <input_directory> -o <output_directory> -t <temp_file> -p <GPU_process_num>"
    exit 1
}

# Parse command line options using getopts
while getopts ":i:o:t:p:" opt; do
    case $opt in
        i) INPUT_DIR="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        t) TEMP_FILE="$OPTARG" ;;
        p) GPU_PROCESS_NUM="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check if all required options are provided
if [ -z "$INPUT_DIR" ] || [ -z "$OUTPUT_DIR" ] || [ -z "$TEMP_FILE" ] || [ -z "$GPU_PROCESS_NUM" ]; then
    usage
fi

# Ensure GPU_PROCESS_NUM is a number and greater than 0
if ! [[ "$GPU_PROCESS_NUM" =~ ^[0-9]+$ ]] || [ "$GPU_PROCESS_NUM" -le 0 ]; then
    echo "Error: The number of commands per GPU must be a positive number."
    exit 1
fi

# Ensure output directory exists and is empty
if [ -d "$OUTPUT_DIR" ]; then
    find "$OUTPUT_DIR" -mindepth 1 -print -delete  # Log what gets deleted
    echo "Cleared all contents of $OUTPUT_DIR"
else
    mkdir -p "$OUTPUT_DIR"  # Create the directory if it doesn't exist
    echo "Created directory $OUTPUT_DIR"
fi

echo "Combining Videos..."

run_processing() {
    local NUM_GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

    # Initialize commands for each GPU
    declare -A gpu_commands
    for ((i = 0; i < NUM_GPUS; i++)); do
        gpu_commands[$i]=""
    done

    # Loop through each subdirectory in the parent directory
    local subdir_index=0
    for SUBDIR in "$INPUT_DIR"/*; do
        if [ -d "$SUBDIR" ]; then
            > "$TEMP_FILE"  # Clear the temporary file list
            # List all video files in the subdirectory
            for VIDEO_FILE in "$SUBDIR"/*; do
                echo "file '$VIDEO_FILE'" >> "$TEMP_FILE"
            done
            local SUBDIR_NAME=$(basename "$SUBDIR")
            local gpu_index=$((subdir_index % NUM_GPUS))
            gpu_commands[$gpu_index]+="CUDA_VISIBLE_DEVICES=$gpu_index ffmpeg -y -vsync 0 -hwaccel nvdec -f concat -safe 0 -i \"$TEMP_FILE\" -hide_banner -loglevel error -stats \"$OUTPUT_DIR/$SUBDIR_NAME.mp4\";&"
            subdir_index=$((subdir_index + 1))
        fi
    done

    # Group the commands for each GPU
    declare -A group_gpu_commands
    for ((i = 0; i < NUM_GPUS; i++)); do
        IFS='&' read -ra commands_array <<< "${gpu_commands[$i]}"
        local total_commands=$(echo "${gpu_commands[$i]}" | tr -cd '&' | wc -c)
        local num_commands_per_group=$(( (total_commands + GPU_PROCESS_NUM - 1) / GPU_PROCESS_NUM ))
        group_gpu_commands[$i]=""
        for ((j = 0; j < ${#commands_array[@]}; j += num_commands_per_group)); do
            group_gpu_commands[$i]+="${commands_array[@]:j:num_commands_per_group} & "
        done
    done

    # Execute the grouped commands in the desired order
    for ((i = 0; i < GPU_PROCESS_NUM; i++)); do
        for ((j = 0; j < NUM_GPUS; j++)); do
            if [ -n "${group_gpu_commands[$j]}" ]; then
                IFS='&' read -ra commands <<< "${group_gpu_commands[$j]}"
                if [ -n "${commands[$i]}" ]; then
                    eval "(${commands[$i]}) &"
                    sleep 1
                fi
            fi
        done
    done

    # Wait for all background processes to exit
    wait
}

run_processing

# Remove the temporary file list
rm "$TEMP_FILE"
echo "All videos have been combined and stored in $OUTPUT_DIR."
