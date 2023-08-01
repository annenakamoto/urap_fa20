#!/bin/bash
#SBATCH --job-name=clade_tree
#SBATCH --partition=savio2
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=24
#SBATCH --time=72:00:00
#SBATCH --mail-user=annen@berkeley.edu
#SBATCH --mail-type=ALL

working_dir=${1}    ## NLR_CTRL dir
species=${2}        ## Mo, Zt, Sc, or Nc
min_eco=${3}        ## was ~2/3 of the total number of accessions [adjust this first, ]
max_bl=${4}         ## was 0.5 (or 0.3 before that)
min_bl=${5}         ## was 0.05
min_bs=${6}         ## was 90

cd ${working_dir}
out_dir=TREESPLIT_OUT_${min_eco}_${max_bl}_${min_bl}_${min_bs}  ## create a unique directory for every different combination of parameters tried
mkdir -p ${out_dir}

module purge
source activate /global/scratch/users/annen/anaconda3/envs/R

### run autorefinement tree-splitting R script on each NLR clade
# ls *NLR_Clade*.fa | awk -v FS="." '{ print $2; }' | while read clade; do
#     Rscript /global/scratch/users/annen/KVKLab/fungal_srs/3.hv_analysis/autorefinement.R \
#         --working_dir ${working_dir} \
#         --tree_path CLADE_TREES/RAxML_bipartitionsBranchLabels.RAxML.${species}.${clade} \
#         --alignment_path ${species}.${clade}.afa \
#         --min_eco_overlap ${min_eco} \
#         --max_branch_length ${max_bl} \
#         --min_branch_length ${min_bl} \
#         --min_bs_support ${min_bs} \
#         --out_dir ${out_dir}
# done

### run alignment filtering script to assess #hvsites of subalignments generated by tree splitting
# mkdir -p ${out_dir}/SUBALIGNMENTS
# cp ${out_dir}/*.subali.afa ${out_dir}/SUBALIGNMENTS
# cd ${out_dir}/SUBALIGNMENTS
# Rscript /global/scratch/users/annen/KVKLab/fungal_srs/3.hv_analysis/assess_aln_cutoff_dist.R \
#     --working_dir . \
#     --MinGapFraction 0.9 \
#     --MinGapBlockWidth 3 | awk -v OFS="\t" '/.subali.afa/ { split($2,a,"."); c1 = substr(a[1],2) "." a[2]; split(c1,n,"_"); if (n[3] == n[5]) { c2 = n[1] "_" n[2] "_" n[3] } else { c2 = c1 }; if ($3 >= 10) { h = 1 } else { h = 0 }; print c1, c2, h, $3, substr($4,1,length($4)-1); }' > ${working_dir}/${out_dir}.HVSITE_RESULTS.txt

cd ${working_dir}
echo -e "DATASET_STYLE\nSEPARATOR COMMA\nDATASET_LABEL,hv genes\nCOLOR,#ffff00\nDATA" > ${out_dir}.HV_HILIGHT.iTOL.txt
> ${out_dir}.GENE_TABLE.txt
cat ${out_dir}.HVSITE_RESULTS.txt | while read line; do
    clade=$(echo ${line} | awk '{ print $2; }')
    cat ${out_dir}/SUBALIGNMENTS/${clade}.subali.afa | awk -v d=${line} '/>/ { print substr($1,2) "\t" substr(d,1,length(d)-1); }' >> ${out_dir}.GENE_TABLE.txt
    hv=$(echo ${line} | awk '{ print $3; }')
    if [ "${hv}" -eq "1" ]; then
        cat ${out_dir}/SUBALIGNMENTS/${clade}.subali.afa | awk '/>/ { print substr($1,2) ",label,node,#000000,1,normal,#fff93d"; }' >> ${out_dir}.HV_HILIGHT.iTOL.txt
    fi
done

conda deactivate

