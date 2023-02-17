#!/bin/bash
set -x
set -e
export CUSTOM_CUDA_VERSION=11.6
cd /opt
sudo git clone https://github.com/NVIDIA/nccl.git
sudo git clone https://github.com/NVIDIA/nccl-tests.git
mv nccl-tests nccl-test
cd nccl-test
sudo make CUDA_HOME=/usr/local/cuda-${CUSTOM_CUDA_VERSION} NCCL_HOME=/opt/nccl/build
cd /opt
cp -r nccl-test /tmp/.
cd nccl
sudo git checkout inc_nsteps
sudo make -j src.build CUDA_HOME=/usr/local/cuda-${CUSTOM_CUDA_VERSION} NVCC_GENCODE='-gencode=arch=compute_70,code=sm_70 -gencode=arch=compute_75,code=sm_75 -gencode=arch=compute_80,code=sm_80'
echo -e '#!/bin/sh\nexport LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/nccl/build/lib\nexport NCCL_PROTO=simple' | sudo tee /etc/profile.d/nccl.sh
