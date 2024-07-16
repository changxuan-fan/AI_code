import os
import fire
from typing import List, Optional
from llama import Dialog, Llama

def read_file(file_path: str) -> str:
    """Read the content of a text file."""
    with open(file_path, 'r', encoding='utf-8') as file:
        return file.read()

def write_file(output_path: str, content: str):
    """Write content to a text file."""
    with open(output_path, 'w', encoding='utf-8') as file:
        file.write(content)

def split_files(files: List[str], gpu_count: int, gpu_index: int) -> List[str]:
    """Split the list of files into parts and return the part corresponding to the gpu_index."""
    split_size = len(files) // gpu_count
    remainder = len(files) % gpu_count
    start_index = gpu_index * split_size + min(gpu_index, remainder)
    end_index = start_index + split_size + (1 if gpu_index < remainder else 0)
    return files[start_index:end_index]

def translate_files(
    input_dir: str,
    output_dir: str,
    ckpt_dir: str,
    tokenizer_path: str,
    gpu_count: int,
    gpu_index: int,
    max_batch_size: int,
    temperature: float = 0.3,
    top_p: float = 0.9,
    max_seq_len: int = 2048,
    max_gen_len: Optional[int] = None,
):
    """Translate a part of Chinese text files to English using LLaMA and save the results."""
    
    system_prompt = (
        "Step 1: Understand the context of the provided audio transcription and authentically translate the Chinese text into fluent American English.\n"
        "Step 2: Make the translation into a colloquial style, organizing it into appropriate paragraphs based on the speaker.\n"
        "Now I will give you the Chinese text, please give me the both tranlsation from step 1 and 2:\n"
    )
    
    generator = Llama.build(
        ckpt_dir=ckpt_dir,
        tokenizer_path=tokenizer_path,
        max_seq_len=max_seq_len,
        max_batch_size=max_batch_size,
    )

    # Get all files from the input directory
    all_files = [os.path.join(input_dir, f) for f in os.listdir(input_dir) if os.path.isfile(os.path.join(input_dir, f))]
    # Split the files and get the part corresponding to gpu_index
    files_to_process = split_files(all_files, gpu_count, gpu_index)

    dialogues = [
        [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": read_file(input_file)}
        ]
        for input_file in files_to_process
    ]

    results = generator.chat_completion(
        dialogues,
        max_gen_len=max_gen_len,
        temperature=temperature,
        top_p=top_p,
    )

    for i, result in enumerate(results):
        translated_text = result['generation']['content']

        # Get the base name of the input file (filename.ext)
        basename = os.path.basename(files_to_process[i])
        # Remove the extension
        filename_without_ext = os.path.splitext(basename)[0]
        # Create the output file path
        output_file = f"{output_dir}/{filename_without_ext}_English.txt"
        
        write_file(output_file, translated_text)
        print(f"Translation saved to {output_file}")

if __name__ == "__main__":
    fire.Fire(translate_files)
