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

    # Number of GPUs
    num_gpus=$(nvidia-smi -L | wc -l)

    # Array to track GPU availability
    declare -a gpu_available
    for ((i = 0; i < num_gpus; i++)); do
        gpu_available[i]=1
    done

    # Array to hold PIDs for background processes
    declare -a gpu_pids

    # Loop through each child folder
    for child_folder_name in $(ls "$parent_input_dir"); do
        local child_input_dir="$parent_input_dir/$child_folder_name"
        local child_output_dir="$parent_output_dir/$child_folder_name"
        local child_text_file="$detected_text_dir/$child_folder_name.txt"

        if [[ -d "$child_input_dir" ]]; then
            echo "Processing child folder: $child_input_dir"

            first_command_executed=false

            while : ; do
                for ((i = 0; i < num_gpus; i++)); do
                    if [[ ${gpu_available[i]} -eq 1 ]]; then
                        if [[ "$first_command_executed" == false ]]; then
                            CUDA_VISIBLE_DEVICES=$i python /workspace/AI_code/process_images.py "$child_input_dir" "$child_output_dir" "$child_text_file"
                            first_command_executed=true
                        else
                            gpu_available[i]=0
                            CUDA_VISIBLE_DEVICES=$i python /workspace/AI_code/process_images.py "$child_input_dir" "$child_output_dir" "$child_text_file" &
                            gpu_pids[i]=$!
                            sleep 1
                            break 2
                        fi
                    fi
                done

                # Check if any GPU has finished its task
                for ((i = 0; i < num_gpus; i++)); do
                    if [[ -n "${gpu_pids[i]}" && ! -e /proc/${gpu_pids[i]} ]]; then
                        gpu_available[i]=1
                    fi
                done
                sleep 0.1
            done
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
            --detected-text-dir)
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
