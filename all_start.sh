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
  execution_times+=("$cmd: ${elapsed_time} seconds")
}

# Function to track GPU memory usage and utilization
track_gpu_metrics() {
  > /workspace/gpu_metrics.log
  while true; do
    nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv,noheader,nounits >> /workspace/gpu_metrics.log
    echo "" >> /workspace/gpu_metrics.log
    sleep 0.5
  done
}

# Start tracking GPU metrics
track_gpu_metrics &
GPU_TRACK_PID=$!

# Execute commands and track time

chmod +x /workspace/AI_code/*
mkdir -p /workspace/results

./separate_audio.sh -i /workspace/demucs/inputs -o /workspace/results -p 2

source /workspace/env/facefusion_env/bin/activate
cd /workspace/facefusion
track_time /workspace/AI_code/facefusion_batch.sh -f /workspace/facefusion/face_food_eating.webp -i /workspace/facefusion/inputs -o /workspace/results/swapped -p 2
track_time /workspace/AI_code/extract_frames.sh -i /workspace/results/swapped -o /workspace/results/frames -p 2
deactivate

source /workspace/env/paddle_env/bin/activate
cd /workspace/PaddleOCR
track_time /workspace/AI_code/paddle_batch.sh -i /workspace/results/frames -o /workspace/results/frames-mask -t /workspace/results/detected_text -p 2
track_time /workspace/AI_code/split_dir.sh --parent-dir /workspace/results/frames --files-per-dir 600 --process-num 2
track_time /workspace/AI_code/split_dir.sh --parent-dir /workspace/results/frames-mask --files-per-dir 600 --process-num 2
deactivate

source /workspace/env/propainter_env/bin/activate
cd /workspace/ProPainter
track_time /workspace/AI_code/propainter_batch.sh -v /workspace/results/frames -m /workspace/results/frames-mask -o /workspace/results/propainted -p 2
track_time /workspace/AI_code/extract_propainter.sh -input-dir /workspace/results/propainted -output-dir /workspace/results/propaint_extracted --process-num 2
track_time /workspace/AI_code/combine_videos.sh -i /workspace/results/propaint_extracted -o /workspace/results/propaint_combined -t /workspace/results/file_list.txt -p 2
deactivate

source /workspace/env/esrgan_env/bin/activate
cd /workspace/Real-ESRGAN
track_time /workspace/AI_code/esrgan_batch.sh -i /workspace/results/propaint_combined -o /workspace/results/HD -p 2
deactivate

# Stop tracking GPU metrics
kill $GPU_TRACK_PID

# Print all execution times at the end
echo "Execution times for each command:"
for time in "${execution_times[@]}"; do
  echo "$time"
done

file_end_time=$(date +%s)
file_execution_time=$((file_end_time - file_start_time))

echo "All environments have been set up in $file_execution_time seconds."

# Get the maximum GPU memory usage and average GPU utilization
max_gpu_memory=$(awk -F, '{print $1}' /workspace/gpu_metrics.log | sort -nr | head -n 1)
avg_gpu_utilization=$(awk -F, '{sum+=$2; count++} END {print sum/count}' /workspace/gpu_metrics.log)
echo "Maximum GPU memory usage: ${max_gpu_memory} MiB"
echo "Average GPU utilization: ${avg_gpu_utilization} %"
