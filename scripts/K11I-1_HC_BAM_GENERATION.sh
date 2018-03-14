#$ -S /bin/bash
#$ -q rnd.q,prod.q,test.q,bigdata.q
#$ -cwd
#$ -p -50
#$ -V


JAVA_1_7=$1
GATK_DIR=$2
KEY=$3
REF_GENOME=$4
DBSNP=$5

CORE_PATH=$6
OUT_PROJECT=$7
SM_TAG=$8

CMD=$JAVA_1_7'/java -jar'
CMD=$CMD' '$GATK_DIR'/GenomeAnalysisTK.jar'
CMD=$CMD' -T HaplotypeCaller'
CMD=$CMD' --input_file '$CORE_PATH'/'$OUT_PROJECT'/BAM/AGGREGATE/'$SM_TAG'.bam'
CMD=$CMD' --dbsnp '$DBSNP
CMD=$CMD' -L '$CORE_PATH'/'$OUT_PROJECT'/TEMP/'$SM_TAG'_MS_OnBait.vcf.bed'
CMD=$CMD' --disable_auto_index_creation_and_locking_when_reading_rods'
CMD=$CMD' -et NO_ET'
CMD=$CMD' -K '$KEY
CMD=$CMD' -R '$REF_GENOME
CMD=$CMD' -stand_call_conf 0'
CMD=$CMD' -stand_emit_conf 0'
CMD=$CMD' --bamOutput '$CORE_PATH'/'$OUT_PROJECT'/HC_BAM/'$SM_TAG'_MS_OnBait.HC.bam'
CMD=$CMD' -pairHMM VECTOR_LOGLESS_CACHING'
CMD=$CMD' -o '$CORE_PATH'/'$OUT_PROJECT'/HC_BAM/'$SM_TAG'_MS_OnBait.HC.vcf'

echo $CMD >> $CORE_PATH/$OUT_PROJECT/command_lines.txt
echo >> $CORE_PATH/$OUT_PROJECT/command_lines.txt
echo $CMD | bash
