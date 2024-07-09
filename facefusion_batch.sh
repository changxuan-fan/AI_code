#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -i <input_folder> -o <output_folder> -f <face_img>"
    exit 1
}

# Parse command line options using getopts
while getopts ":i:o:f:" opt; do
    case $opt in
        i) input_folder="$OPTARG" ;;
        o) output_folder="$OPTARG" ;;
        f) face_img="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check if all required options are provided
if [ -z "$input_folder" ] || [ -z "$output_folder" ] || [ -z "$face_img" ]; then
    usage
fi

run_processing() {
    local input_folder="$1"
    local output_folder="$2"
    local face_img="$3"

    # Create the output folder if it doesn't exist
    mkdir -p "$output_folder"

    # Record the start time
    local start_time=$(date +%s)

    # Get the number of available GPUs
    local NUM_GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

    # Get the list of MP4 files in the input folder
    local video_files=("$input_folder"/*.mp4)

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
        local output_video="$output_folder/$video_filename"
        gpu_commands[$gpu_index]+="CUDA_VISIBLE_DEVICES=$gpu_index python run.py -t \"$video\" -s \"$face_img\" -o \"$output_video\" --face-mask-types region --face-mask-blur 0.8 --face-mask-regions skin; "
    done

    # Execute the commands for each GPU in parallel
    for ((i = 0; i < NUM_GPUS; i++)); do
        if [ -n "${gpu_commands[$i]}" ]; then
            eval "(${gpu_commands[$i]}) &"
            sleep 1
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

# Call the function with the provided arguments
run_processing "$input_folder" "$output_folder" "$face_img"
