#!/bin/bash

start_time=$(date +%s)

# Clone the repositories
git clone -b next https://github.com/changxuan-fan/facefusion.git 
git clone https://github.com/changxuan-fan/ProPainter.git 
git clone https://github.com/changxuan-fan/Real-ESRGAN.git 
git clone https://github.com/changxuan-fan/PaddleOCR
git clone https://github.com/changxuan-fan/demucs
git clone https://github.com/changxuan-fan/whisper-ctranslate2

# Update package lists and install APT packages
apt-get update -y
apt-get install -y ffmpeg mesa-va-drivers libcublaslt11 libcublas11 libcufft10 cuda-cudart-11-8 libcudnn8

# Create virtual environments
python3 -m venv /workspace/env/facefusion_env
python3 -m venv /workspace/env/propainter_env
python3 -m venv /workspace/env/esrgan_env
python3 -m venv /workspace/env/paddle_env
python3 -m venv /workspace/env/demucs_env
python3 -m venv /workspace/env/whisper_env
# python3 -m venv /workspace/env/llama_env
python3 -m venv /workspace/env/qwen_env


# Function to set up FaceFusion environment
setup_facefusion() {
  source /workspace/env/facefusion_env/bin/activate
  cd /workspace/facefusion
  pip install --upgrade pip
  pip install openvino==2023.1.0 &
  pip install -r requirements.txt
  python run.py &
  bg_pid=$!
  sleep 15
  wget -P .assets/models https://github.com/facefusion/facefusion-assets/releases/download/models/inswapper_128.onnx 
  wget -P .assets/models https://github.com/facefusion/facefusion-assets/releases/download/models/gfpgan_1.4.onnx 
  wget -P .assets/models https://github.com/facefusion/facefusion-assets/releases/download/models/real_esrgan_x2.onnx 
  wget -P .assets/models https://github.com/facefusion/facefusion-assets/releases/download/models/real_esrgan_x4.onnx
  rm facefusion.ini
  mv facefusion_rename.ini facefusion.ini
  sleep 120
  kill $bg_pid
  deactivate
  cd /workspace
}

# Function to set up ProPainter environment
setup_propainter() {
  source /workspace/env/propainter_env/bin/activate
  cd /workspace/ProPainter
  pip install --upgrade pip
  pip install -r requirements.txt
  deactivate
  cd /workspace
}

# Function to set up Real-ESRGAN environment
setup_esrgan() {
  source /workspace/env/esrgan_env/bin/activate
  cd /workspace/Real-ESRGAN
  pip install --upgrade pip
  pip install basicsr facexlib gfpgan &
  pip install -r requirements.txt
  pip install -e .
  cp degradations.py /workspace/env/esrgan_env/lib/python3.10/site-packages/basicsr/data/degradations.py
  cd /workspace
}

# Function to set up PaddleOCR environment
setup_paddleocr() {
  source /workspace/env/paddle_env/bin/activate
  cd /workspace/PaddleOCR
  pip install --upgrade pip
  pip install paddlepaddle-gpu==2.6.1 &
  pip install -r requirements.txt
  ln -s /usr/local/lib/python3.10/dist-packages/nvidia/cudnn/lib/libcudnn.so.8 /usr/lib/libcudnn.so
  deactivate
  cd /workspace
}

# Function to set up PaddleOCR environment
setup_demucs() {
  source /workspace/env/demucs_env/bin/activate
  pip install --upgrade pip
  pip install -U demucs
  deactivate
  cd /workspace
}

# Function to set up PaddleOCR environment
setup_whisper() {
  source /workspace/env/whisper_env/bin/activate
  pip install --upgrade pip
  pip install -U whisper-ctranslate2
  pip install torchvision
  pip install pyannote.audio
  deactivate
  cd /workspace
}

# Function to set up PaddleOCR environment
setup_qwen() {
  source /workspace/env/qwen_env/bin/activate
  pip install vLLM>=0.4.0
  deactivate
  cd /workspace
}

# Run all setups sequentially
setup_facefusion &
setup_propainter &
setup_esrgan &
setup_paddleocr & 
setup_demucs &
setup_whisper &
setup_qwen &

wait

end_time=$(date +%s)
execution_time=$((end_time - start_time))

echo "All environments have been set up in $execution_time seconds."

