#$ -S /bin/bash
#$ -q rnd.q,prod.q,test.q,bigdata.q
#$ -cwd
#$ -p -50
#$ -V

SAMTOOLS_DIR=$1

CORE_PATH=$2
OUT_PROJECT=$3
SM_TAG=$4

CMD=$SAMTOOLS_DIR'/bcftools/vcfutils.pl qstats '$CORE_PATH'/'$OUT_PROJECT'/TEMP/'$SM_TAG'.Release.Novel.TiTv.vcf'
CMD=$CMD' >| '$CORE_PATH'/'$OUT_PROJECT'/REPORTS/TI_TV_MS/'$SM_TAG'_Novel_.titv.txt'

echo $CMD >> $CORE_PATH/$OUT_PROJECT/command_lines.txt
echo >> $CORE_PATH/$OUT_PROJECT/command_lines.txt
echo $CMD | bash
