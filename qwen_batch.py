import os
import argparse
from transformers import AutoTokenizer
from vllm import LLM, SamplingParams

def main(input_folder, max_num_seqs, tensor_parallel_size):
    # Initialize the tokenizer
    tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen2-7B-Instruct")

    # Pass the default decoding hyperparameters of Qwen2-7B-Instruct
    sampling_params = SamplingParams(
        temperature=0.7,
        top_p=0.8,
        repetition_penalty=1.05,
        max_tokens=3000
    )

    # Input the model name or path. Can be GPTQ or AWQ models.
    llm = LLM(
        model="Qwen/Qwen2-72B-Instruct-GPTQ-Int4",
        quantization="gptq",
        tensor_parallel_size=tensor_parallel_size,
        gpu_memory_utilization=1,
        max_num_seqs=max_num_seqs,
    )
    
    def prepare_messages(prompt):
        instruction = (
            "Translation and Adaptation Process for Chinese Text\n\n"
            "Step 1: Initial Translation\n\n"
            "1. Understand the context of the provided audio transcription in Chinese.\n"
            "2. Ensure comprehension of the full context and correct any typos before proceeding with the translation.\n"
            "3. Translate the Chinese text into modern, simple American English.\n"
            "4. Omit any speaker tags and organize the translation into proper paragraphs.\n"
            "5. Title this translated output as 'Initial Translation'.\n\n"
            "Step 2: Colloquial Adaptation\n\n"
            "1. Make the initial translation a little bit colloquial and concise without using many abbreviations.\n"
            "2. Organize the translation into proper paragraphs.\n"
            "3. Convert any measurements to American metrics (e.g., cm to inches).\n"
            "4. Title this adapted output as 'Colloquial Translation'.\n\n"
            "Step 3: Title and SEO Optimization\n\n"
            "1. Create a humorous, captivating, controversial, concise, or exaggerated title and description for the translation.\n"
            "2. Ensure the title is no more than 5 words.\n"
            "3. Ensure the description is no more than 12 words.\n"
            "4. Provide 5 different options for both titles and descriptions.\n"
            "5. Generate 10 SEO-optimized tags suitable for platforms like TikTok and YouTube.\n\n"
            "Instructions for Processing Chinese Text\n\n"
            "You will be provided with the Chinese text.\n"
            "Complete and provide the following:\n"
            "Step 1: Initial Translation\n"
            "Step 2: Colloquial Translation\n"
            "Step 3: Titles, descriptions, and viral tags\n\n"
            "Here is the Chinese text:\n"
        )

        return [
            {
                "role": "system",
                "content": "You are a helpful assistant."
            },
            {
                "role": "user",
                "content": instruction + prompt,
            }
        ]

            
        # Read prompts from files in the input folder
        file_paths = []
        prompts = []
        for filename in os.listdir(input_folder):
            # Check if the file is not hidden and has a .txt extension
            if filename.endswith('.txt') and not filename.startswith('.'):
                filepath = os.path.join(input_folder, filename)
                with open(filepath, 'r', encoding='utf-8') as file:
                    prompt = file.read().strip()
                    prompts.append(prompt)
                    file_paths.append(filepath)

        # Prepare messages for each prompt and generate outputs
        prompt_texts = [tokenizer.apply_chat_template(prepare_messages(prompt), tokenize=False, add_generation_prompt=True) for prompt in prompts]
        outputs = llm.generate(prompt_texts, sampling_params)

        # Append the generated output to the corresponding input file
        for i, filepath in enumerate(file_paths):
            output_text = outputs[i].outputs[0].text
            with open(filepath, 'a', encoding="utf-8") as file:
                file.write("\n" + output_text)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generate text from prompts in input files and append the output to the same files.')
    parser.add_argument('-i', '--input_folder', type=str, required=True, help='Path to the input folder containing prompt files.')
    parser.add_argument('-p', '--max_num_seqs', type=int, required=True, help='Maximum number of sequences to process.')
    parser.add_argument('--cuda', type=int, required=True, help='Tensor parallel size for CUDA.')

    args = parser.parse_args()
    main(args.input_folder, args.max_num_seqs, args.cuda)
