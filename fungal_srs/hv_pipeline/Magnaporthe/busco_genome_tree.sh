#!/bin/bash
#SBATCH --job-name=busco_Mo
#SBATCH --partition=savio2
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=24
#SBATCH --time=72:00:00
#SBATCH --mail-user=annen@berkeley.edu
#SBATCH --mail-type=ALL

cd /global/scratch/users/annen/000_FUNGAL_SRS_000/MoOrthoFinder

# module purge
# echo "activating conda env..."
# source activate /global/scratch/users/annen/anaconda3/envs/BUSCO_phylogenomics
# echo "env activated"
# python ../../BUSCO_phylogenomics/BUSCO_phylogenomics.py -i MoBUSCO -o MoBUSCO_PHYLO -t ${SLURM_NTASKS} --supermatrix_only --gene_tree_program fasttree > BUSCO_phylogenomics.LOG.txt
# conda deactivate

cd /global/scratch/users/annen/000_FUNGAL_SRS_000/MoOrthoFinder/MoBUSCO_PHYLO/supermatrix/proteins
ls ${1}* | while read faa; do
    mafft --maxiterate 1000 --globalpair --thread ${SLURM_NTASKS} ${faa} > ../../../MoBUSCO_MAFFT/${faa}
done


