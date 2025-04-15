set -euo pipefail

apt-get install -y python3.10-dev libpython3.10 libpython3.10-dev

uv venv
source .venv/bin/activate

uv pip install torch==2.5.1 --index-url https://download.pytorch.org/whl/cu124
uv pip install -U pip setuptools wheel packaging psutil ipython
uv pip install flash-attn --no-build-isolation -c my_pip_fix.txt
uv pip install -e . -c my_pip_fix.txt

# ------------- verl 0.3.0.post1 sglang patch -----------
uv pip install "sglang[all]>=0.4.5" --find-links https://flashinfer.ai/whl/cu124/torch2.5/flashinfer-python
uv pip install torch-memory-saver==0.0.3

# # ------------- verl 0.3.0.post1 vllm patch -----------
# # from https://github.com/hiyouga/EasyR1/blob/main/Dockerfile
# uv pip install "vllm==0.8.3" -c my_pip_fix.txt
# wget -nv https://github.com/flashinfer-ai/flashinfer/releases/download/v0.2.2.post1/flashinfer_python-0.2.2.post1+cu124torch2.6-cp38-abi3-linux_x86_64.whl && \
#     uv pip install --no-cache-dir flashinfer_python-0.2.2.post1+cu124torch2.6-cp38-abi3-linux_x86_64.whl -c my_pip_fix.txt
# torch==2.6.0
# triton==3.2.0

# ------------- Megatron --------------
uv pip install -v --disable-pip-version-check --no-cache-dir --no-build-isolation --config-settings '"--build-option=--cpp_ext"' --config-settings '"--build-option=--cuda_ext"' -c my_pip_fix.txt \
   git+https://github.com/NVIDIA/apex
pip install -c my_pip_fix.txt \
   git+https://github.com/NVIDIA/TransformerEngine.git@stable

# In China github banned
# (
#     mkdir mydeps && cd mydeps && \
#         git clone --depth 1 https://github.com/NVIDIA/apex && \
#         git clone --depth 1 --branch stable https://github.com/NVIDIA/TransformerEngine && \
#         cd TransformerEngine && git submodule update --init --recursive
# )
# uv pip install -v --disable-pip-version-check --no-cache-dir --no-build-isolation --config-settings '"--build-option=--cpp_ext"' --config-settings '"--build-option=--cuda_ext"' \
#    ./mydeps/apex
# uv pip install \
#    ./mydeps/TransformerEngine --no-build-isolation

uv pip install  -c my_pip_fix.txt megatron-core==0.11.0
