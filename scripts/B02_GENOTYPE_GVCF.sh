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

CMD=$JAVA_1_7'/java -jar'
CMD=$CMD' '$GATK_DIR'/GenomeAnalysisTK.jar'
CMD=$CMD' -T GenotypeGVCFs'
CMD=$CMD' -R '$REF_GENOME
CMD=$CMD' --annotateNDA'
CMD=$CMD' --variant '$CORE_PATH'/'$PROJECT'/GVCF/AGGREGATE/'$PREFIX'.'$BED_FILE'.genome.vcf'
CMD=$CMD' --disable_auto_index_creation_and_locking_when_reading_rods'
CMD=$CMD' -XL 11:78516315-78516329'
CMD=$CMD' -XL 19:5787188-5787257'
CMD=$CMD' -XL 9:15623473-15623473'
CMD=$CMD' -XL 11:71932113-71932113'
CMD=$CMD' -XL 3:38355176-38355176'
CMD=$CMD' -XL 16:11537347-11537347'
CMD=$CMD' -XL 16:12297247-12297247'
CMD=$CMD' -et NO_ET'
CMD=$CMD' -K '$KEY
CMD=$CMD' -o '$CORE_PATH'/'$PROJECT'/TEMP/'$PREFIX'.'$BED_FILE'.temp.vcf'

echo $CMD >> $CORE_PATH/$PROJECT/command_lines.txt
echo >> $CORE_PATH/$PROJECT/command_lines.txt
echo $CMD | bash

echo

ls $CORE_PATH/$PROJECT/TEMP/$PREFIX"."$BED_FILE".temp.vcf.idx"
