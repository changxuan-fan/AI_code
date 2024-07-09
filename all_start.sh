#!/bin/bash

file_start_time=$(date +%s)

# Initialize an array to store the execution times
declare -a execution_times

# Function to track execution time
track_time() {
  local start_time=$(date +%s)
  local cmd="$1"
  shift
  "$cmd" "$@"
  local end_time=$(date +%s)
  local elapsed_time=$((end_time - start_time))
  execution_times+=("Time taken for $cmd: ${elapsed_time} seconds")
}

# Function to track GPU memory usage
track_gpu_memory() {
  while true; do
    nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits >> /workspace/gpu_memory.log
    sleep 0.1
  done
}

# Start tracking GPU memory usage
track_gpu_memory &
GPU_TRACK_PID=$!

# Execute commands and track time

chmod +x /workspace/AI_code/*
mkdir -p /workspace/results

conda activate facefusion_env
cd /workspace/facefusion
track_time /workspace/AI_code/facefusion_batch.sh  -f /workspace/facefusion/face_food_eating.webp -i /workspace/facefusion/inputs -o /workspace/results/swapped
track_time /workspace/AI_code/extract_frames.sh -i /workspace/results/swapped -o /workspace/results/frames
conda deactivate

conda activate paddle_env
cd /workspace/PaddleOCR
track_time /workspace/AI_code/paddle_batch.sh --parent-input-dir /workspace/results/frames --parent-output-dir /workspace/results/frames-mask --detected-text-dir /workspace/results/detected_text
track_time /workspace/AI_code/split_dir.sh --parent-dir /workspace/results/frames --files-per-dir 600
track_time /workspace/AI_code/split_dir.sh --parent-dir /workspace/results/frames-mask --files-per-dir 600
conda deactivate

conda activate propainter_env
cd /workspace/ProPainter
track_time /workspace/AI_code/propainter_batch.sh -v /workspace/results/frames  -m /workspace/results/frames-mask -o /workspace/results/propainted
track_time /workspace/AI_code/extract_propainter.sh -i /workspace/results/propainted -o /workspace/results/propaint_extracted
track_time /workspace/AI_code/combine_videos.sh -p /workspace/results/propaint_extracted -o /workspace/results/propaint_combined -t /workspace/results/file_list.txt
conda deactivate

conda activate esrgan_env
cd /workspace/Real-ESRGAN
track_time /workspace/AI_code/esrgan_batch.sh -i /workspace/results/propaint_combined -o results /workspace/results/HD
conda deactivate

# Stop tracking GPU memory usage
kill $GPU_TRACK_PID

# Print all execution times at the end
echo "Execution times for each command:"
for time in "${execution_times[@]}"; do
  echo "$time"
done

file_end_time=$(date +%s)
file_execution_time=$((file_end_time - file_start_time))

echo "All environments have been set up in $file_execution_time seconds."

# Get the maximum GPU memory usage
max_gpu_memory=$(sort -nr /workspace/gpu_memory.log | head -n 1)
echo "Maximum GPU memory usage: ${max_gpu_memory} MiB"

# Clean up
rm /workspace/gpu_memory.log
