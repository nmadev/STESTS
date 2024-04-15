#!/bin/sh

#SBATCH --account=xulab
#SBATCH --job-nam=STESTS_Run
#SBATCH -c 1
#SBATCH --time=10:00
#SBATCH --mem-per-cpu=1gb

module load julia
module load gurobi

julia main_CLI.jl strategic 0.5 25 1 2 12 1 1.2 0.25 1.0 /insomnia001/depts/xulab/projects/STESTS/test/03082024
# julia main.jl