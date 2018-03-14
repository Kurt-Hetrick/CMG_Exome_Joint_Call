#$ -S /bin/bash
#$ -q rnd.q,prod.q,test.q,bigdata.q
#$ -cwd
#$ -p -50
#$ -V

CORE_PATH=$1
OUT_PROJECT=$2
SM_TAG=$3

grep -v "^#" $CORE_PATH/$OUT_PROJECT/VCF/RELEASE/FILTERED_ON_BAIT/$SM_TAG"_MS_OnBait.vcf" \
| awk 'BEGIN {OFS="\t"} {print $1,$2-150,$2+150}' \
>| $CORE_PATH/$OUT_PROJECT/TEMP/$SM_TAG"_MS_OnBait.vcf.bed"
