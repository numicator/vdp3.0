module load java/jdk-13.33 python3-as-python
cd /g/data/xx92/data/vdp3.0/
source /g/data/xx92/vdp3.0/conf/environment.txt
unset PYTHONPATH
source /g/data/xx92/vdp3.0/software/miniconda3/etc/profile.d/conda.sh
conda activate gatk; conda info
python --version

for split in 01 02 03 04 05 06 07 08 09 10; do

  tsvs=""
  for f in ccg_cohort00*/run/gatk_cnv/ccg_cohort00*.tsv; do
  #for f in ccg_cohort00{01,03,05,07,09,11,13,15,17}/run/gatk_cnv/ccg_cohort00*.tsv; do
    tsvs="$tsvs -I /g/data/xx92/data/vdp3.0/$f"
  done

  echo "#!/bin/bash
#PBS -P u86
#PBS -q normal
#PBS -l walltime=48:00:00,mem=64GB,ncpus=8,jobfs=256GB
#PBS -l storage=gdata/u86+gdata/xx92
#PBS -l other=gdata
#PBS -W umask=0007
#PBS -o /g/data/xx92/data/vdp3.0/TMP_GermlineCNVCaller/GermlineCNVCaller.$split.out
#PBS -e /g/data/xx92/data/vdp3.0/TMP_GermlineCNVCaller/GermlineCNVCaller.$split.err

export MKL_NUM_THREADS=8
export OMP_NUM_THREADS=8

module load java/jdk-13.33 python3-as-python
#cd /g/data/xx92/data/vdp3.0/
source /g/data/xx92/vdp3.0/conf/environment.txt
unset PYTHONPATH
source /g/data/xx92/vdp3.0/software/miniconda3/etc/profile.d/conda.sh
conda activate gatk

#/g/data/xx92/vdp3.0/software/gatk-4.1.5.0/gatk FilterIntervals \
#--tmp-dir /g/data/xx92/data/vdp3.0/TMP_GermlineCNVCaller/tmp \
#-imr OVERLAPPING_ONLY  \
#-L /g/data/xx92/data/vdp3.0/ccg_cohort0004/run/gatk_cnv/scatter/cnv_WES.$split.interval_list \
#-L /g/data/xx92/data/vdp3.0/ccg_cohort0001/run/gatk_cnv/targets_preprocessed.interval_list \
#-O /g/data/xx92/vdp3.0/GRCh38/GATK_cnv/$interval_f \
#$tsvs

mkdir -p \$PBS_JOBFS/tmp
echo "cp -a /g/data/xx92/vdp3.0/GRCh38/GATK_cnv/ploidy_WES-calls \$PBS_JOBFS"
cp -a /g/data/xx92/vdp3.0/GRCh38/GATK_cnv/ploidy_WES-calls \$PBS_JOBFS
cd \$PBS_JOBFS
ls -l
echo

/g/data/xx92/vdp3.0/software/gatk-4.1.5.0/gatk GermlineCNVCaller \
--run-mode COHORT \
-L /g/data/xx92/data/vdp3.0/ccg_cohort0004/run/gatk_cnv/scatter/cnv_WES.$split.interval_list \
-imr OVERLAPPING_ONLY  \
--tmp-dir \$PBS_JOBFS/tmp \
--contig-ploidy-calls \$PBS_JOBFS/ploidy_WES-calls/ \
--output /g/data/xx92/vdp3.0/GRCh38/GATK_cnv/ \
--output-prefix caller_WES.$split \
$tsvs
" >/g/data/xx92/data/vdp3.0/TMP_GermlineCNVCaller/GermlineCNVCaller.$split.qsub
  
  qsub /g/data/xx92/data/vdp3.0/TMP_GermlineCNVCaller/GermlineCNVCaller.$split.qsub
done