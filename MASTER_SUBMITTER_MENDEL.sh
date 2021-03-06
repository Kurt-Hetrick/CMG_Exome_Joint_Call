#!/bin/bash

PROJECT=$1 # The project folder that is housing all the multi-sample goods For now : M_Valle_MD_SeqWholeExome_120417_1
SAMPLE_SHEET=$2 # MS sample sheet
PREFIX=$3 # Name you want all the multi-sample files to be names
NUMBER_OF_BED_FILES=$4 # how many mini-bed files you want to scatter gather on.

# argument 4 is null then the master bed files is split into 500 bed files.

if [[ ! $NUMBER_OF_BED_FILES ]]
	then
	NUMBER_OF_BED_FILES=500
fi

############# FIXED DIRECTORIES ################

	SCRIPT_DIR="/mnt/research/tools/LINUX/00_GIT_REPO_KURT/CMG_Exome_Joint_Call/scripts"
	JAVA_1_7="/mnt/research/tools/LINUX/JAVA/jdk1.7.0_25/bin"
	# the slash at the end of core path is needed...
	CORE_PATH="/mnt/research/active/"
	GATK_DIR="/mnt/research/tools/LINUX/GATK/GenomeAnalysisTK-3.3-0"
	GATK_3_1_1_DIR="/mnt/research/tools/LINUX/GATK/GenomeAnalysisTK-3.1-1"
	GATK_DIR_NIGHTLY="/mnt/research/tools/LINUX/GATK/GenomeAnalysisTK-nightly-2015-01-15-g92376d3"
	SAMTOOLS_DIR="/mnt/research/tools/LINUX/SAMTOOLS/samtools-0.1.18"
	TABIX_DIR="/mnt/research/tools/LINUX/TABIX/tabix-0.2.6"
	CIDR_SEQSUITE_JAVA_DIR="/mnt/research/tools/LINUX/JAVA/jre1.7.0_45/bin"
	CIDR_SEQSUITE_6_1_1_DIR="/mnt/research/tools/LINUX/CIDRSEQSUITE/6.1.1"
	CIDR_SEQSUITE_4_0_JAVA='/mnt/research/tools/LINUX/JAVA/jre1.6.0_25/bin'
	CIDR_SEQSUITE_DIR_4_0='/mnt/research/tools/LINUX/CIDRSEQSUITE/Version_4_0'

############## FIXED FILE PATHS ################

	KEY="/mnt/research/tools/PIPELINE_FILES/MISC/lee.watkins_jhmi.edu.key"
	HAPMAP_VCF="/mnt/research/tools/PIPELINE_FILES/GATK_resource_bundle/2.8/b37/hapmap_3.3.b37.vcf"
	OMNI_VCF="/mnt/research/tools/PIPELINE_FILES/GATK_resource_bundle/2.8/b37/1000G_omni2.5.b37.vcf"
	ONEKG_SNPS_VCF="/mnt/research/tools/PIPELINE_FILES/GATK_resource_bundle/2.8/b37/1000G_phase1.snps.high_confidence.b37.vcf"
	DBSNP_138_VCF="/mnt/research/tools/PIPELINE_FILES/GATK_resource_bundle/2.8/b37/dbsnp_138.b37.vcf"
	ONEKG_INDELS_VCF="/mnt/research/tools/PIPELINE_FILES/GATK_resource_bundle/2.8/b37/Mills_and_1000G_gold_standard.indels.b37.vcf"
	P3_1KG="/mnt/shared_resources/public_resources/1000genomes/Full_Project/Sep_2014/20130502/ALL.wgs.phase3_shapeit2_mvncall_integrated_v5.20130502.sites.vcf.gz"
	ExAC="/mnt/shared_resources/public_resources/ExAC/Release_0.3/ExAC.r0.3.sites.vep.vcf.gz"
	KNOWN_SNPS="/mnt/research/tools/PIPELINE_FILES/GATK_resource_bundle/2.8/b37/dbsnp_138.b37.excluding_sites_after_129.vcf"
	VERACODE_CSV="/mnt/research/tools/LINUX/CIDRSEQSUITE/Veracode_hg18_hg19.csv"
	# this is a combined v4 and v4 all merged bait bed files
	MERGED_MENDEL_BED_FILE="/mnt/research/active/M_Valle_MD_SeqWholeExome_120417_1/BED_Files/BAITS_Merged_S03723314_S06588914.bed"

# other environment settings

	QUEUE_LIST=`qstat -f -s r \
		| egrep -v "^[0-9]|^-|^queue" \
		| cut -d @ -f 1 \
		| sort \
		| uniq \
		| egrep -v "bigmem.q|all.q|cgc.q|programmers.q|rhel7.q|bina.q|qtest.q" \
		| datamash collapse 1 \
		| awk '{print "-q",$1}'`

	# load gcc 5.1.0 for programs like verifyBamID
	## this will get pushed out to all of the compute nodes since I specify env var to pushed out with qsub
	module load gcc/5.1.0

	# explicitly setting this b/c not everybody has had the $HOME directory transferred and I'm not going to through
	# and figure out who does and does not have this set correctly
	umask 0007

