#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -v <video_dir> -m <mask_dir> -o <output_dir>"
    exit 1
}

# Parse command line options using getopts
while getopts ":v:m:o:" opt; do
    case $opt in
        v) video_dir="$OPTARG" ;;
        m) mask_dir="$OPTARG" ;;
        o) output_dir="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check if all required options are provided
if [ -z "$video_dir" ] || [ -z "$mask_dir" ] || [ -z "$output_dir" ]; then
    usage
fi

run_inference() {
    local VIDEO_DIR="$1"
    local MASK_DIR="$2"
    local OUTPUT_DIR="$3"

    # Record the start time
    local start_time=$(date +%s)

    # Get the number of available GPUs
    local NUM_GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

    # Array to store commands for each GPU
    declare -a gpu_commands

    # Initialize commands for each GPU
    for ((i = 0; i < NUM_GPUS; i++)); do
        gpu_commands[$i]=""
    done

    # Iterate over each video directory (video1, video2, etc.)
    for video_dir in "$VIDEO_DIR"/*; do
        [ -d "$video_dir" ] || continue
        video_name=$(basename "$video_dir")

        # Get the sorted list of numeric subdirectories within each video directory
        local sub_dirs=$(find "$video_dir" -maxdepth 1 -mindepth 1 -type d | grep -E '/[0-9]+$' | sort)

        # Process each subdirectory
        for sub_dir in $sub_dirs; do
            local sub_dir_name=$(basename "$sub_dir")
            local mask_sub_dir="$MASK_DIR/$video_name/$sub_dir_name"

            if [ -d "$mask_sub_dir" ]; then
                gpu_index=$((sub_dir_name % NUM_GPUS))
                gpu_commands[$gpu_index]+="mkdir -p \"$OUTPUT_DIR/$video_name\"; CUDA_VISIBLE_DEVICES=$gpu_index python inference_propainter.py --video \"$sub_dir\" --mask \"$mask_sub_dir\" --output \"$OUTPUT_DIR/$video_name\" --subvideo_length 100 --save_fps 30; "
            else
                echo "Mask directory $mask_sub_dir does not exist."
            fi
        done
    done

    # Execute the commands for each GPU in parallel
    for ((i = 0; i < NUM_GPUS; i++)); do
        if [ -n "${gpu_commands[$i]}" ]; then
            eval "(${gpu_commands[$i]}) &"
            sleep 1
        fi
    done

    # Wait for all background processes to complete
    wait

    # Display the total execution time in a human-readable format
    local end_time=$(date +%s)
    local execution_time=$((end_time - start_time))
    local hours=$((execution_time / 3600))
    local minutes=$(( (execution_time % 3600) / 60 ))
    local seconds=$((execution_time % 60))
    echo "Total execution time: ${hours}h ${minutes}m ${seconds}s"
}

# Call the function with the provided directories
run_inference "$video_dir" "$mask_dir" "$output_dir"
