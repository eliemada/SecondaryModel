#!/bin/bash
#SBATCH --job-name=gpu8-target-report
#SBATCH --partition=gpu
#SBATCH --qos=normal
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=8G
#SBATCH --time=00:15:00
#SBATCH --output=/scratch/izar/enbruno/SecondaryModel-gpu8/slurm/logs/gpu8-targets-20261029-030611/report-%A_%a.out
#SBATCH --error=/scratch/izar/enbruno/SecondaryModel-gpu8/slurm/logs/gpu8-targets-20261029-030611/report-%A_%a.err
set -euo pipefail
cd /scratch/izar/enbruno/SecondaryModel-gpu8/src
export HF_HOME="/scratch/izar/enbruno/.cache/huggingface"
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-8}"
export KMP_DUPLICATE_LIB_OK=TRUE
export PYTHONUNBUFFERED=1
/scratch/izar/enbruno/SecondaryModel-gpu8/.venv/bin/python /scratch/izar/enbruno/SecondaryModel-gpu8/slurm/gpu8_trial.py report --manifest /scratch/izar/enbruno/SecondaryModel-gpu8/slurm/logs/gpu8-targets-20261029-030611/manifest.json
