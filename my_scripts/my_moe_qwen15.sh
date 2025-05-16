#!/usr/bin/env bash
set -euxo pipefail

# If you are using vllm<=0.6.3, you might need to set the following environment variable to avoid bugs:
# export VLLM_ATTENTION_BACKEND=XFORMERS
export CUDA_DEVICE_MAX_CONNECTIONS=1 # For megatron communication/computation overlapping

project_name='MOE'
exp_name="GRPO-Qwen15MOE_$(date '+%Y%m%d_%H%M%S')"
# Paths
RAY_DATA_HOME=${RAY_DATA_HOME:-"${HOME}/verl"}
MODEL_PATH=${MODEL_PATH:-"${RAY_DATA_HOME}/models/Qwen1.5-MoE-A2.7B-Chat"}
CKPTS_DIR=${CKPTS_DIR:-"${RAY_DATA_HOME}/ckpts/${project_name}/${exp_name}"}
TRAIN_FILE=${TRAIN_FILE:-"${RAY_DATA_HOME}/data/gsm8k/train.parquet"}
TEST_FILE=${TEST_FILE:-"${RAY_DATA_HOME}/data/gsm8k/test.parquet"}

# # 1. convert the model to mcore format
# # change the HF_MODEL_PATH and DIST_CKPT_PATH to your own path
HF_MODEL_PATH=$MODEL_PATH
DIST_CKPT_PATH="${MODEL_PATH}/gptmodel/"
python scripts/converter_hf_to_mcore.py --hf_model_path $MODEL_PATH --output_path $DIST_CKPT_PATH

# 2. run the script
NODES=4
PP=2
TP=4
CP=2
VLLM_TP=4

RAY_ADDRESS='auto' ray job submit --working-dir . -- \
    python3 -m verl.trainer.main_ppo --config-path=./config --config-name='ppo_megatron_trainer' \
    algorithm.adv_estimator=gae \
    data.train_files="$TRAIN_FILE" \
    data.val_files="$TEST_FILE" \
    data.train_batch_size=1024 \
    data.max_prompt_length=1024 \
    data.max_response_length=512 \
    data.filter_overlong_prompts=True \
    data.truncation='error' \
    actor_rollout_ref.model.path=$HF_MODEL_PATH \
    actor_rollout_ref.actor.optim.lr=1e-6 \
    actor_rollout_ref.actor.ppo_mini_batch_size=256 \
    actor_rollout_ref.actor.ppo_micro_batch_size_per_gpu=4 \
    actor_rollout_ref.actor.use_kl_loss=False \
    actor_rollout_ref.actor.megatron.tensor_model_parallel_size=$TP \
    actor_rollout_ref.actor.megatron.pipeline_model_parallel_size=$PP \
    actor_rollout_ref.actor.megatron.context_parallel_size=$CP \
    actor_rollout_ref.actor.megatron.use_dist_checkpointing=True \
    actor_rollout_ref.actor.megatron.dist_checkpointing_path=$DIST_CKPT_PATH \
    actor_rollout_ref.ref.megatron.tensor_model_parallel_size=$TP \
    actor_rollout_ref.ref.megatron.pipeline_model_parallel_size=$PP \
    actor_rollout_ref.ref.megatron.context_parallel_size=$CP \
    actor_rollout_ref.ref.megatron.use_dist_checkpointing=True \
    actor_rollout_ref.ref.megatron.dist_checkpointing_path=$DIST_CKPT_PATH \
    actor_rollout_ref.rollout.name=vllm \
    actor_rollout_ref.rollout.log_prob_micro_batch_size_per_gpu=2 \
    actor_rollout_ref.rollout.gpu_memory_utilization=0.7 \
    actor_rollout_ref.rollout.tensor_model_parallel_size=$VLLM_TP \
    critic.optim.lr=1e-5 \
    critic.model.path=$HF_MODEL_PATH \
    critic.model.enable_gradient_checkpointing=False \
    critic.ppo_micro_batch_size_per_gpu=4 \
    critic.megatron.tensor_model_parallel_size=$TP \
    critic.megatron.pipeline_model_parallel_size=$PP \
    critic.megatron.context_parallel_size=$CP \
    critic.megatron.use_dist_checkpointing=True \
    critic.megatron.dist_checkpointing_path=$DIST_CKPT_PATH \
    algorithm.use_kl_in_reward=False \
    trainer.critic_warmup=0 \
    trainer.logger=['console','wandb'] \
    trainer.project_name='verl_megatron_gsm8k_examples' \
    trainer.experiment_name='qwen1.5_moe_nochat' \
    trainer.n_gpus_per_node=8 \
    trainer.nnodes=$NODES \
    trainer.save_freq=20 \
    trainer.test_freq=5 \
    trainer.total_epochs=100 $@