############################################################################
################# Start of Combine Gvcf Functions ##########################
############################################################################

	# This checks to see if bed file directory and split gvcf list has been created from a previous run.
	# If so, remove them to not interfere with current run			

		if [ -d $CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT ]
			then
				rm -rf $CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT
		fi

		if [ -d $CORE_PATH/$PROJECT/TEMP/SPLIT_LIST ]
			then
				rm -rf $CORE_PATH/$PROJECT/TEMP/SPLIT_LIST
		fi

	# make the directories

		mkdir -p $CORE_PATH/$PROJECT/LOGS
		mkdir -p $CORE_PATH/$PROJECT/MULTI_SAMPLE/VARIANT_SUMMARY_STAT_VCF
		mkdir -p $CORE_PATH/$PROJECT/GVCF/AGGREGATE
		mkdir -p $CORE_PATH/$PROJECT/TEMP/{SPLIT_LIST,AGGREGATE,BED_FILE_SPLIT}

		# THIS WAS VITO'S OLD, STUFF, SUPPOSED TO CLEAR UP BED FILES, ETC ALREADY CREATED. NEED TO REVISIT
		# THERE REALLY SHOULDN'T BE ANY COLLISIONS DUE TO THE FILE PREFIX.
		# KEPT THE OUTPUT B/C OF THE REGIONS FAILING DUE TO TOO MANY ALLELES

			# mkdir -p $CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT

			# # if [ -d $CORE_PATH/$PROJECT/TEMP/AGGREGATE ]
			# # then
			# #	rm -rf $CORE_PATH/$PROJECT/TEMP/AGGREGATE
			# # fi
			# mkdir -p $CORE_PATH/$PROJECT/TEMP/AGGREGATE

# for each mendel project in the sample sheet grab the reference genome and dbsnp file

CREATE_PROJECT_INFO_ARRAY ()
{
	PROJECT_INFO_ARRAY=(`sed 's/\r//g' $SAMPLE_SHEET | sed 's/,/\t/g' | awk 'NR>1 {print $12,$18}' | sort | uniq`)

	REF_GENOME=${PROJECT_INFO_ARRAY[0]}
	PROJECT_DBSNP=${PROJECT_INFO_ARRAY[1]}
}

# get the full path of the last gvcf list file.
# take the sample sheet and create a gvcf list from that
# append the two outputs and write #line_count".samples.ReSeq.JH2027.list"

