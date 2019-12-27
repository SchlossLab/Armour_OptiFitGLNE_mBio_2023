#! /bin/bash
# mothurLOO.sh
# Begum Topcuoglu
# William L. Close
# Schloss Lab
# University of Michigan

##################
# Set Script Env #
##################

# Set the variables to be used in this script
FASTA=${1:?ERROR: Need to define FASTA.}
COUNT=${2:?ERROR: Need to define COUNT.}
TAXONOMY=${3:?ERROR: Need to define TAXONOMY.}
SAMPLE=${4:?ERROR: Need to define SAMPLE.}

# Other variables
OUTDIR=data/process/loo/"${SAMPLE}"/ # Output dir based on sample name to keep things separate during parallelization/organized
NPROC=$(nproc) # Setting number of processors to use based on available resources
SUBSIZE=10000 # Number of reads to subsample to, based on Baxter, et al., Genome Med, 2016


###################################################
# Generate Sequence Distances for Sample Left Out #
###################################################

# Make output dirs if they don't exist
mkdir -p "${OUTDIR}"/

# Create cluster distance file for individual sample
mothur "#get.groups(fasta="${FASTA}", count="${COUNT}", taxonomy="${TAXONOMY}",  groups="${SAMPLE}", outputdir="${OUTDIR}"/, processors="${NPROC}");
	dist.seqs(fasta=current, cutoff=0.03)"

# Renaming outputs of files generated from single sample
for FILE in $(find "${OUTDIR}"/ -regex ".*precluster.*"); do

	# Uses path and suffix of input file to rename output file using $SAMPLE and 'in' to represent the file is for
	# the individual sample only.
	REPLACEMENT=$(echo "${FILE}" | sed "s:\(.*/\).*\.\(.*\):\1"${SAMPLE}".in.\2:")

	# Rename files using new format
	mv "${FILE}" "${REPLACEMENT}"

done



#########################################
# Generate Clusters After Leave One Out #
#########################################

# Cluster all sequences while leaving out the specified sample
mothur "#remove.groups(fasta="${FASTA}", count="${COUNT}", taxonomy="${TAXONOMY}",  groups="${SAMPLE}", outputdir="${OUTDIR}"/, processors="${NPROC}");
	dist.seqs(fasta=current, cutoff=0.03);
	cluster(column=current, count=current);
	make.shared(list=current, count=current, label=0.03);
	sub.sample(shared=current, label=0.03, size="${SUBSIZE}")"

# Renaming shared files specifically
mv "${OUTDIR}"/*.opti_mcc.shared "${OUTDIR}"/"${SAMPLE}".out.opti_mcc.shared
mv "${OUTDIR}"/*.opti_mcc.0.03.subsample.shared "${OUTDIR}"/"${SAMPLE}".out.opti_mcc.0.03.subsample.shared

# Renaming outputs of files generated after leaving the specified sample out
for FILE in $(find "${OUTDIR}"/ -regex ".*precluster.*"); do

	# Uses path and suffix of input file to rename output file using $SAMPLE and 'out' to represent the file is for
	# all of the other samples after the specified sample has been left out.
	REPLACEMENT=$(echo "${FILE}" | sed "s:\(.*/\).*\.\(.*\):\1"${SAMPLE}".out.\2:")

	# Rename files using new format
	mv "${FILE}" "${REPLACEMENT}"

done
