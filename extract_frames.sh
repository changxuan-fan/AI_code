#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -i <input_folder> -o <output_folder>"
    exit 1
}

# Parse command line options using getopts
while getopts ":i:o:" opt; do
    case $opt in
        i) input_folder="$OPTARG" ;;
        o) output_folder="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check if all required options are provided
if [ -z "$input_folder" ] || [ -z "$output_folder" ]; then
    usage
fi

# Function to extract frames from a video
extract_frames() {
    local input_folder="$1"
    local output_folder="$2"

    # Array to store commands for each GPU
    declare -a gpu_commands

    # Number of GPUs
    num_gpus=$(nvidia-smi -L | wc -l)

    # Initialize commands for each GPU
    for ((i = 0; i < num_gpus; i++)); do
        gpu_commands[$i]=""
    done

    # Loop through each video file in the directory
    video_index=0
    for VIDEO_FILE in "$input_folder"/*.mp4; do
        # Get the base name of the video file (without the directory and extension)
        local BASE_NAME=$(basename "$VIDEO_FILE" .mp4)

        # Create a directory for the frames of this video
        mkdir -p "$output_folder/$BASE_NAME"

        # Assign the command to the appropriate GPU
        gpu_index=$((video_index % num_gpus))
        gpu_commands[$gpu_index]+="CUDA_VISIBLE_DEVICES=$gpu_index ffmpeg -y -vsync 0 -hwaccel cuda -i \"$VIDEO_FILE\" -vf scale=360:640 -qscale:v 1 \"$output_folder/$BASE_NAME/frame_%04d.jpg\"; "

        video_index=$((video_index + 1))
    done

    # Execute the commands for each GPU
    for ((i = 0; i < num_gpus; i++)); do
        if [ -n "${gpu_commands[$i]}" ]; then
            eval "(${gpu_commands[$i]}) &"
        fi
    done

    # Wait for all background processes to finish
    wait
}

# Call the function with the provided arguments
extract_frames "$input_folder" "$output_folder"
