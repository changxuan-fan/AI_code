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
    nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits >> gpu_memory.log
    sleep 0.1
  done
}

# Start tracking GPU memory usage
track_gpu_memory &
GPU_TRACK_PID=$!

# Execute commands and track time

chmod +x /workspace/AI_code/*

conda activate facefusion_env
cd /workspace/facefusion
track_time /workspace/AI_code/facefusion_batch.sh -i inputs -o results -f face_food_eating.webp
track_time /workspace/AI_code/extract_frames.sh -i results -o /workspace/PaddleOCR/frames
conda deactivate

conda activate paddle_env
cd /workspace/PaddleOCR
track_time /workspace/AI_code/paddle_batch.sh --parent-input-dir frames --parent-output-dir frames-mask --detected_text_dir detected_text
track_time python /workspace/AI_code/split_dir.py --parent-dir frames --files-per-dir 600
track_time python /workspace/AI_code/split_dir.py --parent-dir frames-mask --files-per-dir 600
conda deactivate

conda activate propainter_env
cd /workspace/ProPainter
track_time /workspace/AI_code/propainter_batch.sh -v /workspace/PaddleOCR/frames -m /workspace/PaddleOCR/frames-mask
track_time /workspace/AI_code/extract_propainter.sh -i results -o results_extracted
track_time /workspace/AI_code/combine_videos.sh -p results_extracted -o results_combined -t file_list.txt
conda deactivate

conda activate esrgan_env
cd /workspace/Real-ESRGAN
track_time /workspace/AI_code/esrgan_batch.sh -i /workspace/ProPainter/results_combined -o results
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
max_gpu_memory=$(sort -nr gpu_memory.log | head -n 1)
echo "Maximum GPU memory usage: ${max_gpu_memory} MiB"

# Clean up
cd /workspace
rm gpu_memory.log
