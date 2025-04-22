#!/usr/bin/env bash
set -euxo pipefail

project_name='GRPO'
exp_name="ppo_aime_kl1e-3_lr1e-6_$(date '+%Y%m%d_%H%M%S')"
VERL_PPO_LOGGING_LEVEL='DEBUG'

# Paths
RAY_DATA_HOME=${RAY_DATA_HOME:-"${HOME}/verl"}
MODEL_PATH=${MODEL_PATH:-"${RAY_DATA_HOME}/models/Qwen2-7B-Instruct"}
CKPTS_DIR=${CKPTS_DIR:-"${RAY_DATA_HOME}/ckpts/${project_name}/${exp_name}"}
TRAIN_FILE=${TRAIN_FILE:-"${RAY_DATA_HOME}/data/dapo-math-17k.parquet"}
TEST_FILE=${TEST_FILE:-"${RAY_DATA_HOME}/data/aime-2024.parquet"}

train_prompt_bsz=64
gen_prompt_bsz=$((train_prompt_bsz * 2))
n_resp_per_prompt=16
train_prompt_mini_bsz=32

max_prompt_length=$((1024 * 2))
max_response_length=$((1024 * 20))
actor_ppo_max_token_len=$((max_prompt_length + max_response_length))
infer_ppo_max_token_len=$((max_prompt_length + max_response_length))
sp_size=4
offload=True

export HYDRA_FULL_ERROR=1
export SGL_DISABLE_TP_MEMORY_INBALANCE_CHECK=True
PYTHONUNBUFFERED=1 python3 -m verl.trainer.main_ppo \
    actor_rollout_ref.actor.optim.lr=1e-6 \
    actor_rollout_ref.rollout.n=${n_resp_per_prompt} \
    trainer.save_freq=10 \
    trainer.test_freq=5 \
    trainer.total_epochs=1500 \
    data.train_files=${TRAIN_FILE} \
    data.val_files=${TEST_FILE} \
    +data.gen_batch_size=${gen_prompt_bsz} \
    data.train_batch_size=${train_prompt_bsz} \
    data.max_prompt_length=${max_prompt_length} \
    data.max_response_length=${max_response_length} \
    actor_rollout_ref.model.path="${MODEL_PATH}" \
    actor_rollout_ref.actor.ppo_mini_batch_size=${train_prompt_mini_bsz} \
    actor_rollout_ref.actor.ppo_max_token_len_per_gpu=${actor_ppo_max_token_len} \
    actor_rollout_ref.ref.log_prob_max_token_len_per_gpu=${infer_ppo_max_token_len} \
    actor_rollout_ref.rollout.log_prob_max_token_len_per_gpu=${infer_ppo_max_token_len} \
    actor_rollout_ref.actor.ulysses_sequence_parallel_size=${sp_size} \
    actor_rollout_ref.actor.fsdp_config.param_offload=${offload} \
    actor_rollout_ref.actor.fsdp_config.optimizer_offload=${offload} \
    actor_rollout_ref.ref.fsdp_config.param_offload=${offload} \
    trainer.project_name="${project_name}" \
    trainer.experiment_name="${exp_name}" \
    trainer.default_local_dir="${CKPTS_DIR}" \
    $@ 2>&1 | tee logs/doe_$exp_name.log
