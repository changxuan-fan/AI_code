#! /bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -p <parent_directory> -o <output_directory> -t <temp_file> -c <commands_per_gpu>"
    exit 1
}

# Parse command line options using getopts
while getopts ":p:o:t:c:" opt; do
    case $opt in
        p) PARENT_DIR="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        t) TEMP_FILE="$OPTARG" ;;
        c) COMMANDS_PER_GPU="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check if all required options are provided
if [ -z "$PARENT_DIR" ] || [ -z "$OUTPUT_DIR" ] || [ -z "$TEMP_FILE" ] || [ -z "$COMMANDS_PER_GPU" ]; then
    usage
fi

# Safety enhancement for output directory cleanup
if [ -d "${OUTPUT_DIR}" ]; then
    find "${OUTPUT_DIR}" -mindepth 1 -print -delete  # Log what gets deleted
    echo "Cleared all contents of ${OUTPUT_DIR}"
else
    mkdir -p "${OUTPUT_DIR}"  # Create the directory if it doesn't exist
    echo "Created directory ${OUTPUT_DIR}"
fi

# Adding logging for command execution
echo "Starting processing of videos..."


# Number of GPUs
num_gpus=$(nvidia-smi -L | wc -l)

# Initialize commands for each GPU
declare -a gpu_commands
for ((i = 0; i < num_gpus; i++)); do
    gpu_commands[$i]=()
done

# Loop through each subdirectory in the parent directory
subdir_index=0
for SUBDIR in "$PARENT_DIR"/*; do
    if [ -d "$SUBDIR" ]; then
        > "$TEMP_FILE"  # Clear the temporary file list
        # List all video files in the subdirectory
        for VIDEO_FILE in "$SUBDIR"/*; do
            echo "file '$VIDEO_FILE'" >> "$TEMP_FILE"
        done
        SUBDIR_NAME=$(basename "$SUBDIR")
        gpu_index=$((subdir_index % num_gpus))
        gpu_commands[$gpu_index]+="CUDA_VISIBLE_DEVICES=$gpu_index ffmpeg -y -vsync 0 -hwaccel nvdec -f concat -safe 0 -i \"$TEMP_FILE\" \"$OUTPUT_DIR/$SUBDIR_NAME.mp4\"; "
        subdir_index=$((subdir_index + 1))
    fi
done

# Group the commands for each GPU
declare -a group_gpu_commands
for ((i = 0; i < num_gpus; i++)); do
    group_gpu_commands[$i]=()
    total_commands=${#gpu_commands[$i][@]}
    # Avoid getting 0 num_commands_per_group
    num_commands_per_group=$(( (total_commands + COMMANDS_PER_GPU - 1) / COMMANDS_PER_GPU ))
    for ((j = 0; j < total_commands; j += num_commands_per_group)); do
        # Join a batch of commands using ';'
        group_gpu_commands[$i]+=("$(printf "%s" "${gpu_commands[$i][@]:j:num_commands_per_group}" | sed 's/; $//')")
    done
done

# Execute the grouped commands in the desired order
for ((i = 0; i < COMMANDS_PER_GPU; i++)); do
    cmd=""
    for ((j = 0; j < num_gpus; j++)); do
        if [ -n "${group_gpu_commands[$j][$i]}" ]; then
            cmd+="(${group_gpu_commands[$j][$i]}) & "
        fi
    done
    eval "$cmd wait"
    sleep 1
done


# Remove the temporary file list
rm "$TEMP_FILE"
echo "All videos have been combined and stored in $OUTPUT_DIR."
