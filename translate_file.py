import os
import fire
from typing import Optional
from llama import Dialog, Llama

def read_file(file_path: str) -> str:
    """Read the content of a text file."""
    with open(file_path, 'r', encoding='utf-8') as file:
        return file.read()

def write_file(output_path: str, content: str):
    """Write content to a text file."""
    with open(output_path, 'w', encoding='utf-8') as file:
        file.write(content)

def translate_file(
    input_file: str,
    output_dir: str,
    ckpt_dir: str,
    tokenizer_path: str,
    temperature: float = 0.6,
    top_p: float = 0.9,
    max_seq_len: int = 2048,
    max_batch_size: int = 1,
    max_gen_len: Optional[int] = 8000,
):
    """Translate a Chinese text file to English using LLaMA and save the result."""
    
    system_prompt = (
        "Step 1: Understand the context of the provided audio transcription and authentically translate the Chinese text into fluent American English.\n"
        "Step 2: Make the translation into a colloquial style, organizing it into appropriate paragraphs based on the speaker.\n"
        "Step 3: Devise a humorous, controversial, or exaggerated title and description for the translated content. "
        "The title should be no more than 5 words, and the description should be no more than 10 words. "
        "Ensure both the title and description are engaging and attention-grabbing for the audience. Provide 3 options for titles and descriptions.\n"
        "Step 4: Generate relevant viral tags for the content suitable for social media platforms.\n"
        "The output should include step1-4 and also include my original Chinese text."
    )

    generator = Llama.build(
        ckpt_dir=ckpt_dir,
        tokenizer_path=tokenizer_path,
        max_seq_len=max_seq_len,
        max_batch_size=max_batch_size,
    )

    content = read_file(input_file)

    dialog = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": content},
    ]

    result = generator.chat_completion(
        [dialog],
        max_gen_len=max_gen_len,
        temperature=temperature,
        top_p=top_p,
    )[0]

    translated_text = result['generation']['content']
    
    # Get the base name of the input file (filename.ext)
    basename = os.path.basename(input_file)
    # Remove the extension
    filename_without_ext = os.path.splitext(basename)[0]
    # Create the output file path
    output_file = f"{output_dir}/{filename_without_ext}_English.txt"
    
    write_file(output_file, translated_text)
    print(f"Translation saved to {output_file}")

if __name__ == "__main__":
    fire.Fire(translate_file)
