#!/bin/sh
#SBATCH --account=xulab             # Replace ACCOUNT with your group account name
#SBATCH --job-name=HelloWorld         # The job name
#SBATCH -c 1                          # The number of cpu cores to use
#SBATCH --time=10:00                   # The time the job will take to run
#SBATCH --mem-per-cpu=5gb             # The memory the job will use per cpu core

module load julia
module load gurobi

# CLI arguments:
# 0 - If no command line arguments, default settings are run
# 1 - "strategic" if strategic bidding, "nonstrategic"  if non-strategic bidding
# 2 - ratio of strategic ES bidding (Float)
# 3 - Unit Commitment Horizon (Int)
# 4 - Economic Dispatch Horizon (Int)
# 5 - Number of simulation days (Int)
# 6 - Economic dispatch steps (Int)
# 7 - Energy Storage Segments (Int)
# 8 - Fuel Adjustment Proportion (Float)
# 9 - Error Adjustment (Float)
# 10 - Load Adjustment (Float)
# 11 - Path to data ("." if in directory)
# julia main_CLI.jl strategic 0.5 25 1 2 12 1 1.2 0.25 1.0 /insomnia001/depts/xulab/projects/STESTS/test/03082024
julia main.jl

# End of script