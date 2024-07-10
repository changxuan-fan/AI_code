#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -i <input_dir> -o <output_dir> -p <GPU_PROCESS_NUM>"
    exit 1
}

# Parse command line options using getopts
while getopts ":i:o:p:" opt; do
    case $opt in
        i) input_dir="$OPTARG" ;;
        o) output_dir="$OPTARG" ;;
        p) GPU_PROCESS_NUM="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check if all required options are provided
if [ -z "$input_dir" ] || [ -z "$output_dir" ] || [ -z "$GPU_PROCESS_NUM" ]; then
    usage
fi

# Ensure GPU_PROCESS_NUM is a number and greater than 0
if ! [[ "$GPU_PROCESS_NUM" =~ ^[0-9]+$ ]] || [ "$GPU_PROCESS_NUM" -le 0 ]; then
    echo "Error: The number of commands per GPU must be a positive number."
    exit 1
fi

# Ensure output directory exists
if [ -d "$output_dir" ]; then
    find "$output_dir" -mindepth 1 -print -delete  # Log what gets deleted
    echo "Cleared all contents of $output_dir"
else
    mkdir -p "$output_dir"  # Create the directory if it doesn't exist
    echo "Created directory $output_dir"
fi

echo "Starting processing of videos..."

run_processing() {
    # Record the start time
    local start_time=$(date +%s)

    # Get the number of available GPUs
    local NUM_GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

    # Get the list of MP4 files in the input folder
    local video_files=("$input_dir"/*.mp4)

    # Initialize commands for each GPU
    declare -A gpu_commands
    for ((i = 0; i < NUM_GPUS; i++)); do
        gpu_commands[$i]=""
    done

    # Assign commands to GPUs
    for ((i = 0; i < ${#video_files[@]}; i++)); do
        local gpu_index=$((i % NUM_GPUS))
        local video="${video_files[$i]}"
        local video_filename=$(basename "$video")
        local output_video="$output_dir/$video_filename"
        gpu_commands[$gpu_index]+="CUDA_VISIBLE_DEVICES=$gpu_index python inference_realesrgan_video.py -i \"$video\" -o \"$output_video\" --suffix HD -n RealESRGAN_x4plus;&"
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

    # Wait for all background processes to finish
    wait
}

# Call the function with the provided input and output directories
run_processing 
