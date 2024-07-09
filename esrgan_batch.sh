#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -i <input_dir> -o <output_dir>"
    exit 1
}

# Parse command line options using getopts
while getopts ":i:o:" opt; do
    case $opt in
        i) input_dir="$OPTARG" ;;
        o) output_dir="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check if all required options are provided
if [ -z "$input_dir" ] || [ -z "$output_dir" ]; then
    usage
fi

run_processing() {
    local input_dir="$1"
    local output_dir="$2"

    # Create the output folder if it doesn't exist
    mkdir -p "$output_dir"

    # Record the start time
    local start_time=$(date +%s)

    # Get the number of available GPUs
    local NUM_GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

    # Get the list of MP4 files in the input folder
    local video_files=("$input_dir"/*.mp4)

    # Array to store commands for each GPU
    declare -a gpu_commands

    # Initialize commands for each GPU
    for ((i = 0; i < NUM_GPUS; i++)); do
        gpu_commands[$i]=""
    done

    # Assign commands to GPUs
    for ((i = 0; i < ${#video_files[@]}; i++)); do
        local gpu_index=$((i % NUM_GPUS))
        local video="${video_files[$i]}"
        local video_filename=$(basename "$video")
        local output_video="$output_dir/$video_filename"
        gpu_commands[$gpu_index]+="CUDA_VISIBLE_DEVICES=$gpu_index python inference_realesrgan_video.py -i \"$video\" -o \"$output_video\" --suffix HD -n RealESRGAN_x4plus; "
    done

    # Execute the commands for each GPU in parallel
    for ((i = 0; i < NUM_GPUS; i++)); do
        if [ -n "${gpu_commands[$i]}" ]; then
            eval "(${gpu_commands[$i]}) &"
        fi
    done

    # Wait for all background processes to finish
    wait

    # Display the total execution time in a human-readable format
    local end_time=$(date +%s)
    local execution_time=$((end_time - start_time))
    local hours=$((execution_time / 3600))
    local minutes=$(( (execution_time % 3600) / 60 ))
    local seconds=$((execution_time % 60))
    echo "Total execution time: ${hours}h ${minutes}m ${seconds}s"
}

# Call the function with the provided input and output directories
run_processing "$input_dir" "$output_dir"
