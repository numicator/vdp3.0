module load java/jdk-13.33 python3-as-python
cd /g/data/xx92/data/vdp3.0/
source /g/data/xx92/vdp3.0/conf/environment.txt
unset PYTHONPATH
source /g/data/xx92/vdp3.0/software/miniconda3/etc/profile.d/conda.sh
conda activate gatk; conda info
python --version

for split in 01 02 03 04 05 06 07 08 09 10; do
  if [ "$split" == "01" ]; then interval="1_21"; fi
  if [ "$split" == "02" ]; then interval="2_18"; fi
  if [ "$split" == "03" ]; then interval="3_14"; fi
  if [ "$split" == "04" ]; then interval="4_15_M"; fi
  if [ "$split" == "05" ]; then interval="5_13_Y"; fi
  if [ "$split" == "06" ]; then interval="6_9"; fi
  if [ "$split" == "07" ]; then interval="7_10"; fi
  if [ "$split" == "08" ]; then interval="8_11"; fi
  if [ "$split" == "09" ]; then interval="12_22_X_Un"; fi
  if [ "$split" == "10" ]; then interval="16_17_19_20"; fi
  interval_f="${interval}_filtered.interval_list"
  interval="$interval.interval_list"
  echo "doing split: $split interval: $interval"

  tsvs=""
  for f in ccg_cohort00*/run/gatk_cnv/ccg_cohort00*.tsv; do
    tsvs="$tsvs -I $f"
  done

  echo "
#!/bin/bash
#PBS -P u86
#PBS -q normal
#PBS -l walltime=48:00:00,mem=32GB,ncpus=8,jobfs=100GB
#PBS -l storage=gdata/u86+gdata/xx92
#PBS -l other=gdata
#PBS -W umask=0007
#PBS -o /g/data/xx92/data/vdp3.0/TMP_GermlineCNVCaller/GermlineCNVCaller.$split.out
#PBS -e /g/data/xx92/data/vdp3.0/TMP_GermlineCNVCaller/.GermlineCNVCaller$split.err

module load java/jdk-13.33 python3-as-python
cd /g/data/xx92/data/vdp3.0/
source /g/data/xx92/vdp3.0/conf/environment.txt
unset PYTHONPATH
source /g/data/xx92/vdp3.0/software/miniconda3/etc/profile.d/conda.sh
conda activate gatk

/g/data/xx92/vdp3.0/software/gatk-4.1.5.0/gatk FilterIntervals \
--tmp-dir /g/data/xx92/data/vdp3.0/TMP_GermlineCNVCaller/tmp \
-imr OVERLAPPING_ONLY  \
-L /g/data/xx92/vdp3.0/GRCh38/splits/$interval \
-L /g/data/xx92/data/vdp3.0/ccg_cohort0001/run/gatk_cnv/targets_preprocessed.interval_list \
-O /g/data/xx92/vdp3.0/GRCh38/GATK_cnv/$interval_f \
$tsvs

/g/data/xx92/vdp3.0/software/gatk-4.1.5.0/gatk GermlineCNVCaller \
--run-mode COHORT \
-L /g/data/xx92/vdp3.0/GRCh38/GATK_cnv/$interval_f \
-imr OVERLAPPING_ONLY  \
--tmp-dir /g/data/xx92/data/vdp3.0/TMP_GermlineCNVCaller/tmp \
--contig-ploidy-calls /g/data/xx92/vdp3.0/GRCh38/GATK_cnv/ploidy_WES-calls/ \
--output /g/data/xx92/vdp3.0/GRCh38/GATK_cnv/ \
--output-prefix caller_WES.$split \
$tsvs
" >/g/data/xx92/data/vdp3.0/TMP_GermlineCNVCaller/GermlineCNVCaller.$split.qsub
  
  qsub /g/data/xx92/data/vdp3.0/TMP_GermlineCNVCaller/GermlineCNVCaller.$split.qsub
done
