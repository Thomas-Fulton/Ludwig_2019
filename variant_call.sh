#!/bin/bash
#SBATCH --chdir=/nobackup/proj/clsclmr/Ludwig_2019
#SBATCH -p defq
#SBATCH -A clsclmr
#SBATCH -t 06:00:00
#SBATCH -c 8
#

    ## load modules
module load Java/11.0.2; 
module load BCFtools/1.10.2-foss-2019b;

mkdir vcf/

  ## check if mutserve is installed
if [ -f "mutserve/mutserve" ]; then 
  echo "mutserve already installed";
else
  mkdir mutserve/;
  cd mutserve/;
  source ../mutserve_installer.sh;
  echo "mutserve installed";
  cd ../;
fi

  ## Variant call
# read bulk ATAC-seq from TF1 cells into array
readarray -t rts < multiQC/group_SRP149534_SRRs.txt;

for rt in "${rts[@]}"
do

  echo ${rt};

  if [ -f "vcf/${rt}_annotated.txt" ]; then
    echo "${rt} already called";
  else 
    
    # default settings: min heteroplasmy level=0.01, mapping quality=20, base quality=20, alignment quality=30
    echo "Calling variants for ${rt}...";
    ./mutserve/mutserve call bam/${rt}_sorted.bam --threads 8 --mapQ 18 --reference mutserve/rCRS.fasta --output vcf/${rt}.vcf ;
    
    echo "left aligning with bcftools";
    bcftools norm vcf/${rt}.vcf -f mutserve/rCRS.fasta --multiallelics +snps -o vcf/${rt}_normalised.vcf -O v
    
    echo "Annotating mutserve .txt output";
    ./mutserve/mutserve annotate --input vcf/${rt}.txt --annotation mutserve/rCRS_annotation_2020-08-20.txt --output vcf/${rt}_annotated.txt
  fi
done


module purge;
