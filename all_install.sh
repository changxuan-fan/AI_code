#!/bin/bash

start_time=$(date +%s)

# Clone the repositories
git clone -b next https://github.com/changxuan-fan/facefusion.git 
git clone https://github.com/changxuan-fan/ProPainter.git 
git clone https://github.com/changxuan-fan/Real-ESRGAN.git 
git clone https://github.com/changxuan-fan/PaddleOCR


# Update package lists and install APT packages
apt-get update -y
apt-get install -y ffmpeg mesa-va-drivers libcublaslt11 libcublas11 libcufft10 cuda-cudart-11-8 libcudnn8

# Create virtual environments
python3 -m venv /workspace/facefusion_env
python3 -m venv /workspace/propainter_env
python3 -m venv /workspace/esrgan_env
python3 -m venv /workspace/paddle_env

# Function to set up FaceFusion environment
setup_facefusion() {
  source /workspace/facefusion_env/bin/activate
  cd /workspace/facefusion
  pip install --upgrade pip
  pip install openvino==2023.1.0
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
  source /workspace/propainter_env/bin/activate
  cd /workspace/ProPainter
  pip install --upgrade pip
  pip install -r requirements.txt
  deactivate
  cd /workspace
}

# Function to set up Real-ESRGAN environment
setup_esrgan() {
  source /workspace/esrgan_env/bin/activate
  cd /workspace/Real-ESRGAN
  pip install --upgrade pip
  pip install basicsr facexlib gfpgan
  pip install -r requirements.txt
  python setup.py develop
  cp degradations.py /workspace/facefusion_env/lib/python3.10/site-packages/basicsr/data/degradations.py
  deactivate
  cd /workspace
}

# Function to set up PaddleOCR environment
setup_paddleocr() {
  source /workspace/paddle_env/bin/activate
  cd /workspace/PaddleOCR
  pip install --upgrade pip
  pip install paddlepaddle-gpu==2.6.1 -f https://www.paddlepaddle.org.cn/whl/linux/cudnnin/stable.html --no-index --no-deps
  pip install -r requirements.txt
  deactivate
  cd /workspace
}

# Run all setups sequentially
setup_facefusion &
setup_propainter &
setup_esrgan &
setup_paddleocr

wait

end_time=$(date +%s)
execution_time=$((end_time - start_time))

echo "All environments have been set up in $execution_time seconds."

