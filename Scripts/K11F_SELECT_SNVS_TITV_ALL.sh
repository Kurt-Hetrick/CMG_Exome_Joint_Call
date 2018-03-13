#$ -S /bin/bash
#$ -q rnd.q,prod.q,test.q,bigdata.q
#$ -cwd
#$ -p -50
#$ -V


JAVA_1_7=$1
GATK_DIR=$2
KEY=$3
REF_GENOME=$4

CORE_PATH=$5
OUT_PROJECT=$6
SM_TAG=$7
TITV_BED=$8

CMD=$JAVA_1_7'/java -jar'
CMD=$CMD' '$GATK_DIR'/GenomeAnalysisTK.jar'
CMD=$CMD' -T SelectVariants'
CMD=$CMD' --disable_auto_index_creation_and_locking_when_reading_rods'
CMD=$CMD' -et NO_ET'
CMD=$CMD' -K '$KEY
CMD=$CMD' -R '$REF_GENOME
CMD=$CMD' -ef'
CMD=$CMD' -env'
CMD=$CMD' -L '$TITV_BED
CMD=$CMD' -selectType SNP'
CMD=$CMD' --variant '$CORE_PATH'/'$OUT_PROJECT'/VCF/RELEASE/FILTERED_ON_BAIT/'$SM_TAG'_MS_OnBait.vcf'
CMD=$CMD' -o '$CORE_PATH'/'$OUT_PROJECT'/TEMP/'$SM_TAG'.Release.OnExon.FILTERED.vcf'

echo $CMD >> $CORE_PATH/$OUT_PROJECT/command_lines.txt
echo >> $CORE_PATH/$OUT_PROJECT/command_lines.txt
echo $CMD | bash
