#!/usr/bin/env bash
set -xeuo pipefail
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOGFILE="logs/run_${TIMESTAMP}.log"
exec &> >(tee -a "$LOGFILE")
echo "Logging all output to: $LOGFILE"

# --- User Configs ---
NNODES=2
GPUS_PER_NODE=8
RUNTIME_ENV=${RUNTIME_ENV:-"${HOME}/myCodeLab/host/verl/my_scripts/my_deepep_env.yaml"}
# Model path (750B)
MODEL_PATH=/public/lichang93/stCodeLab/downloads/models/750B_Math84
# Eval Data
TRAIN_FILE=${RAY_DATA_HOME:-"${HOME}/myCodeLab/host/downloads"}/datasets/dapo_data/dapo-math-17k.parquet
# Output Path
OUTPUT_PATH="${HOME}/myCodeLab/host/verl/eval_results/750B_train_acc1.parquet"

# --- Key Distributed Settings ---
# TP=16 ensures 750B fits (cross-node inference)
gen_tp=16
# Acc@1
n_samples=1

# --- Ray Submission ---
RAY_ADDRESS='auto' ray job submit \
    --runtime-env="${RUNTIME_ENV}" \
    -- \
    python3 -m verl.trainer.main_generation_server \
    --config-path=config \
    --config-name='ppo_trainer.yaml' \
    data.train_files="${TRAIN_FILE}" \
    +data.output_path="${OUTPUT_PATH}" \
    data.prompt_key=prompt \
    data.max_prompt_length=4096 \
    data.max_response_length=10240 \
    actor_rollout_ref.model.path="${MODEL_PATH}" \
    actor_rollout_ref.rollout.name=vllm \
    actor_rollout_ref.rollout.tensor_model_parallel_size=${gen_tp} \
    actor_rollout_ref.rollout.gpu_memory_utilization=0.90 \
    actor_rollout_ref.rollout.n=${n_samples} \
    actor_rollout_ref.rollout.temperature=0.6 \
    actor_rollout_ref.rollout.top_p=0.8 \
    actor_rollout_ref.rollout.top_k=0.95 \
    actor_rollout_ref.rollout.response_length=10240 \
    trainer.nnodes=${NNODES} \
    trainer.n_gpus_per_node=${GPUS_PER_NODE} \
    reward_model.reward_manager=dapo \
    trainer.ray_wait_register_center_timeout=7200 \
    actor_rollout_ref.nccl_timeout=7200 \
    +reward_model.reward_kwargs.max_resp_len=10240
