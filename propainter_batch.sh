#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -v <VIDEO_DIR> -m <MASK_DIR> -o <OUTPUT_DIR> -p <GPU_PROCESS_NUM>"
    exit 1
}

# Parse command line options using getopts
while getopts ":v:m:o:p:" opt; do
    case $opt in
        v) VIDEO_DIR="$OPTARG" ;;
        m) MASK_DIR="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        p) GPU_PROCESS_NUM="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check if all required options are provided
if [ -z "$VIDEO_DIR" ] || [ -z "$MASK_DIR" ] || [ -z "$OUTPUT_DIR" ] || [ -z "$GPU_PROCESS_NUM" ]; then
    usage
fi

# Ensure GPU_PROCESS_NUM is a number and greater than 0
if ! [[ "$GPU_PROCESS_NUM" =~ ^[0-9]+$ ]] || [ "$GPU_PROCESS_NUM" -le 0 ]; then
    echo "Error: The number of commands per GPU must be a positive number."
    exit 1
fi

echo "ProPainter Processing..."

run_inference() {
    # Record the start time
    local start_time=$(date +%s)

    # Get the number of available GPUs
    local NUM_GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

    # Initialize commands for each GPU
    declare -A gpu_commands
    for ((i = 0; i < NUM_GPUS; i++)); do
        gpu_commands[$i]=""
    done

    # Iterate over each video directory (video1, video2, etc.)
    local subdir_index=0
    for video_subdir in "$VIDEO_DIR"/*; do
        [ -d "$video_subdir" ] || continue
        local video_name=$(basename "$video_subdir")

        # Get the sorted list of numeric subdirectories within each video directory
        local sub_dirs=$(find "$video_subdir" -maxdepth 1 -mindepth 1 -type d | grep -E '/[0-9]+$' | sort)

        # Process each subdirectory
        for sub_dir in $sub_dirs; do
            local sub_dir_name=$(basename "$sub_dir")
            local mask_sub_dir="$MASK_DIR/$video_name/$sub_dir_name"

            if [ -d "$mask_sub_dir" ]; then
                local gpu_index=$((subdir_index % NUM_GPUS))
                gpu_commands[$gpu_index]+="mkdir -p \"$OUTPUT_DIR/$video_name\"; CUDA_VISIBLE_DEVICES=$gpu_index python inference_propainter.py --video \"$sub_dir\" --mask \"$mask_sub_dir\" --output \"$OUTPUT_DIR/$video_name\" --subvideo_length 100 --save_fps 30;&"
                subdir_index=$((subdir_index + 1))
            else
                echo "Mask directory $mask_sub_dir does not exist."
            fi
        done
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

    # Wait for all background processes to complete
    wait
}

# Call the function with the provided directories
run_inference
