#$ -S /bin/bash
#$ -q rnd.q,prod.q,test.q,bigdata.q
#$ -cwd
#$ -p -50
#$ -V

TABIX_DIR=$1

CORE_PATH=$2
OUT_PROJECT=$3
SM_TAG=$4


CMD1=$TABIX_DIR'/bgzip -c '$CORE_PATH'/'$OUT_PROJECT'/VCF/RELEASE/FILTERED_ON_BAIT/'$SM_TAG'_MS_OnBait.vcf'
CMD1=$CMD1' >| '$CORE_PATH'/'$OUT_PROJECT'/VCF/RELEASE/FILTERED_ON_BAIT/'$SM_TAG'_MS_OnBait.vcf.gz'

CMD2=$TABIX_DIR'/tabix -p vcf -f '$CORE_PATH'/'$OUT_PROJECT'/VCF/RELEASE/FILTERED_ON_BAIT/'$SM_TAG'_MS_OnBait.vcf.gz'

echo $CMD1 >> $CORE_PATH/$OUT_PROJECT/command_lines.txt
echo >> $CORE_PATH/$OUT_PROJECT/command_lines.txt
echo $CMD1 | bash

echo $CMD2 >> $CORE_PATH/$OUT_PROJECT/command_lines.txt
echo >> $CORE_PATH/$OUT_PROJECT/command_lines.txt
echo $CMD2 | bash
