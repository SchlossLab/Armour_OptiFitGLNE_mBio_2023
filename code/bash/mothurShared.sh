#! /bin/bash
# mothurShared.sh
# William L. Close
# Schloss Lab
# University of Michigan

##################
# Set Script Env #
##################

# Set the variables to be used in this script
export SAMPLEDIR=${1:?ERROR: Need to define SAMPLEDIR.}
export FILE=${2:?ERROR: Need to define SAMPLEDIR.}
export SILVAV4=${3:?ERROR: Need to define SILVAV4.}
export RDPFASTA=${4:?ERROR: Need to define RDPFASTA.}
export RDPTAX=${5:?ERROR: Need to define RDPTAX.}

# Other variables
export OUTDIR=data/process/baxter/intermediate



###################
# Run QC Analysis #
###################

echo PROGRESS: Assembling, quality controlling, clustering, and classifying sequences.

# Making output dir
mkdir -p "${OUTDIR}"

# Convert to fasta files that will be used
for sample in data/mothur/raw/baxter/*.sra
do
	fastq-dump --split-files $sample -O data/process/baxter
done

# Making contigs from fastq.gz files, aligning reads to references, removing any non-bacterial sequences, calculating distance matrix, making shared file, and classifying OTUs
mothur "#make.contigs(file=data/process/baxter/glne007.files, outputdir="${OUTDIR}");
	screen.seqs(fasta=current, group=current, maxambig=0, maxlength=275, maxhomop=8);
	unique.seqs(fasta=current);
	count.seqs(name=current, group=current);
	align.seqs(fasta=current, reference="${SILVAV4}");
	screen.seqs(fasta=current, count=current, start=13862, end=23444, maxhomop=8);
	filter.seqs(fasta=current, vertical=T, trump=.);
	unique.seqs(fasta=current, count=current);
	pre.cluster(fasta=current, count=current, diffs=2);
	chimera.vsearch(fasta=current, count=current, dereplicate=T);
	remove.seqs(fasta=current, accnos=current);
	classify.seqs(fasta=current, count=current, reference="${RDPFASTA}", taxonomy="${RDPTAX}", cutoff=80);
	remove.lineage(fasta=current, count=current, taxonomy=current, taxon=Chloroplast-Mitochondria-unknown-Archaea-Eukaryota);
	remove.groups(fasta=current, count=current, taxonomy=current, groups=mock1-mock2-mock5-mock6-mock7)"

# Now let's extract fasta, taxonomy and count for the removed group and build subsampled shared for the removed sample.

mothur "#get.groups(groups=data/process/baxter/glne007.contigs.good.groups, fasta=data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.fasta, count=data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.denovo.vsearch.pick.pick.pick.count_table, taxonomy=data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pds.wang.pick.pick.taxonomy,  groups=2003650);
dist.seqs(fasta=current, cutoff=0.03);
cluster(column=current, count=current);
make.shared(list=current, count=current, label=0.03);
sub.sample(shared=current, label=0.03)"


# Change the name of the files generated to represent that they only have 1 SAMPLE

mv data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.dist data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.{num}.dist

mv data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.opti_mcc.list data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.opti_mcc.sample.list

mv data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.opti_mcc.steps data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.opti_mcc.sample.steps

mv data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.opti_mcc.sensspec data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.opti_mcc.sample.sensspec

mv data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.opti_mcc.shared data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.opti_mcc.sample.shared

mv data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.opti_mcc.0.03.subsample.shared data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.opti_mcc.0.03.subsample.sample.shared

mv data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pds.wang.pick.pick.pick.taxonomy data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pds.wang.pick.pick.pick.sample.taxonomy

mv data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.denovo.vsearch.pick.pick.pick.pick.count_table data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.denovo.vsearch.pick.pick.pick.pick.sample.count_table

mv data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.fasta data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.sample.fasta

# Now let's remove that 1 sample from rest of the samples by removing from original count, fasta and taxa files.

mothur "#remove.groups(groups=data/process/baxter/glne007.contigs.good.groups, fasta=data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.fasta, count=data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.denovo.vsearch.pick.pick.pick.count_table, taxonomy=data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pds.wang.pick.pick.taxonomy,  groups=2003650);
dist.seqs(fasta=current, cutoff=0.03);
cluster(column=current, count=current);
make.shared(list=current, count=current, label=0.03);
sub.sample(shared=current, label=0.03)"

# The generated subsampled file will have all the samples except the left-out-one.

# We are now ready to use OptiFit to fit left out sample to the rest.

mothur cluster.fit(fasta=data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.sample.fasta, column=data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.sample.dist, count=data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.denovo.vsearch.pick.pick.pick.pick.sample.count_table, reffasta=data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.fasta, refcolumn=data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.dist, reflist=data/process/baxter/glne007.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.pick.opti_mcc.list, method=closed)








###############
# Cleaning Up #
###############

echo PROGRESS: Cleaning up working directory.

# Making dir for storing intermediate files (can be deleted later)
mkdir -p "${OUTDIR}"/intermediate/

# Deleting unneccessary files
rm "${OUTDIR}"/*filter.unique.precluster*fasta
rm "${OUTDIR}"/*filter.unique.precluster*map
rm "${OUTDIR}"/*filter.unique.precluster*count_table

# Moving all remaining intermediate files to the intermediate dir
mv "${OUTDIR}"/stability* "${OUTDIR}"/intermediate/