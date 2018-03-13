# ---qsub parameter settings---
# --these can be overrode at qsub invocation--

# tell sge to execute in bash
#$ -S /bin/bash

# tell sge to submit any of these queue when available
#$ -q prod.q,rnd.q,test.q,bigmem.q,bigdata.q

# tell sge that you are in the users current working directory
#$ -cwd

# tell sge to export the users environment variables
#$ -V

# tell sge to submit at this priority setting
#$ -p -50

# tell sge to output both stderr and stdout to the same file
#$ -j y

# export all variables, useful to find out what compute node the program was executed on
# redirecting stderr/stdout to file as a log.

PROJECT=$1
SM_TAG=$2
CIDR_SEQSUITE_JAVA=$3
CIDR_SEQSUITE_DIR_4_0=$4
CORE_PATH=$5


 mkdir -p $CORE_PATH/$PROJECT/TEMP/ANNOVAR_TEMP/$SM_TAG
 mkdir -p $CORE_PATH/$PROJECT/REPORTS/ANNOVAR/
 
 cp $CORE_PATH/$PROJECT/VCF/RELEASE/FILTERED_ON_BAIT/$SM_TAG* $CORE_PATH/$PROJECT/TEMP/ANNOVAR_TEMP/$SM_TAG/

$CIDR_SEQSUITE_JAVA/java \
-jar $CIDR_SEQSUITE_DIR_4_0/CIDRSeqSuite.jar \
-pipeline \
-annovar_directory_annotation $CORE_PATH/$PROJECT/TEMP/ANNOVAR_TEMP/$SM_TAG $CORE_PATH/$PROJECT/TEMP/ANNOVAR_TEMP/$SM_TAG

du -ah $CORE_PATH/$PROJECT/TEMP/ANNOVAR_TEMP/$SM_TAG | egrep "csv|txt" | awk '{print "mv -v",$2,"'$CORE_PATH'""/""'$PROJECT'""/REPORTS/ANNOVAR/"}' | bash

rm -rvf $CORE_PATH/$PROJECT/TEMP/ANNOVAR_TEMP/$SM_TAG
