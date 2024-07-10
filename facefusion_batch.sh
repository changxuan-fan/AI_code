#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -i <input_folder> -o <output_folder> -f <face_img> -p <GPU_PROCESS_NUM>"
    exit 1
}

# Parse command line options using getopts
while getopts ":i:o:f:c:" opt; do
    case $opt in
        f) face_img="$OPTARG" ;;
        i) input_folder="$OPTARG" ;;
        o) output_folder="$OPTARG" ;;
        p) GPU_PROCESS_NUM="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check if all required options are provided
if [ -z "$input_folder" ] || [ -z "$output_folder" ] || [ -z "$face_img" ] || [ -z "$GPU_PROCESS_NUM" ]; then
    usage
fi

# Ensure GPU_PROCESS_NUM is a number and greater than 0
if ! [[ "$GPU_PROCESS_NUM" =~ ^[0-9]+$ ]] || [ "$GPU_PROCESS_NUM" -le 0 ]; then
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

echo "FaceFusion Processing"

run_processing() {
    local NUM_GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

    # Initialize commands for each GPU
    # gpu_commands look like this:
    # ["command1; & command2; & command3", "command1; & command2; & command3"]
    declare -A gpu_commands
    for ((i = 0; i < NUM_GPUS; i++)); do
        gpu_commands[$i]=""
    done

    local video_files=("$input_folder"/*.mp4)
    for ((i = 0; i < ${#video_files[@]}; i++)); do
        local gpu_index=$((i % NUM_GPUS))
        local video="${video_files[$i]}"
        local video_filename=$(basename "$video")
        local output_video="$output_folder/$video_filename"
        gpu_commands[$gpu_index]+="CUDA_VISIBLE_DEVICES=$gpu_index python run.py -t \"$video\" -s \"$face_img\" -o \"$output_video\" --face-mask-types region --face-mask-blur 0.8 --face-mask-regions skin;&"
    done

    # Group the commands for each GPU
    # group_gpu_commands look like this:
    # ["command1;command3 & command2;commmand4", "command1;command3 & command2;commmand4"]
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
    # order is GPU1-n, then GPU1-n for each individual subprocess
    for ((i = 0; i < GPU_PROCESS_NUM; i++)); do
        for ((j = 0; j < NUM_GPUS; j++)); do
            if [ -n "${group_gpu_commands[$j]}" ]; then
                # Split the commands by & and check the GPU_PROCESS_NUM element
                IFS='&' read -ra commands <<< "${group_gpu_commands[$j]}"
                if [ -n "${commands[$i]}" ]; then
                    eval "(${commands[$i]}) &"
                    sleep 1
                fi
            fi
        done
    done

    # Wait for all background to exit
    wait
}

run_processing
