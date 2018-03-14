#$ -S /bin/bash
#$ -q rnd.q,prod.q,test.q,bigdata.q
#$ -cwd
#$ -V
#$ -p -50

JAVA_1_7=$1
GATK_DIR=$2
REF_GENOME=$3
KEY=$4

CORE_PATH=$5
PROJECT=$6
PREFIX=$7
BED_FILE=$8
DBSNP=$9


CMD=$JAVA_1_7'/java -jar'
CMD=$CMD' '$GATK_DIR'/GenomeAnalysisTK.jar'
CMD=$CMD' -T VariantAnnotator'
CMD=$CMD' -R '$REF_GENOME
CMD=$CMD' --variant '$CORE_PATH'/'$PROJECT'/TEMP/'$PREFIX'.'$BED_FILE'.temp.vcf'
CMD=$CMD' --dbsnp '$DBSNP
CMD=$CMD' -L '$CORE_PATH'/'$PROJECT'/TEMP/'$PREFIX'.'$BED_FILE'.temp.vcf'
CMD=$CMD' -A GCContent'
CMD=$CMD' -A VariantType'
CMD=$CMD' --disable_auto_index_creation_and_locking_when_reading_rods'
CMD=$CMD' -et NO_ET'
CMD=$CMD' -K '$KEY
CMD=$CMD' -o '$CORE_PATH'/'$PROJECT'/TEMP/AGGREGATE/'$PREFIX'.'$BED_FILE'.normal.vcf'

echo $CMD >> $CORE_PATH/$PROJECT/command_lines.txt
echo >> $CORE_PATH/$PROJECT/command_lines.txt
echo $CMD | bash
