#! /bin/bash
# mothurPrecluster.sh
# William L. Close
# Begum Topcuoglu
# Schloss Lab
# University of Michigan

##################
# Set Script Env #
##################

# Set the variables to be used in this script
FILESFILE=${1:?ERROR: Need to define FILESFILE.} # File listing sample groups and sequence files
SILVAV4=${2:?ERROR: Need to define SILVAV4.}
SILVATAX=${3:?ERROR: Need to define SILVATAX.}
RDPFASTA=${4:?ERROR: Need to define RDPFASTA.}
RDPTAX=${5:?ERROR: Need to define RDPTAX.}
GGV4=${6:?ERROR: Need to define GGV4.}
GGTAX=${7:?ERROR: Need to define GGTAX.}
NPROC=${8:?ERROR: Need to define NPROC.}

# Other variables
OUTDIR=data/process/precluster/
TMP="${OUTDIR}"/tmp/

###################
# Run QC Analysis #
###################

echo PROGRESS: Creating contigs for all the samples

# Making output dir
mkdir -p "${TMP}"/

# Removing old files if they exist
if [ -n "$(ls -A "${OUTDIR}")" ]; then
	rm "${OUTDIR}"/*
fi

mothur "#make.contigs(file="${FILESFILE}", outputdir="${TMP}"/, processors="${NPROC}");
	screen.seqs(fasta=current, group=current, maxambig=0, maxlength=275, maxhomop=8);
	unique.seqs(fasta=current);
	count.seqs(name=current, group=current);
	align.seqs(fasta=current, reference="${SILVAV4}");
	screen.seqs(fasta=current, count=current, start=1968, end=11550);
	filter.seqs(fasta=current, vertical=T, trump=.);
	unique.seqs(fasta=current, count=current);
	pre.cluster(fasta=current, count=current, diffs=2);
	chimera.vsearch(fasta=current, count=current, dereplicate=T);
	remove.seqs(fasta=current, accnos=current);
	classify.seqs(fasta=current, count=current, reference="${RDPFASTA}", taxonomy="${RDPTAX}", cutoff=80);
	remove.lineage(fasta=current, count=current, taxonomy=current, taxon=Chloroplast-Mitochondria-unknown-Archaea-Eukaryota);
	dist.seqs(fasta=current,cutoff=0.03)"


# Moving and renaming important files for downstream use
mv "${TMP}"/*.precluster.pick.pick.fasta "${OUTDIR}"/glne.precluster.fasta
mv "${TMP}"/*.precluster.denovo.vsearch.pick.pick.count_table "${OUTDIR}"/glne.precluster.count_table
mv "${TMP}"/*.precluster.pick.pds.wang.pick.taxonomy "${OUTDIR}"/glne.precluster.taxonomy
mv "${TMP}"/*.precluster.pick.pick.dist "${OUTDIR}"/glne.precluster.dist


###############
# Cleaning Up #
###############

# check that output files were created then delete temp files
if [[ -f "${OUTDIR}"/glne.precluster.fasta && -f "${OUTDIR}"/glne.precluster.count_table && -f "${OUTDIR}"/glne.precluster.taxonomy && -f "${OUTDIR}"/glne.precluster.dist ]]; then
  echo PROGRESS: Cleaning up working directory.
  rm -r "${TMP}"/
else
  echo "Missing output file(s)"
  exit 0
fi
