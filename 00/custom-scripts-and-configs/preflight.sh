#!/bin/bash
set -euxo pipefail

###########
###########
# GPU check
N_GPUS=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader | wc -l)
if [ ${N_GPUS} -eq 0 ]; then 
        echo "GPUs not present or no supported! nvidia-smi command failed.";
        exit 1
fi
echo "Number of GPUs: ${N_GPUS}"
nvidia-smi
nvcc -V
/tmp/nccl-tests/build/all_reduce_perf -b 8 -e 128M -f 2 -g ${N_GPUS}
echo "system GPU dependency check passed"

###########
###########
# EFA check
if [ $(fi_info -p efa -t FI_EP_RDM | grep 'provider: efa' | wc -l) -eq 0 ]; then
        echo "EFA or it's dependencies (libfabric) not avaialble"
fi

fi_info -p efa -t FI_EP_RDM
echo "Number of EFA: $(fi_info -p efa -t FI_EP_RDM | grep 'provider: efa' | wc -l)"
export FI_PROVIDER=efa
export NCCL_DEBUG=info
NCCL_LOG=nccl_test.log
/tmp/nccl-tests/build/all_reduce_perf -b 8 -e 128M -f 2 -g ${N_GPUS} > ${NCCL_LOG}
echo "NCCL test dependencies used: $(grep 'NCCL version' ${NCCL_LOG})"
if [[ $(grep -q "NCCL INFO NET/OFI Selected Provider is efa" ${NCCL_LOG} ) -eq 0  && $(grep -q "NCCL INFO Using network AWS Libfabric" ${NCCL_LOG} ) -eq 0 ]]; then
    echo "NCCL tests used EFA";
else
    echo "ERROR: NCCL tests are not detecting and using EFA!"
    exit 1
fi
echo "See EFA backed NCCL test results in ${NCCL_LOG}"

################
################
# PyTorch checks
${1:-python3} -c "import torch;print('CUDA version:', torch.version.cuda, '\n', 'cuDNN version:', torch.backends.cudnn.version(), '\n',  'NCCL version:', torch.cuda.nccl.version())"
cat << 'EOF' > run.py
import sys
import torch
import torch.distributed as dist
import torch.nn as nn
import torch.optim as optim
from torch.nn.parallel import DistributedDataParallel as DDP
class ToyModel(nn.Module):
    def __init__(self):
        super(ToyModel, self).__init__()
        self.net1 = nn.Linear(10, 10)
        self.relu = nn.ReLU()
        self.net2 = nn.Linear(10, 5)
    def forward(self, x):
        return self.net2(self.relu(self.net1(x)))
def demo_basic():
    if sys.argv[1] == "ddp":
        dist.init_process_group("nccl")
        rank = dist.get_rank()
        print(f"Start running basic DDP example on rank {rank}.")
        device_id = f"cuda:{rank % torch.cuda.device_count()}"
        model = ToyModel().to(device_id)
        ddp_model = DDP(model, device_ids=[device_id])
    elif sys.argv[1] == "local":
        device_id = "cuda:0"
        model = ToyModel().to(device_id)
        pass
    else:
        raise RuntimeError("Unknown mode.")
    loss_fn = nn.MSELoss()
    optimizer = optim.SGD(model.parameters(), lr=0.001)
    for i in range(1000):
        if i % 100 == 0:
            msg = f"step: {i}"
            if sys.argv[1] == "ddp":
                print(f"device_id: {device_id}, {msg}")
            print(msg)
        optimizer.zero_grad()
        outputs = model(torch.randn(20, 10).to(device_id))
        labels = torch.randn(20, 5).to(device_id)
        loss_fn(outputs, labels).backward()
        optimizer.step()
if __name__ == "__main__":
    demo_basic()
EOF
${1:-python3} run.py local
TRAINING_LOG=training.log
${1:-python3} -m torch.distributed.run --standalone --nnodes=1 --nproc_per_node=${N_GPUS} run.py ddp > ${TRAINING_LOG}
echo "NCCL and CUDA dependencies used for distributed training: $(grep 'NCCL version' ${NCCL_LOG})"
echo "See full distributed training log in ${TRAINING_LOG}"
