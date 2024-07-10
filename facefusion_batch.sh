#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -i <input_folder> -o <output_folder> -f <face_img> -c <commands_per_gpu>"
    exit 1
}

# Parse command line options using getopts
while getopts ":i:o:f:c:" opt; do
    case $opt in
        i) input_folder="$OPTARG" ;;
        o) output_folder="$OPTARG" ;;
        f) face_img="$OPTARG" ;;
        c) COMMANDS_PER_GPU="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check if all required options are provided
if [ -z "$input_folder" ] || [ -z "$output_folder" ] || [ -z "$face_img" ] || [ -z "$COMMANDS_PER_GPU" ]; then
    usage
fi

# Ensure COMMANDS_PER_GPU is a number and greater than 0
if ! [[ "$COMMANDS_PER_GPU" =~ ^[0-9]+$ ]] || [ "$COMMANDS_PER_GPU" -le 0 ]; then
    echo "Error: The number of commands per GPU must be a positive number."
    exit 1
fi

# Ensure output directory exists and is empty
if [ -d "$output_folder" ]; then
    find "$output_folder" -mindepth 1 -print -delete  # Log what gets deleted
    echo "Cleared all contents of $output_folder"
else
    mkdir -p "$output_folder"  # Create the directory if it doesn't exist
    echo "Created directory $output_folder"
fi

echo "Starting processing of videos..."

run_processing() {
    local NUM_GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

    # Initialize commands for each GPU
    declare -a gpu_commands
    for ((i = 0; i < NUM_GPUS; i++)); do
        gpu_commands[$i]=()
    done

    local video_files=("$input_folder"/*.mp4)
    for ((i = 0; i < ${#video_files[@]}; i++)); do
        local gpu_index=$((i % NUM_GPUS))
        local video="${video_files[$i]}"
        local video_filename=$(basename "$video")
        local output_video="$output_folder/$video_filename"
        gpu_commands[$gpu_index]+="CUDA_VISIBLE_DEVICES=$gpu_index python run.py -t \"$video\" -s \"$face_img\" -o \"$output_video\" --face-mask-types region --face-mask-blur 0.8 --face-mask-regions skin; "
    done

    # Group the commands for each GPU
    declare -a group_gpu_commands
    for ((i = 0; i < NUM_GPUS; i++)); do
        group_gpu_commands[$i]=()
        local total_commands=${#gpu_commands[$i][@]}
        local num_commands_per_group=$(( (total_commands + COMMANDS_PER_GPU - 1) / COMMANDS_PER_GPU ))
        for ((j = 0; j < total_commands; j += num_commands_per_group)); do
            group_gpu_commands[$i]+=("$(printf "%s" "${gpu_commands[$i][@]:j:num_commands_per_group}" | sed 's/; $//')")
        done
    done

    # Execute the grouped commands in the desired order
    for ((i = 0; i < COMMANDS_PER_GPU; i++)); do
        local cmd=""
        for ((j = 0; j < NUM_GPUS; j++)); do
            if [ -n "${group_gpu_commands[$j][$i]}" ]; then
                cmd+="(${group_gpu_commands[$j][$i]}) & "
            fi
        done
        eval "$cmd wait"
        sleep 1
    done
}

run_processing
