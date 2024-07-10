#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 --i <input_dir> --o <output_dir> --t <detected_text_dir> --p <GPU_PROCESS_NUM>"
    exit 1
}

# Parse command line options using getopts
while getopts ":i:o:t:p:" opt; do
    case $opt in
        i) parent_input_dir="$OPTARG" ;;
        o) parent_output_dir="$OPTARG" ;;
        t) detected_text_dir="$OPTARG" ;;
        p) GPU_PROCESS_NUM="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check if all required options are provided
if [[ -z $parent_input_dir || -z $parent_output_dir || -z $detected_text_dir || -z $GPU_PROCESS_NUM ]]; then
    usage
fi

# Ensure GPU_PROCESS_NUM is a number and greater than 0
if ! [[ "$GPU_PROCESS_NUM" =~ ^[0-9]+$ ]] || [ "$GPU_PROCESS_NUM" -le 0 ]; then
    echo "Error: The number of commands per GPU must be a positive number."
    exit 1
fi

# Ensure output directories exist
mkdir -p "$parent_output_dir"
mkdir -p "$detected_text_dir"

echo "PaddleOCR Processing..."

run_processing() {
    local NUM_GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

    # Initialize commands for each GPU
    declare -A gpu_commands
    for ((i = 0; i < NUM_GPUS; i++)); do
        gpu_commands[$i]=""
    done

    # Loop through each child folder in the parent input directory
    local child_folder_index=0
    for child_folder_name in $(ls "$parent_input_dir"); do
        local child_input_dir="$parent_input_dir/$child_folder_name"
        local child_output_dir="$parent_output_dir/$child_folder_name"
        local child_text_file="$detected_text_dir/$child_folder_name.txt"

        if [[ -d "$child_input_dir" ]]; then
            echo "Processing child folder: $child_input_dir"

            local gpu_index=$((child_folder_index % NUM_GPUS))
            gpu_commands[$gpu_index]+="CUDA_VISIBLE_DEVICES=$gpu_index python /workspace/AI_code/process_images.py \"$child_input_dir\" \"$child_output_dir\" \"$child_text_file\";&"
            child_folder_index=$((child_folder_index + 1))
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
                    if [[ $i -eq 0 && $j -eq 0 ]]; then
                        eval "(${commands[$i]}) &"
                        sleep 30
                    else
                        eval "(${commands[$i]}) &"
                        sleep 1
                    fi
                fi
            fi
        done
    done

    # Wait for all background processes to finish
    wait
}

run_processing
