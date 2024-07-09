#!/bin/bash

process_parent_folder() {
    local parent_input_dir=$1
    local parent_output_dir=$2
    local detected_text_dir=$3

    if [[ ! -d "$parent_input_dir" ]]; then
        echo "Parent input directory '$parent_input_dir' does not exist."
        exit 1
    fi

    mkdir -p "$parent_output_dir"
    mkdir -p "$detected_text_dir"

    # Array to store commands for each GPU
    declare -a gpu_commands

    # Number of GPUs
    num_gpus=$(nvidia-smi -L | wc -l)

    # Initialize commands for each GPU
    for ((i = 0; i < num_gpus; i++)); do
        gpu_commands[$i]=""
    done

    # Loop through each child folder
    child_index=0
    for child_folder_name in $(ls "$parent_input_dir"); do
        local child_input_dir="$parent_input_dir/$child_folder_name"
        local child_output_dir="$parent_output_dir/$child_folder_name"
        local child_text_file="$detected_text_dir/$child_folder_name.txt"


        if [[ -d "$child_input_dir" ]]; then
            echo "Processing child folder: $child_input_dir"

            # Assign the command to the appropriate GPU
            gpu_index=$((child_index % num_gpus))
            gpu_commands[$gpu_index]+="CUDA_VISIBLE_DEVICES=$gpu_index python process_images.py \"$child_input_dir\" \"$child_output_dir\" \"$child_text_file\"; "

            child_index=$((child_index + 1))
        fi
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

main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --parent-input-dir)
                parent_input_dir="$2"
                shift 2
                ;;
            --parent-output-dir)
                parent_output_dir="$2"
                shift 2
                ;;
            --detected_text_dir)
                detected_text_dir="$2"
                shift 2
                ;;
            *)
                echo "Unknown parameter passed: $1"
                exit 1
                ;;
        esac
    done

    if [[ -z $parent_input_dir || -z $parent_output_dir ]]; then
        echo "Usage: $0 --parent-input-dir <input_dir> --parent-output-dir <output_dir>"
        exit 1
    fi

    process_parent_folder "$parent_input_dir" "$parent_output_dir" "$detected_text_dir"
}

main "$@"
