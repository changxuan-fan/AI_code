#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -i <INPUT_DIR> -o <OUTPUT_DIR> -p <Maximum_Batch_Size>"
    exit 1
}

# Parse command line options using getopts
while getopts ":i:o:p:" opt; do
    case $opt in
        i) INPUT_DIR="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        p) max_batch_size="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check if all required options are provided
if [ -z "$INPUT_DIR" ] || [ -z "$OUTPUT_DIR" ] || [ -z "$max_batch_size" ]; then
    usage
fi

# Ensure output directory exists and is empty
if [ -d "$OUTPUT_DIR" ]; then
    find "$OUTPUT_DIR" -mindepth 1 -print -delete  # Log what gets deleted
    echo "Cleared all contents of $OUTPUT_DIR"
else
    mkdir -p "$OUTPUT_DIR"  # Create the directory if it doesn't exist
    echo "Created directory $OUTPUT_DIR"
fi

echo "Starting translation of files in $INPUT_DIR..."

run_translation() {
    local NUM_GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

    # Initialize commands for each GPU
    declare -A gpu_commands
    for ((i = 0; i < NUM_GPUS; i++)); do
        gpu_commands[$i]=""
    done

    for ((i = 0; i < 1; i++)); do
        echo "Start processing files for GPU $i"
        gpu_commands[$i]="CUDA_VISIBLE_DEVICES=$i torchrun --nproc_per_node 1 /workspace/AI_code/translate_file.py \
            --input_dir \"$INPUT_DIR\" \
            --output_dir \"$OUTPUT_DIR\" \
            --ckpt_dir /workspace/llama3/Meta-Llama-3-8B-Instruct/ \
            --tokenizer_path /workspace/llama3/Meta-Llama-3-8B-Instruct/tokenizer.model \
            --gpu_count $NUM_GPUS --gpu_index $i \
            --max_seq_len 2048 --max_batch_size $max_batch_size;"
    done

    # Execute the commands for each GPU in parallel
    for ((i = 0; i < NUM_GPUS; i++)); do
        if [ -n "${gpu_commands[$i]}" ]; then
            eval "(${gpu_commands[$i]}) &"
        fi
    done

    # Wait for all background processes to exit
    wait
}

run_translation

echo "All files in $INPUT_DIR have been translated and stored in $OUTPUT_DIR."
