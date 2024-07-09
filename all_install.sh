#!/bin/bash

start_time=$(date +%s)

# Clone the repositories
git clone -b next https://github.com/changxuan-fan/facefusion.git 
git clone https://github.com/changxuan-fan/ProPainter.git 
git clone https://github.com/changxuan-fan/Real-ESRGAN.git 
git clone https://github.com/changxuan-fan/PaddleOCR

# Initialize conda
curl -LO https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p /workspace/miniconda3
echo -e "\n# >>> conda initialize >>>\n# !! Contents within this block are managed by 'conda init' !!\n__conda_setup=\"\$('/workspace/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)\"\nif [ \$? -eq 0 ]; then\n    eval \"\$__conda_setup\"\nelse\n    if [ -f \"/workspace/miniconda3/etc/profile.d/conda.sh\" ]; then\n        . \"/workspace/miniconda3/etc/profile.d/conda.sh\"\n    else\n        export PATH=\"/workspace/miniconda3/bin:\$PATH\"\n    fi\nfi\nunset __conda_setup\n# <<< conda initialize <<<\n" >> ~/.bashrc
source ~/.bashrc
conda update -y conda


# Create environments
conda create -y -n facefusion_env python=3.10
conda create -y -n propainter_env python=3.10
conda create -y -n esrgan_env python=3.10
conda create -y -n paddle_env python=3.10

# Update package lists and install APT packages
apt-get update -y
apt-get install -y  ffmpeg mesa-va-drivers libcublaslt11 libcublas11 libcufft10 cuda-cudart-11-8 libcudnn8

# Function to set up FaceFusion environment
setup_facefusion() {
  source ~/.bashrc
  conda init
  cd /workspace/facefusion
  conda activate facefusion_env
  conda install -y conda-forge::openvino=2023.1.0
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
  conda deactivate
  cd /workspace
}

# Function to set up ProPainter environment
setup_propainter() {
  cd /workspace/ProPainter
  conda activate propainter_env
  pip install -r requirements.txt

  conda deactivate
  cd /workspace
}

# Function to set up Real-ESRGAN environment
setup_esrgan() {
  source ~/.bashrc
  conda init
  cd /workspace/Real-ESRGAN
  conda activate esrgan_env
  pip install basicsr facexlib gfpgan &
  pip install -r requirements.txt
  python setup.py develop
  cp degradations.py /workspace/miniconda3/envs/esrgan_env/lib/python3.10/site-packages/basicsr/data/degradations.py
  conda deactivate
  cd /workspace
}

# Function to set up PaddleOCR environment
setup_paddleocr() {
  source ~/.bashrc
  conda init
  cd /workspace/PaddleOCR
  conda activate paddle_env
  pip install paddlepaddle-gpu==2.6.1 -f https://www.paddlepaddle.org.cn/whl/linux/cudnnin/stable.html --no-index --no-deps &
  pip install -r requirements.txt 
  conda deactivate
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
