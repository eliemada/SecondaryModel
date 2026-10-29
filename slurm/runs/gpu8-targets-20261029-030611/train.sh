#!/bin/bash
#SBATCH --job-name=gpu8-target-train
#SBATCH --partition=gpu
#SBATCH --qos=normal
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=01:00:00
#SBATCH --output=/scratch/izar/enbruno/SecondaryModel-gpu8/slurm/logs/gpu8-targets-20261029-030611/train-%A_%a.out
#SBATCH --error=/scratch/izar/enbruno/SecondaryModel-gpu8/slurm/logs/gpu8-targets-20261029-030611/train-%A_%a.err
#SBATCH --array=0-11%8
set -euo pipefail
cd /scratch/izar/enbruno/SecondaryModel-gpu8/src
export HF_HOME="/scratch/izar/enbruno/.cache/huggingface"
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-8}"
export KMP_DUPLICATE_LIB_OK=TRUE
export PYTHONUNBUFFERED=1
/scratch/izar/enbruno/SecondaryModel-gpu8/.venv/bin/python /scratch/izar/enbruno/SecondaryModel-gpu8/slurm/gpu8_model_reference.py verify --manifest /scratch/izar/enbruno/SecondaryModel-gpu8/slurm/logs/gpu8-targets-20261029-030611/manifest.json
/scratch/izar/enbruno/SecondaryModel-gpu8/.venv/bin/python /scratch/izar/enbruno/SecondaryModel-gpu8/slurm/gpu8_trial.py train --manifest /scratch/izar/enbruno/SecondaryModel-gpu8/slurm/logs/gpu8-targets-20261029-030611/manifest.json --task "$SLURM_ARRAY_TASK_ID"
