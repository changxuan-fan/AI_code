import os
import shutil
import argparse

def split_files_into_subdirs(child_dir, files_per_dir):
    # Check if the child dir exists
    if not os.path.exists(child_dir):
        print(f"Child dir '{child_dir}' does not exist.")
        return
    
    # Get a list of all files in the child dir with .jpg or .png extensions
    files = [f for f in os.listdir(child_dir) if os.path.isfile(os.path.join(child_dir, f)) and (f.lower().endswith('.jpg') or f.lower().endswith('.png'))]

    # Sort the files to ensure consistent distribution
    files.sort() 

    dir_index = 1
    file_count = 0

    for file in files:
        # Determine the current subdir with zero-padded dir index
        current_subdir = os.path.join(child_dir, f"{dir_index:03}")
        os.makedirs(current_subdir, exist_ok=True)

        # Move the file to the current subdir
        shutil.move(os.path.join(child_dir, file), os.path.join(current_subdir, file))

        file_count += 1
        if file_count >= files_per_dir:
            dir_index += 1
            file_count = 0

def process_parent_dir(parent_dir, files_per_dir):
    # Check if the parent dir exists
    if not os.path.exists(parent_dir):
        print(f"Parent dir '{parent_dir}' does not exist.")
        return
    
    # Iterate through each child dir in the parent dir
    for child_dir_name in os.listdir(parent_dir):
        child_dir_path = os.path.join(parent_dir, child_dir_name)
        if os.path.isdir(child_dir_path):
            print(f"Processing child dir: {child_dir_path}")
            split_files_into_subdirs(child_dir_path, files_per_dir)

def main():
    parser = argparse.ArgumentParser(description="Split files into subdirs within each child dir of a parent dir.")
    parser.add_argument('--parent-dir', type=str, required=True, help='The parent dir containing child dirs to process.')
    parser.add_argument('--files-per-dir', type=int, required=True, help='The number of files per subdir.')

    args = parser.parse_args()
    
    process_parent_dir(args.parent_dir, args.files_per_dir)

if __name__ == "__main__":
    main()
