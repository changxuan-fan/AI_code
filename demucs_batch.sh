#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -i <INPUT_DIR> -o <OUTPUT_DIR> -p <GPU_PROCESS_NUM>"
    exit 1
}

# Parse command line options using getopts
while getopts ":i:o:p:" opt; do
    case $opt in
        i) INPUT_DIR="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        p) GPU_PROCESS_NUM="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check if all required options are provided
if [ -z "$INPUT_DIR" ] || [ -z "$OUTPUT_DIR" ] || [ -z "$GPU_PROCESS_NUM" ]; then
    usage
fi

# Ensure GPU_PROCESS_NUM is a number and greater than 0
if ! [[ "$GPU_PROCESS_NUM" =~ ^[0-9]+$ ]] || [ "$GPU_PROCESS_NUM" -le 0 ]; then
    echo "Error: The number of commands per GPU must be a positive number."
    exit 1
fi

# Ensure output directory exists and is empty
if [ -d "$OUTPUT_DIR/htdemucs" ]; then
    find "$OUTPUT_DIR/htdemucs" -mindepth 1 -print -delete  # Log what gets deleted
    echo "Cleared all contents of $OUTPUT_DIR/htdemucs"
else
    mkdir -p "$OUTPUT_DIR"  # Create the directory if it doesn't exist
fi

echo "Starting audio separation from files in $INPUT_DIR..."

run_separation() {
    export TORCH_HOME=/workspace/demucs/models

    local NUM_GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

    # Initialize commands for each GPU
    declare -A gpu_commands
    for ((i = 0; i < NUM_GPUS; i++)); do
        gpu_commands[$i]=""
    done

    local audio_files=("$INPUT_DIR"/*.mp4 "$INPUT_DIR"/*.MP4)
    for ((i = 0; i < ${#audio_files[@]}; i++)); do
        local gpu_index=$((i % NUM_GPUS))
        local audio="${audio_files[$i]}"
        gpu_commands[$gpu_index]+="CUDA_VISIBLE_DEVICES=$gpu_index demucs \
        --device cuda \
        --jobs 4 \
        --mp3 \
        --filename \"{track}/{track}_{stem}.{ext}\" \
        --out \"$OUTPUT_DIR\" \
        \"$audio\";&"
    done

    # Group the commands for each GPU
    declare -A group_gpu_commands
    for ((i = 0; i < NUM_GPUS; i++)); do
        IFS='&' read -ra commands_array <<< "${gpu_commands[$i]}"
        local total_commands=$(echo "${gpu_commands[$i]}" | tr -cd '&' | wc -c)
        local num_commands_per_group=$(( (total_commands + GPU_PROCESS_NUM - 1) / GPU_PROCESS_NUM ))
        group_gpu_commands[$i]=""
        for ((j = 0; j < ${#commands_array[@]}; j += num_commands_per_group)); do
            group_gpu_commands[$i]+="${commands_array[@]:j:num_commands_per_group} &"
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

run_separation

echo "All audio files have been separated and stored in $OUTPUT_DIR."