CREATE_GVCF_LIST()
{

	OLD_GVCF_LIST=$(ls -tr $CORE_PATH/$PROJECT/*.samples.ReSeq.JH2027.list | tail -n1)

	TOTAL_SAMPLES=(`(cat $OLD_GVCF_LIST ; awk 'BEGIN{FS=","} NR>1{print $1,$8}' $SAMPLE_SHEET \
		| sort \
		| uniq \
		| awk 'BEGIN{OFS="/"}{print "'$CORE_PATH'"$1,"GVCF",$2".genome.vcf"}') \
		| sort \
		| uniq \
		| wc -l`)

	(cat $OLD_GVCF_LIST ; awk 'BEGIN{FS=","} NR>1{print $1,$8}' $SAMPLE_SHEET \
		| sort \
		| uniq \
		| awk 'BEGIN{OFS="/"}{print "'$CORE_PATH'"$1,"GVCF",$2".genome.vcf"}') \
		| sort \
		| uniq \
	>| $CORE_PATH'/'$PROJECT'/'$TOTAL_SAMPLES'.samples.ReSeq.JH2027.list'

	GVCF_LIST=(`echo $CORE_PATH'/'$PROJECT'/'$TOTAL_SAMPLES'.samples.ReSeq.JH2027.list'`)

	# Take the list above and split it into groups of 300
		split -l 300 -a 4 -d $GVCF_LIST \
		$CORE_PATH/$PROJECT/TEMP/SPLIT_LIST/

	# append *list suffix to output
		ls $CORE_PATH/$PROJECT/TEMP/SPLIT_LIST/* \
			| awk '{print "mv",$0,$0".list"}' \
			| bash	
}

FORMAT_AND_SCATTER_BAIT_BED()
{
	BED_FILE_PREFIX=(`echo SPLITTED_BED_FILE_`)

	awk 1 $MERGED_MENDEL_BED_FILE \
	| sed -r 's/\r//g ; s/chr//g ; s/[[:space:]]+/\t/g' \
	>| $CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT/FORMATTED_BED_FILE.bed

	(awk '$1~/^[0-9]/' $CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT/FORMATTED_BED_FILE.bed | sort -k1,1n -k2,2n ; \
		awk '$1=="X"' $CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT/FORMATTED_BED_FILE.bed | sort -k 2,2n ; \
		awk '$1=="Y"' $CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT/FORMATTED_BED_FILE.bed | sort -k 2,2n ; \
		awk '$1=="MT"' $CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT/FORMATTED_BED_FILE.bed | sort -k 2,2n) \
	>| $CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT/FORMATTED_AND_SORTED_BED_FILE.bed

	# get a line count for the number of for the bed file above
	# divide the line count by the number of mini-bed files you want
	# if there is a remainder round up the next integer

	# this somehow sort of works, but the math ends up being off...
	# if I wanted 1000 fold scatter gather, this would actually create 997.
	# and I don't see how this actually rounds up, but it must otherwise split would not work.

	INTERVALS_DIVIDED=`wc -l $CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT/FORMATTED_AND_SORTED_BED_FILE.bed \
		| awk '{print $1 "/" "'$NUMBER_OF_BED_FILES'"}' \
		| bc \
		| awk '{print $0+1}'`

	split -l $INTERVALS_DIVIDED \
		-a 4 \
		-d \
		$CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT/FORMATTED_AND_SORTED_BED_FILE.bed \
		$CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT/$BED_FILE_PREFIX

	ls $CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT/$BED_FILE_PREFIX* \
		| awk '{print "mv",$0,$0".bed"}' \
		| bash
}



CREATE_PROJECT_INFO_ARRAY
FORMAT_AND_SCATTER_BAIT_BED
CREATE_GVCF_LIST

COMBINE_GVCF()
{
	echo \
	qsub $QUEUE_LIST \
	-N 'A01_COMBINE_GVCF_'$PROJECT'_'$PGVCF_LIST_NAME'_'$BED_FILE_NAME \
	-j y \
	-o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_A01_COMBINE_GVCF_'$PGVCF_LIST_NAME'_'$BED_FILE_NAME.log \
	$SCRIPT_DIR/A01_COMBINE_GVCF.sh \
	$JAVA_1_7 \
	$GATK_DIR \
	$REF_GENOME \
	$KEY \
	$CORE_PATH \
	$PROJECT \
	$PGVCF_LIST \
	$PREFIX \
	$BED_FILE_NAME
}

for BED_FILE in $(ls $CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT/SPLITTED_BED_FILE*);
do
	BED_FILE_NAME=$(basename $BED_FILE .bed)
		for PGVCF_LIST in $(ls $CORE_PATH/$PROJECT/TEMP/SPLIT_LIST/*list)
			do
				PGVCF_LIST_NAME=$(basename $PGVCF_LIST .list)
				COMBINE_GVCF
				echo sleep 0.1s
		done
done

############ END OF THE NEW GVCF SPLIT TO TEST #####################

	BUILD_HOLD_ID_GENOTYPE_GVCF ()
	{
		for PROJECT_A in $PROJECT;
		# yeah, so uh, this looks bad, but I just needed a way to set a new project variable that equals the multi-sample project variable.
		do
			GENOTYPE_GVCF_HOLD_ID="-hold_jid "

				for PGVCF_LIST in $(ls $CORE_PATH/$PROJECT_A/TEMP/SPLIT_LIST/*list)
					do
						PGVCF_LIST_NAME=$(basename $PGVCF_LIST .list)
						GENOTYPE_GVCF_HOLD_ID=$GENOTYPE_GVCF_HOLD_ID'A01_COMBINE_GVCF_'$PROJECT_A'_'$PGVCF_LIST_NAME'_'$BED_FILE_NAME','
				done
		done
	}

	GENOTYPE_GVCF ()
	{
		echo \
		qsub $QUEUE_LIST \
		-N B02_GENOTYPE_GVCF_$PROJECT'_'$BED_FILE_NAME \
		$GENOTYPE_GVCF_HOLD_ID \
		-j y \
		-o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_B02_GENOTYPE_GVCF_'$BED_FILE_NAME.log \
		$SCRIPT_DIR/B02_GENOTYPE_GVCF.sh \
		$JAVA_1_7 \
		$GATK_DIR \
		$REF_GENOME \
		$KEY \
		$CORE_PATH \
		$PROJECT \
		$PREFIX \
		$BED_FILE_NAME
	}

	VARIANT_ANNOTATOR()
	{
		echo \
		qsub $QUEUE_LIST \
		-N C03_VARIANT_ANNOTATOR_$PROJECT'_'$BED_FILE_NAME \
		-hold_jid B02_GENOTYPE_GVCF_$PROJECT'_'$BED_FILE_NAME \
		-j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_C03_VARIANT_ANNOTATOR_'$BED_FILE_NAME.log \
		$SCRIPT_DIR/C03_VARIANT_ANNOTATOR.sh \
		$JAVA_1_7 $GATK_DIR $REF_GENOME \
		$KEY $CORE_PATH $PROJECT \
		$PREFIX $BED_FILE_NAME $PROJECT_DBSNP
	}

	GENERATE_COMBINE_VARIANTS_HOLD_ID()
	{
	COMBINE_VARIANTS_HOLD_ID=$COMBINE_VARIANTS_HOLD_ID'C03_VARIANT_ANNOTATOR_'$PROJECT'_'$BED_FILE_NAME','
	}

for BED_FILE in $(ls $CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT/SPLITTED_BED_FILE*);
do
	BED_FILE_NAME=$(basename $BED_FILE .bed)
	BUILD_HOLD_ID_GENOTYPE_GVCF
	GENOTYPE_GVCF
	echo sleep 0.1s
	VARIANT_ANNOTATOR
	echo sleep 0.1s
	GENERATE_COMBINE_VARIANTS_HOLD_ID
done

##############################################################################
##################### End of Combine Gvcf Functions ##########################
##############################################################################

##############################################################################
################## Start of VQSR and Refinement Functions ####################
##############################################################################



COMBINE_VARIANTS(){
echo \
 qsub $QUEUE_LIST \
 -N D04_COMBINE_VARIANTS_$PROJECT \
 -hold_jid $COMBINE_VARIANTS_HOLD_ID \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_D04_COMBINE_VARIANTS.log' \
 $SCRIPT_DIR/D04_COMBINE_VARIANTS.sh \
 $JAVA_1_7 $GATK_3_1_1_DIR $REF_GENOME $KEY \
 $CORE_PATH $PROJECT $PREFIX
}

VARIANT_RECALIBRATOR_SNV() {
echo \
 qsub $QUEUE_LIST \
 -N E05A_VARIANT_RECALIBRATOR_SNV_$PROJECT \
 -hold_jid D04_COMBINE_VARIANTS_$PROJECT \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_E05A_VARIANT_RECALIBRATOR_SNV.log' \
 $SCRIPT_DIR/E05A_VARIANT_RECALIBRATOR_SNV.sh \
 $JAVA_1_7 $GATK_DIR $KEY $REF_GENOME $HAPMAP_VCF $OMNI_VCF $ONEKG_SNPS_VCF $DBSNP_138_VCF \
 $CORE_PATH $PROJECT $PREFIX
}

VARIANT_RECALIBRATOR_INDEL() {
echo \
 qsub $QUEUE_LIST \
 -N E05B_VARIANT_RECALIBRATOR_INDEL_$PROJECT \
 -hold_jid D04_COMBINE_VARIANTS_$PROJECT \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_E05B_VARIANT_RECALIBRATOR_INDEL.log' \
 $SCRIPT_DIR/E05B_VARIANT_RECALIBRATOR_INDEL.sh \
 $JAVA_1_7 $GATK_DIR $KEY $REF_GENOME $ONEKG_INDELS_VCF \
 $CORE_PATH $PROJECT $PREFIX
}

APPLY_RECALIBRATION_SNV(){
echo \
 qsub $QUEUE_LIST \
 -N F06_APPLY_RECALIBRATION_SNV_$PROJECT \
 -hold_jid E05A_VARIANT_RECALIBRATOR_SNV_$PROJECT \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_F06_APPLY_RECALIBRATION_SNV.log' \
 $SCRIPT_DIR/F06_APPLY_RECALIBRATION_SNV.sh \
 $JAVA_1_7 $GATK_DIR $KEY $REF_GENOME \
 $CORE_PATH $PROJECT $PREFIX
}

APPLY_RECALIBRATION_INDEL(){
echo \
 qsub $QUEUE_LIST \
 -N G07_APPLY_RECALIBRATION_INDEL_$PROJECT \
 -hold_jid F06_APPLY_RECALIBRATION_SNV_$PROJECT','E05B_VARIANT_RECALIBRATOR_INDEL_$PROJECT \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_G07_APPLY_RECALIBRATION_INDEL.log' \
 $SCRIPT_DIR/G07_APPLY_RECALIBRATION_INDEL.sh \
 $JAVA_1_7 $GATK_DIR $KEY $REF_GENOME \
 $CORE_PATH $PROJECT $PREFIX
}

SELECT_RARE_BIALLELIC(){
echo \
 qsub $QUEUE_LIST \
 -N H08A_SELECT_RARE_BIALLELIC_$PROJECT \
 -hold_jid G07_APPLY_RECALIBRATION_INDEL_$PROJECT \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_H08A_SELECT_RARE_BIALLELIC.log' \
 $SCRIPT_DIR/H08A_SELECT_RARE_BIALLELIC.sh \
 $JAVA_1_7 $GATK_DIR $KEY $REF_GENOME \
 $CORE_PATH $PROJECT $PREFIX
}

ANNOTATE_SELECT_RARE_BIALLELIC(){
echo \
 qsub $QUEUE_LIST \
 -N H08A-1_ANNOTATE_SELECT_RARE_BIALLELIC_$PROJECT \
 -hold_jid H08A_SELECT_RARE_BIALLELIC_$PROJECT \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_H08A-1_ANNOTATE_SELECT_RARE_BIALLELIC.log' \
 $SCRIPT_DIR/H08A-1_ANNOTATE_SELECT_RARE_BIALLELIC.sh \
 $JAVA_1_7 $GATK_DIR $KEY $REF_GENOME \
 $CORE_PATH $PROJECT $PREFIX
}

SELECT_COMMON_BIALLELIC(){
echo \
 qsub $QUEUE_LIST \
 -N H08B_SELECT_COMMON_BIALLELIC_$PROJECT \
 -hold_jid G07_APPLY_RECALIBRATION_INDEL_$PROJECT \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_H08B_SELECT_COMMON_BIALLELIC.log' \
 $SCRIPT_DIR/H08B_SELECT_COMMON_BIALLELIC.sh \
 $JAVA_1_7 $GATK_DIR $KEY $REF_GENOME \
 $CORE_PATH $PROJECT $PREFIX
}

SELECT_MULTIALLELIC(){
echo \
 qsub $QUEUE_LIST \
 -N H08C_SELECT_MULTIALLELIC_$PROJECT \
 -hold_jid G07_APPLY_RECALIBRATION_INDEL_$PROJECT \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_H08C_SELECT_MULTIALLELIC.log' \
 $SCRIPT_DIR/H08C_SELECT_MULTIALLELIC.sh \
 $JAVA_1_7 $GATK_DIR $KEY $REF_GENOME \
 $CORE_PATH $PROJECT $PREFIX
}

COMBINE_VARIANTS_VCF(){
echo \
 qsub $QUEUE_LIST \
 -N I09_COMBINE_VARIANTS_VCF_$PROJECT \
 -hold_jid H08C_SELECT_MULTIALLELIC_$PROJECT','H08B_SELECT_COMMON_BIALLELIC_$PROJECT','H08A-1_ANNOTATE_SELECT_RARE_BIALLELIC_$PROJECT \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_I09_COMBINE_VARIANTS_VCF.log' \
 $SCRIPT_DIR/I09_COMBINE_VARIANTS_VCF.sh \
 $JAVA_1_7 $GATK_3_1_1_DIR $KEY $REF_GENOME \
 $CORE_PATH $PROJECT $PREFIX
}


BGZIP_AND_TABIX_COMBINED_VCF(){
echo \
 qsub $QUEUE_LIST \
 -N I09-1_BGZIP_AND_TABIX_COMBINED_VCF_$PROJECT \
 -hold_jid I09_COMBINE_VARIANTS_VCF_$PROJECT \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_I09-1_BGZIP_AND_TABIX_COMBINED_VCF.log' \
 $SCRIPT_DIR/I09-1_BGZIP_AND_TABIX_COMBINED_VCF.sh \
 $TABIX_DIR \
 $CORE_PATH $PROJECT $PREFIX
}

############################################################################
################## End of VQSR and Refinement Functions ####################
############################################################################

############################################################################
################## Start of Vcf Splitter Functions #########################
############################################################################

CREATE_SAMPLE_INFO_ARRAY ()
{
	SAMPLE_INFO_ARRAY=(`sed 's/\r//g' $SAMPLE_SHEET | awk 'BEGIN{FS=","} NR>1 {print $1,$8,$17,$15,$18,$12}' | sed 's/,/\t/g' | sort -k 2,2 | uniq | awk '$2=="'$SAMPLE'" {print $1,$2,$3,$4,$5,$6}'`)

	PROJECT_SAMPLE=${SAMPLE_INFO_ARRAY[0]}
	SM_TAG=${SAMPLE_INFO_ARRAY[1]}
	TARGET_BED=${SAMPLE_INFO_ARRAY[2]}
	TITV_BED=${SAMPLE_INFO_ARRAY[3]}
	DBSNP=${SAMPLE_INFO_ARRAY[4]}
	SAMPLE_REF_GENOME=${SAMPLE_INFO_ARRAY[5]}

	JOB_ID_SM_TAG=$(echo $SM_TAG | sed 's/@/_/g')
}

SELECT_PASSING_VARIANTS_PER_SAMPLE(){
echo \
 qsub $QUEUE_LIST \
 -N J10A_SELECT_VARIANTS_FOR_SAMPLE_$JOB_ID_SM_TAG \
 -hold_jid I09_COMBINE_VARIANTS_VCF_$PROJECT \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_J10A_SELECT_VARIANTS_FOR_SAMPLE.log' \
 $SCRIPT_DIR/J10A_SELECT_VARIANTS_FOR_SAMPLE.sh \
 $JAVA_1_7 $GATK_DIR $KEY $SAMPLE_REF_GENOME \
 $CORE_PATH $PROJECT $SM_TAG $PREFIX $PROJECT_SAMPLE
}

BGZIP_AND_TABIX_SAMPLE_VCF()
{
echo \
 qsub $QUEUE_LIST \
 -N J10A-1_BGZIP_AND_TABIX_SAMPLE_VCF_$JOB_ID_SM_TAG \
 -hold_jid J10A_SELECT_VARIANTS_FOR_SAMPLE_$JOB_ID_SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_J10A-1_BGZIP_AND_TABIX_SAMPLE_VCF.log' \
 $SCRIPT_DIR/J10A-1_BGZIP_AND_TABIX_SAMPLE_VCF.sh \
 $TABIX_DIR \
 $CORE_PATH $PROJECT_SAMPLE $SM_TAG
}

SELECT_VARIANTS_ON_TARGET_BY_SAMPLE()
{
echo \
 qsub $QUEUE_LIST \
 -N K11A_SELECT_VARIANTS_ON_TARGET_BY_SAMPLE_$JOB_ID_SM_TAG \
 -hold_jid J10A_SELECT_VARIANTS_FOR_SAMPLE_$JOB_ID_SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_K11A_SELECT_VARIANTS_ON_TARGET_BY_SAMPLE.log' \
 $SCRIPT_DIR/K11A_SELECT_VARIANTS_ON_TARGET_BY_SAMPLE.sh \
 $JAVA_1_7 $GATK_DIR $KEY $SAMPLE_REF_GENOME \
 $CORE_PATH $PROJECT_SAMPLE $SM_TAG $TARGET_BED
}

SELECT_SNVS_ON_BAIT_BY_SAMPLE()
{
echo \
 qsub $QUEUE_LIST \
 -N K11B_SELECT_SNVS_ON_BAIT_BY_SAMPLE_$JOB_ID_SM_TAG \
 -hold_jid J10A_SELECT_VARIANTS_FOR_SAMPLE_$JOB_ID_SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_K11B_SELECT_SNVS_ON_BAIT_BY_SAMPLE.log' \
 $SCRIPT_DIR/K11B_SELECT_SNVS_ON_BAIT_BY_SAMPLE.sh \
 $JAVA_1_7 $GATK_DIR $KEY $SAMPLE_REF_GENOME \
 $CORE_PATH $PROJECT_SAMPLE $SM_TAG
}

SELECT_SNVS_ON_TARGET_BY_SAMPLE()
{
echo \
 qsub $QUEUE_LIST \
 -N K11C_SELECT_SNVS_ON_TARGET_BY_SAMPLE_$JOB_ID_SM_TAG \
 -hold_jid J10A_SELECT_VARIANTS_FOR_SAMPLE_$JOB_ID_SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_K11C_SELECT_SNVS_ON_TARGET_BY_SAMPLE.log' \
 $SCRIPT_DIR/K11C_SELECT_SNVS_ON_TARGET_BY_SAMPLE.sh \
 $JAVA_1_7 $GATK_DIR $KEY $SAMPLE_REF_GENOME \
 $CORE_PATH $PROJECT_SAMPLE $SM_TAG $TARGET_BED
}

CONCORDANCE_ON_TARGET_PER_SAMPLE()
{
echo \
 qsub $QUEUE_LIST \
 -N K11C-1_CONCORDANCE_ON_TARGET_PER_SAMPLE_$JOB_ID_SM_TAG \
 -hold_jid K11C_SELECT_SNVS_ON_TARGET_BY_SAMPLE_$JOB_ID_SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_K11C-1_CONCORDANCE_ON_TARGET_PER_SAMPLE.log' \
 $SCRIPT_DIR/K11C-1_CONCORDANCE_ON_TARGET_PER_SAMPLE.sh \
 $CIDR_SEQSUITE_JAVA_DIR $CIDR_SEQSUITE_6_1_1_DIR $VERACODE_CSV \
 $CORE_PATH $PROJECT_SAMPLE $SM_TAG $TARGET_BED
}

SELECT_INDELS_ON_BAIT_BY_SAMPLE()
{
echo \
 qsub $QUEUE_LIST \
 -N K11D_SELECT_INDELS_ON_BAIT_BY_SAMPLE_$JOB_ID_SM_TAG \
 -hold_jid J10A_SELECT_VARIANTS_FOR_SAMPLE_$JOB_ID_SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_K11D_SELECT_INDELS_ON_BAIT_BY_SAMPLE.log' \
 $SCRIPT_DIR/K11D_SELECT_INDELS_ON_BAIT_BY_SAMPLE.sh \
 $JAVA_1_7 $GATK_DIR $KEY $SAMPLE_REF_GENOME \
 $CORE_PATH $PROJECT_SAMPLE $SM_TAG
}

SELECT_INDELS_ON_TARGET_BY_SAMPLE()
{
echo \
 qsub $QUEUE_LIST \
 -N K11E_SELECT_INDELS_ON_TARGET_BY_SAMPLE_$JOB_ID_SM_TAG \
 -hold_jid J10A_SELECT_VARIANTS_FOR_SAMPLE_$JOB_ID_SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_K11E_SELECT_INDELS_ON_TARGET_BY_SAMPLE.log' \
 $SCRIPT_DIR/K11E_SELECT_INDELS_ON_TARGET_BY_SAMPLE.sh \
 $JAVA_1_7 $GATK_DIR $KEY $SAMPLE_REF_GENOME \
 $CORE_PATH $PROJECT_SAMPLE $SM_TAG $TARGET_BED
}

SELECT_SNVS_TITV_ALL()
{
echo \
 qsub $QUEUE_LIST \
 -N K11F_SELECT_SNVS_TITV_ALL_$JOB_ID_SM_TAG \
 -hold_jid J10A_SELECT_VARIANTS_FOR_SAMPLE_$JOB_ID_SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_K11F_SELECT_SNVS_TITV_ALL.log' \
 $SCRIPT_DIR/K11F_SELECT_SNVS_TITV_ALL.sh \
 $JAVA_1_7 $GATK_DIR $KEY $SAMPLE_REF_GENOME \
 $CORE_PATH $PROJECT_SAMPLE $SM_TAG $TITV_BED
}

TITV_ALL()
{
echo \
 qsub $QUEUE_LIST \
 -N K11F-1_TITV_ALL_$JOB_ID_SM_TAG \
 -hold_jid K11F_SELECT_SNVS_TITV_ALL_$JOB_ID_SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_K11F-1_TITV_ALL.log' \
 $SCRIPT_DIR/K11F-1_TITV_ALL.sh \
 $SAMTOOLS_DIR \
 $CORE_PATH $PROJECT_SAMPLE $SM_TAG
}

SELECT_SNVS_TITV_KNOWN()
{
echo \
 qsub $QUEUE_LIST \
 -N K11G_SELECT_SNVS_TITV_KNOWN_$JOB_ID_SM_TAG \
 -hold_jid J10A_SELECT_VARIANTS_FOR_SAMPLE_$JOB_ID_SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_K11G_SELECT_SNVS_TITV_KNOWN.log' \
 $SCRIPT_DIR/K11G_SELECT_SNVS_TITV_KNOWN.sh \
 $JAVA_1_7 $GATK_DIR $KEY $SAMPLE_REF_GENOME $KNOWN_SNPS \
 $CORE_PATH $PROJECT_SAMPLE $SM_TAG $TITV_BED
}

TITV_KNOWN()
{
echo \
 qsub $QUEUE_LIST \
 -N K11G-1_TITV_KNOWN_$JOB_ID_SM_TAG \
 -hold_jid K11G_SELECT_SNVS_TITV_KNOWN_$JOB_ID_SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_K11G-1_TITV_KNOWN.log' \
 $SCRIPT_DIR/K11G-1_TITV_KNOWN.sh \
 $SAMTOOLS_DIR \
 $CORE_PATH $PROJECT_SAMPLE $SM_TAG
}

SELECT_SNVS_TITV_NOVEL()
{
echo \
 qsub $QUEUE_LIST \
 -N K11H_SELECT_SNVS_TITV_NOVEL_$JOB_ID_SM_TAG \
 -hold_jid J10A_SELECT_VARIANTS_FOR_SAMPLE_$JOB_ID_SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_K11H_SELECT_SNVS_TITV_NOVEL.log' \
 $SCRIPT_DIR/K11H_SELECT_SNVS_TITV_NOVEL.sh \
 $JAVA_1_7 $GATK_DIR $KEY $SAMPLE_REF_GENOME $KNOWN_SNPS \
 $CORE_PATH $PROJECT_SAMPLE $SM_TAG $TITV_BED
}

TITV_NOVEL()
{
echo \
 qsub $QUEUE_LIST \
 -N K11H-1_TITV_NOVEL_$JOB_ID_SM_TAG \
 -hold_jid K11H_SELECT_SNVS_TITV_NOVEL_$JOB_ID_SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_K11H-1_TITV_NOVEL.log' \
 $SCRIPT_DIR/K11H-1_TITV_NOVEL.sh \
 $SAMTOOLS_DIR \
 $CORE_PATH $PROJECT_SAMPLE $SM_TAG
}

SETUP_AND_RUN_ANNOVAR()
{
echo \
 qsub $QUEUE_LIST \
 -N K11B-1_SETUP_AND_RUN_ANNOVER_$JOB_ID_SM_TAG \
 -hold_jid K11B_SELECT_SNVS_ON_BAIT_BY_SAMPLE_$JOB_ID_SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_K11B-1_SETUP_AND_RUN_ANNOVER.log' \
 -pe slots 5 \
 -R y \
 $SCRIPT_DIR/K11B-1_SETUP_AND_RUN_ANNOVER.sh \
 $PROJECT_SAMPLE $SM_TAG $CIDR_SEQSUITE_4_0_JAVA $CIDR_SEQSUITE_DIR_4_0 \
 $CORE_PATH
}

HC_BED_GENERATION()
{
echo \
 qsub $QUEUE_LIST \
 -N K11I_HC_BED_GENERATION_$SM_TAG \
 -hold_jid J10A_SELECT_VARIANTS_FOR_SAMPLE_$SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_K11I_HC_BED_GENERATION.log' \
 $SCRIPT_DIR/K11I_HC_BED_GENERATION.sh \
 $CORE_PATH $PROJECT_SAMPLE $SM_TAG
}


HC_BAM_GENERATION(){
echo \
 qsub $QUEUE_LIST \
 -N K11I-1_HC_BAM_GENERATION_$SM_TAG \
 -hold_jid K11I_HC_BED_GENERATION_$SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_K11I-1_HC_BAM_GENERATION.log' \
 $SCRIPT_DIR/K11I-1_HC_BAM_GENERATION.sh \
 $JAVA_1_7 $GATK_DIR $KEY $SAMPLE_REF_GENOME $DBSNP \
 $CORE_PATH $PROJECT_SAMPLE $SM_TAG
}

BGZIP_AND_TABIX_HC_VCF(){
echo \
 qsub $QUEUE_LIST \
 -N K11I-1-1_BGZIP_AND_TABIX_HC_VCF_$SM_TAG \
 -hold_jid K11I-1_HC_BAM_GENERATION_$SM_TAG \
 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_'$SM_TAG'_K11I-1-1_BGZIP_AND_TABIX_HC_VCF.log' \
 $SCRIPT_DIR/K11I-1-1_BGZIP_AND_TABIX_HC_VCF.sh \
 $TABIX_DIR \
 $CORE_PATH $PROJECT_SAMPLE $SM_TAG
}

GENERATE_MENDEL_HAPMAP_SAMPLE_LISTS () 
{
	HAP_MAP_SAMPLE_LIST=(`echo $CORE_PATH'/'$PROJECT'/MULTI_SAMPLE/VARIANT_SUMMARY_STAT_VCF/'$PREFIX'_hap_map_samples.list'`)
	MENDEL_SAMPLE_LIST=(`echo $CORE_PATH'/'$PROJECT'/MULTI_SAMPLE/VARIANT_SUMMARY_STAT_VCF/'$PREFIX'_mendel_samples.list'`)
	echo \
	 qsub $QUEUE_LIST \
	 -N J10_GENERATE_MENDEL_HAPMAP_SAMPLE_LISTS_$PROJECT \
 	 -hold_jid I09_COMBINE_VARIANTS_VCF_$PROJECT \
	 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_J10B_GENERATE_MENDEL_HAPMAP_SAMPLE_LISTS.log' \
	 $SCRIPT_DIR/J10_GENERATE_MENDEL_HAPMAP_SAMPLE_LISTS.sh \
	 $CORE_PATH $PROJECT $PREFIX
}


SELECT_SNVS_ALL () 
{
	echo \
	 qsub $QUEUE_LIST \
	 -N J10B_SELECT_SNPS_FOR_ALL_SAMPLES_$PROJECT \
	 -hold_jid J10_GENERATE_MENDEL_HAPMAP_SAMPLE_LISTS_$PROJECT \
	 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_J10B_SELECT_SNPS_FOR_ALL_SAMPLES.log' \
	 $SCRIPT_DIR/J10B_SELECT_ALL_SAMPLES_SNP.sh \
	 $JAVA_1_7 $GATK_DIR $KEY $REF_GENOME \
	 $CORE_PATH $PROJECT $PREFIX
}

SELECT_PASS_MENDEL_ONLY_SNP () 
{
	echo \
	 qsub $QUEUE_LIST \
	 -N J10C_SELECT_PASS_MENDEL_ONLY_SNP_$PROJECT \
	 -hold_jid J10_GENERATE_MENDEL_HAPMAP_SAMPLE_LISTS_$PROJECT \
	 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_J10C_SELECT_PASS_MENDEL_ONLY_SNP.log' \
	 $SCRIPT_DIR/J10C_SELECT_PASS_MENDEL_ONLY_SNP.sh \
	 $JAVA_1_7 $GATK_DIR $KEY $REF_GENOME \
	 $CORE_PATH $PROJECT $PREFIX $HAP_MAP_SAMPLE_LIST
}

SELECT_PASS_HAPMAP_ONLY_SNP ()
{
	echo \
	 qsub $QUEUE_LIST \
	 -N J10D_SELECT_PASS_HAPMAP_ONLY_SNP_$PROJECT \
	 -hold_jid J10_GENERATE_MENDEL_HAPMAP_SAMPLE_LISTS_$PROJECT \
	 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_J10D_SELECT_PASS_HAPMAP_ONLY_SNP.log' \
	 $SCRIPT_DIR/J10D_SELECT_PASS_HAPMAP_ONLY_SNP.sh \
	 $JAVA_1_7 $GATK_DIR $KEY $REF_GENOME \
	 $CORE_PATH $PROJECT $PREFIX $MENDEL_SAMPLE_LIST
}

SELECT_INDELS_ALL ()
{
	echo \
	 qsub $QUEUE_LIST \
	 -N J10E_SELECT_INDELS_FOR_ALL_SAMPLES_$PROJECT \
	 -hold_jid J10_GENERATE_MENDEL_HAPMAP_SAMPLE_LISTS_$PROJECT \
	 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_J10E_SELECT_INDELS_FOR_ALL_SAMPLES.log' \
	 $SCRIPT_DIR/J10E_SELECT_ALL_SAMPLES_INDELS.sh \
	 $JAVA_1_7 $GATK_DIR $KEY $REF_GENOME \
	 $CORE_PATH $PROJECT $PREFIX
}

SELECT_PASS_MENDEL_ONLY_INDELS ()
{
	echo \
	 qsub $QUEUE_LIST \
	 -N J10F_SELECT_PASS_MENDEL_ONLY_INDEL_$PROJECT \
	 -hold_jid J10_GENERATE_MENDEL_HAPMAP_SAMPLE_LISTS_$PROJECT \
	 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_J10F_SELECT_PASS_MENDEL_ONLY_INDEL.log' \
	 $SCRIPT_DIR/J10F_SELECT_PASS_MENDEL_ONLY_INDEL.sh \
	 $JAVA_1_7 $GATK_DIR $KEY $REF_GENOME \
	 $CORE_PATH $PROJECT $PREFIX $HAP_MAP_SAMPLE_LIST
}

SELECT_PASS_HAPMAP_ONLY_INDELS ()
{
	echo \
	 qsub $QUEUE_LIST \
	 -N J10G_SELECT_PASS_HAPMAP_ONLY_INDEL_$PROJECT \
	 -hold_jid J10_GENERATE_MENDEL_HAPMAP_SAMPLE_LISTS_$PROJECT \
	 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_J10G_SELECT_PASS_HAPMAP_ONLY_INDEL.log' \
	 $SCRIPT_DIR/J10G_SELECT_PASS_HAPMAP_ONLY_INDEL.sh \
	 $JAVA_1_7 $GATK_DIR $KEY $REF_GENOME \
	 $CORE_PATH $PROJECT $PREFIX $MENDEL_SAMPLE_LIST
}

SELECT_SNVS_ALL_PASS () 
{
	echo \
	 qsub $QUEUE_LIST \
	 -N J10H_SELECT_SNP_FOR_ALL_SAMPLES_PASS_$PROJECT \
	 -hold_jid J10_GENERATE_MENDEL_HAPMAP_SAMPLE_LISTS_$PROJECT \
	 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_J10H_SELECT_SNPS_FOR_ALL_SAMPLES_PASS.log' \
	 $SCRIPT_DIR/J10H_SELECT_ALL_SAMPLES_SNP_PASS.sh \
	 $JAVA_1_7 $GATK_DIR $KEY $REF_GENOME \
	 $CORE_PATH $PROJECT $PREFIX
}

SELECT_INDELS_ALL_PASS () 
{
	echo \
	 qsub $QUEUE_LIST \
	 -N J10I_SELECT_INDEL_FOR_ALL_SAMPLES_PASS_$PROJECT \
	 -hold_jid J10_GENERATE_MENDEL_HAPMAP_SAMPLE_LISTS_$PROJECT \
	 -j y -o $CORE_PATH/$PROJECT/LOGS/$PREFIX'_J10I_SELECT_INDEL_FOR_ALL_SAMPLES_PASS.log' \
	 $SCRIPT_DIR/J10I_SELECT_ALL_SAMPLES_INDEL_PASS.sh \
	 $JAVA_1_7 $GATK_DIR $KEY $REF_GENOME \
	 $CORE_PATH $PROJECT $PREFIX
}

##########################################################################
###################### End of Functions ##################################
##########################################################################


# this probably shouldn't be here
# if [ -d $CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT ]
#  then
#  	rm -rf $CORE_PATH/$PROJECT/TEMP/BED_FILE_SPLIT
# fi

COMBINE_VARIANTS
VARIANT_RECALIBRATOR_SNV
VARIANT_RECALIBRATOR_INDEL
APPLY_RECALIBRATION_SNV
APPLY_RECALIBRATION_INDEL
SELECT_RARE_BIALLELIC
ANNOTATE_SELECT_RARE_BIALLELIC
SELECT_COMMON_BIALLELIC
SELECT_MULTIALLELIC
COMBINE_VARIANTS_VCF
BGZIP_AND_TABIX_COMBINED_VCF

for SAMPLE in $(awk 'BEGIN {FS=","} NR>1 {print $8}' $SAMPLE_SHEET | sort | uniq )
do
CREATE_SAMPLE_INFO_ARRAY
SELECT_PASSING_VARIANTS_PER_SAMPLE
BGZIP_AND_TABIX_SAMPLE_VCF
SELECT_VARIANTS_ON_TARGET_BY_SAMPLE
SELECT_SNVS_ON_BAIT_BY_SAMPLE
SELECT_SNVS_ON_TARGET_BY_SAMPLE
SELECT_INDELS_ON_BAIT_BY_SAMPLE
SELECT_INDELS_ON_TARGET_BY_SAMPLE
SELECT_SNVS_TITV_ALL
TITV_ALL
SELECT_SNVS_TITV_KNOWN
TITV_KNOWN
SELECT_SNVS_TITV_NOVEL
TITV_NOVEL
HC_BED_GENERATION
HC_BAM_GENERATION
BGZIP_AND_TABIX_HC_VCF
CONCORDANCE_ON_TARGET_PER_SAMPLE
SETUP_AND_RUN_ANNOVAR
done

GENERATE_MENDEL_HAPMAP_SAMPLE_LISTS
SELECT_SNVS_ALL
SELECT_PASS_MENDEL_ONLY_SNP EXCLUDE HAP_MAP_SAMPLES
SELECT_PASS_HAPMAP_ONLY_SNP INCLUDE ONLY HAP_MAP_SAMPLES
SELECT_INDELS_ALL
SELECT_PASS_MENDEL_ONLY_INDELS EXCLUDE HAP_MAP_SAMPLES
SELECT_PASS_HAPMAP_ONLY_INDELS INCLUDE ONLY HAP_MAP_SAMPLES
SELECT_SNVS_ALL_PASS
SELECT_INDELS_ALL_PASS
