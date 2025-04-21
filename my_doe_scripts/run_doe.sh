#!/usr/bin/env bash
set -euxo pipefail

project_name='GRPO'
exp_name="doe_kl1e-3_lr1e-6_$(date '+%Y%m%d_%H%M%S')"

# Paths
RAY_DATA_HOME=${RAY_DATA_HOME:-"${HOME}/verl"}
MODEL_PATH=${MODEL_PATH:-"${RAY_DATA_HOME}/models/Qwen2-7B-Instruct"}
CKPTS_DIR=${CKPTS_DIR:-"${RAY_DATA_HOME}/ckpts/${project_name}/${exp_name}"}
TRAIN_FILE=${TRAIN_FILE:-"${RAY_DATA_HOME}/data/gsm8k/train.parquet"}
TEST_FILE=${TEST_FILE:-"${RAY_DATA_HOME}/data/gsm8k/test.parquet"}

export SGL_DISABLE_TP_MEMORY_INBALANCE_CHECK=True
PYTHONUNBUFFERED=1 python3 -m my_doe_scripts.src.main_doe \
    actor_rollout_ref.actor.optim.lr=1e-6 \
    trainer.save_freq=10 \
    trainer.test_freq=5 \
    trainer.total_epochs=1500 \
    data.train_files=${TRAIN_FILE} \
    data.val_files=${TEST_FILE} \
    actor_rollout_ref.model.path="${MODEL_PATH}" \
    trainer.project_name="${project_name}" \
    trainer.experiment_name="${exp_name}" \
    trainer.default_local_dir="${CKPTS_DIR}" \
    $@ 2>&1 | tee logs/doe_$exp_name.log
