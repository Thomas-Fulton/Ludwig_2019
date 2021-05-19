#!/bin/bash
#
#SBATCH --workdir=/nobackup/proj/clsclmr/Ludwig_2019
#SBATCH -p defq
#SBATCH -A clsclmr
#SBATCH -t 03:00:00
#

# load modules
module load Python/3.8.6-GCCcore-10.2.0;
module load SAMtools;

# Make sure you have SRA toolkit installed.
# (implement a check for SRA toolkit)
# Download and extract NCBI SRA-toolkit from GitHub: Ubuntu Lixux 64 bit archetecture version 2.11
#wget https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/2.11.0/sratoolkit.2.11.0-ubuntu64.tar.gz;
#tar -xzvf sratoolkit.2.11.0-ubuntu64.tar.gz;
#rm sratoolkit.2.11.0-ubuntu64.tar.gz;
# configure (without interactive) 
#vdb-config --restore-defaults;
# Export to shell PATH variable
export PATH=$PATH:`pwd`/sratoolkit.2.11.0-ubuntu64/bin/;

# Note that version from ubuntu repos is too out of date:
# https://ncbi.github.io/sra-tools/install_config.html

# Make directories
mkdir fastq;
mkdir bam;
mkdir pileup;
mkdir frames;
mkdir frames_examine;
mkdir reports;
mkdir nuc;
mkdir mito;
mkdir sra;


# To download the samples, you might be tempted to use fastq-dump from sra-tools.
# However, this is slow and unable to resume from broken connection.
# Better to run sra-tools prefetch first, then fastq-dump on result


     #### Use custom python script to download metadata ####
# https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE115218
# https://doi.org/10.1016/j.cell.2019.01.022

gse='GSE115218';
# parse.py gets list of SRA sequence names from GSE series of "Human lineage tracing enabled by mitochondrial mutations and single cell genomics"

# needs python3 GEOparse module - want to control what and where everything is downloaded: create virtual envirnoment "env"
python3 -m venv env;
source ./env/bin/activate;
pip install GEOparse;

# run parse.py
python3 parse.py $gse;


    #### Prefetch and fastq-dump ####
# Update the prefetch download directory by editing SRA configuration file
# Need to delete once have .fastq files.
echo '/repository/user/main/public/rt = '"\"$(pwd)/sra\"" >> $HOME/.ncbi/user-settings.mkfg;
echo '/repository/user/main/public/root = '"\"$(pwd)/sra\"" >> $HOME/.ncbi/user-settings.mkfg;


# Read sra accession names into shell array rts
#readarray -t rts < ExamplePath_sra.txt;
readarray -t rts < $gse\_sra.txt;

#vdb-dump --info

prefetch --option-file $gse\_sra.txt;
# fasterq-dump????

cd sra/sra;

for i in "${rts[@]}"
do
fastq-dump --outdir ../../fastq ${i}.sra
done

rm -rf sra;


## Download reference human genome
wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.28_GRCh38.p13/GCA_000001405.28_GRCh38.p13_genomic.fna.gz ; 
gunzip GCA_000001405.28_GRCh38.p13_genomic.fna.gz;
rm GCA_000001405.28_GRCh38.p13_genomic.fna.gz;
grep '^>' GCA_000001405.28_GRCh38.p13_genomic.fna > seqnames.txt;
#
## Split into nuclear sequences and mitochondrial sequences
python3 split_genome.py GCA_000001405.28_GRCh38.p13_genomic.fna;

# Build indices for reference sequences
# The second line takes many hours to complete...
#bowtie2-build mito/mito.fna mito/mito&
#bowtie2-build nuc/nuc.fna nuc/nuc;

#
hisat2-build mito/mito.fna mito/mito;
#hisat2-build nuc/nuc.fna nuc/nuc;


for rt in "${rts[@]}"
do

 echo ${rt};
 #echo Number of reads: $(cat fastq/${rt}.fastq|wc -l)/4|bc

 if [ -f "bam/${rt}_header.bam" ]; then
    echo "${rt} already aligned";
 else 
    echo "Aligning ${rt} to mitochondrial genome...";
    #bowtie2 -p 22 -D20 -R 10 -N 1 -L 20 -i C,1 -x mito/mito -U fastq/${rt}.fastq -S ${rt}_aligned_mito.sam
    #bowtie2 -p 22 --very-sensitive-local -x mito/mito -U fastq/${rt}.fastq -S ${rt}_aligned_mito.sam;
	#bowtie2 -p 22 --very-sensitive -x nuc/nuc -U fastq/${rt}.fastq --un fastq/${rt}_unmapped.fastq -S fastq/${rt}_tmp.sam;
	bowtie2 -p 22 --very-sensitive -x mito/mito -U fastq/${rt}_unmapped.fastq -S ${rt}_aligned_mito.sam;

    echo "Generating output files...";
    samtools view -Sb ${rt}_aligned_mito.sam -u| samtools view -h -f 0 -q 1 - >  ${rt}_unsorted.sam;
    samtools view -Sb ${rt}_unsorted.sam -u|samtools sort - bam/${rt}_header;
    #samtools view -h bam/${rt}_header.bam > ${rt}_header.sam
    samtools index bam/${rt}_header.bam bam/${rt}_header.bam;
    rm ${rt}_unsorted.sam;
    rm ${rt}_header.sam;
    rm ${rt}_aligned_mito.sam;
    #samtools mpileup -a bam/${rt}_header.bam > pileup/${rt}.pileup -f mtDNA.fa
  fi

done;


# unload modules
module purge;

# remove directory .ncbi used for sra-tools settings from user home directory


# deactivate virtual environment
deactivate;
rm -r env
