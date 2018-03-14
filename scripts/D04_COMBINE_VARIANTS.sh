#$ -S /bin/bash
#$ -q rnd.q,prod.q,test.q,bigdata.q
#$ -cwd
#$ -V
#$ -p -50

JAVA_1_7=$1
shift
GATK_3_1_1_DIR=$1
shift
REF_GENOME=$1
shift
KEY=$1
shift
CORE_PATH=$1
shift
PROJECT=$1
shift
PREFIX=$1
shift

START_COMBINE_VARIANTS=`date '+%s'`

CMD=$JAVA_1_7'/java'
CMD=$CMD' -jar '$GATK_3_1_1_DIR'/GenomeAnalysisTK.jar'
CMD=$CMD' -T CombineVariants'
CMD=$CMD' -R '$REF_GENOME
CMD=$CMD' --disable_auto_index_creation_and_locking_when_reading_rods'
CMD=$CMD' -et NO_ET'
CMD=$CMD' -K '$KEY
for VCF in $(ls $CORE_PATH/$PROJECT/TEMP/AGGREGATE/$PREFIX'.SPLITTED_BED_FILE'*.vcf)
do
  CMD=$CMD' --variant '$VCF
done
CMD=$CMD' -o '$CORE_PATH'/'$PROJECT'/MULTI_SAMPLE/'$PREFIX'.raw.HC.vcf'

echo $CMD >> $CORE_PATH/$PROJECT/command_lines.txt
echo >> $CORE_PATH/$PROJECT/command_lines.txt
echo $CMD | bash

# TODO: To implement runs in about an hour compared to 3 - Has been tested and works.  Same output as before
# CMD=$JAVA_1_7'/java'
# CMD=$CMD' -cp '$GATK_3_3_DIR'/GenomeAnalysisTK.jar'
# CMD=$CMD' org.broadinstitute.gatk.tools.CatVariants'
# CMD=$CMD' -R '$REF_GENOME
# CMD=$CMD' -assumeSorted'
# for VCF in $(ls $CORE_PATH/$PROJECT/TEMP/AGGREGATE/$PREFIX'.SPLITTED_BED_FILE'*.vcf)
# do
#   CMD=$CMD' --variant '$VCF
# done
# CMD=$CMD' -out '$CORE_PATH'/'$PROJECT'/MULTI_SAMPLE/'$PREFIX'.raw.HC.vcf'
