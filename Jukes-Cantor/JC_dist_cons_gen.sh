#!/bin/bash
#SBATCH --job-name=gen_cons_jukes_cantor
#SBATCH --partition=savio2
#SBATCH --qos=savio_normal
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=24
#SBATCH --time=72:00:00
#SBATCH --mail-user=annen@berkeley.edu
#SBATCH --mail-type=ALL

###     find Jukes-Cantor distances between one reference gene and its SCOs
###         reference: guy11
###         lineages: FJ98099 (Oryza), US71 (Setaria), B71 (Triticum), LpKY97 (Lolium), MZ5-1-6 (Eleusine)

### SETUP FILES
cd /global/scratch/users/annen/JC_cons_genomes

# RUN GFFREAD: gffread-0.12.7.Linux_x86_64/gffread -g <genome_fasta> -x <coding_seqs_output_fasta> -F <gff_file>
gffread-0.12.7.Linux_x86_64/gffread -g guy11.fasta -x guy11.cds.fasta -F guy11.fungap_out.gff3 
gffread-0.12.7.Linux_x86_64/gffread -g US71.fasta -x US71.cds.fasta -F US71.fungap_out.gff3 
gffread-0.12.7.Linux_x86_64/gffread -g B71.fasta -x B71.cds.fasta -F B71.fungap_out.gff3 
gffread-0.12.7.Linux_x86_64/gffread -g LpKY97.fasta -x LpKY97.cds.fasta -F LpKY97.fungap_out.gff3 
gffread-0.12.7.Linux_x86_64/gffread -g MZ5-1-6.fasta -x MZ5-1-6.cds.fasta -F MZ5-1-6.fungap_out.gff3 

# gets one fasta entry
#awk 'BEGIN { RS=">"} /gene_00002.t1 prediction_source=maker_oryza:maker-MQOP01000001.1-augustus-gene-0.99-mRNA-1/ { print ">" substr($0, 1, length($0) - 1) }'

> SCOs.txt
while read orthogroup; do
    grep ${orthogroup} Orthogroups.txt >> SCOs.txt
    > SCOs/${orthogroup}_ref.fasta   # guy11 is reference
    > SCOs/${orthogroup}_rep.fasta   # the other representative genomes
done < SingleCopyOrthogroups.txt

cat guy11.cds.fasta | awk '/>/ { print substr($1, 2, length($1)), $2; }' > guy11.cds.list.txt
cat US71.cds.fasta | awk '/>/ { print substr($1, 2, length($1)), $2; }' > US71.cds.list.txt
cat B71.cds.fasta | awk '/>/ { print substr($1, 2, length($1)), $2; }' > B71.cds.list.txt
cat LpKY97.cds.fasta | awk '/>/ { print substr($1, 2, length($1)), $2; }' > LpKY97.cds.list.txt
cat MZ5-1-6.cds.fasta | awk '/>/ { print substr($1, 2, length($1)), $2; }' > MZ5-1-6.cds.list.txt

### make representative genome fasta (5)
while read genome; do
    while read gene; do
        GENE=$(echo ${gene} | awk 'BEGIN { FS=":" } { print $1 "_" $2 }')
        OG=$(grep "${GENE}" SCOs.txt | awk 'BEGIN { FS=":" } { print $1 }')
        if [ -n "${OG}" ]; then
            echo "$OG for $genome"
            cat ${genome}.cds.fasta | awk -v gen="${gene}" 'BEGIN { RS=">"} $0 ~ gen { print ">" substr($0, 1, length($0) - 1) }' >> SCOs/${OG}_rep.fasta
        fi
    done < ${genome}.cds.list.txt
done < ref_genomes.list.txt

### make consensus gene fasta, find distances
while read sco; do
    ### generate MSA and remove all-gap columns
    mafft SCOs/${sco}_rep.fasta > SCOs/${sco}_rep.aligned
    source activate /global/scratch/users/annen/anaconda3/envs/pfam_scan.pl
    esl-reformat --mingap -o SCOs/${sco}_rep.al.nogap afa SCOs/${sco}_rep.aligned
    conda deactivate
    echo "*** finished ${sco} MSA ***"

    ### generate consensus sequence
    cons -sequence SCOs/${sco}_rep.al.nogap -outseq SCOs/${sco}_cons.fasta -name ${sco}_cons
    echo "*** generated ${sco} consensus sequence ***"
    cat SCOs/${sco}_cons.fasta | awk '{ gsub("n", ""); print; }' > SCOs/${sco}_CONS.fasta
    echo "*** removed unknown (n) characters from consensus ***"
    
    ### use needle to align each SCO to the reference gene and find the percent identity, then compute JC dist in python
    needle -asequence SCOs/${sco}_CONS.fasta -bsequence SCOs/${sco}_rep.fasta -outfile Needle/${sco}.needle -gapopen 10.0 -gapextend 0.5
    echo "*** finished needle for ${sco} ***"
    cat Needle/${sco}.needle | awk '/# Identity:/ { print $3 }' | python /global/scratch/users/annen/KVKLab/Jukes-Cantor/genome_JC.py > JC_out/${sco}.JC.out
    echo "*** finished computing JC discances for ${sco} ***"
done < SingleCopyOrthogroups.txt

