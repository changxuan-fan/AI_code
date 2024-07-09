#!/bin/bash

# Function to split files into subdirectories
split_files_into_subdirs() {
  local child_dir=$1
  local files_per_dir=$2

  # Check if the child dir exists
  if [ ! -d "$child_dir" ]; then
    echo "Child dir '$child_dir' does not exist."
    return
  fi

  # Get a list of all .jpg and .png files in the child dir
  files=($(ls "$child_dir" | grep -E "\.jpg$|\.png$" | sort))

  local dir_index=1
  local file_count=0

  for file in "${files[@]}"; do
    # Determine the current subdir with zero-padded dir index
    current_subdir=$(printf "%s/%03d" "$child_dir" "$dir_index")
    mkdir -p "$current_subdir"

    # Move the file to the current subdir
    mv "$child_dir/$file" "$current_subdir/"

    file_count=$((file_count + 1))
    if [ "$file_count" -ge "$files_per_dir" ]; then
      dir_index=$((dir_index + 1))
      file_count=0
    fi
  done
}

# Function to process the parent directory
process_parent_dir() {
  local parent_dir=$1
  local files_per_dir=$2

  # Check if the parent dir exists
  if [ ! -d "$parent_dir" ]; then
    echo "Parent dir '$parent_dir' does not exist."
    return
  fi

  # Iterate through each child dir in the parent dir
  for child_dir_name in "$parent_dir"/*; do
    if [ -d "$child_dir_name" ]; then
      echo "Processing child dir: $child_dir_name"
      split_files_into_subdirs "$child_dir_name" "$files_per_dir"
    fi
  done
}

# Main script execution
main() {
  # Parse arguments
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --parent-dir) parent_dir="$2"; shift ;;
      --files-per-dir) files_per_dir="$2"; shift ;;
      *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
  done

  if [ -z "$parent_dir" ] || [ -z "$files_per_dir" ]; then
    echo "Usage: $0 --parent-dir <parent_dir> --files-per-dir <files_per_dir>"
    exit 1
  fi

  process_parent_dir "$parent_dir" "$files_per_dir"
}

main "$@"
