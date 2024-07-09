import sys
import os
import cv2
import numpy as np
from paddleocr import PaddleOCR
from tqdm import tqdm
import logging

def process_images(child_input_dir, child_output_dir, child_text_file):
    ocr = PaddleOCR(use_angle_cls=True, lang='ch', use_gpu=True)
    os.makedirs(child_output_dir, exist_ok=True)
    
    all_text = []
    
    # Process each image file in the directory
    for filename in tqdm(sorted(os.listdir(child_input_dir)), desc="Processing Images"):
        if filename.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp')):
            image_path = os.path.join(child_input_dir, filename)
            image = cv2.imread(image_path)
            if image is None:
                print(f"Failed to read {image_path}")
                continue

            # Perform OCR with text orientation classification
            results = ocr.ocr(image, cls=True)
            black_image = np.zeros_like(image)
            
            if results and results != [None]: 
                recognized_text = ""
                for page in results:
                    for line in page:
                        bbox = line[0]
                        bbox = np.array(bbox).astype(np.int32)
                        cv2.fillPoly(black_image, [bbox], color=(255, 255, 255))
                        recognized_text += line[1][0] + " "

                recognized_text = recognized_text.strip()
                if recognized_text and recognized_text not in all_text:
                    all_text.append(recognized_text)

            output_path = os.path.join(child_output_dir, filename)
            cv2.imwrite(output_path, black_image)
    
    # Write all collected text to the file at once
    with open(child_text_file, 'w', encoding='utf-8') as file:
        file.write("\n".join(all_text))

def main():
    if len(sys.argv) != 3:
        print("Usage: python process_images.py <input_dir> <output_dir>")
        sys.exit(1)

    child_input_dir = sys.argv[1]
    child_output_dir = sys.argv[2]
    process_images(child_input_dir, child_output_dir)

if __name__ == "__main__":
    logging.getLogger('ppocr').setLevel(logging.ERROR)
    main()
