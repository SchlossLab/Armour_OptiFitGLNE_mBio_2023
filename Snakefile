# Snakefile
# Courtney R Armour
# William L. Close
# Begum Topcuoglu
# Schloss Lab
# University of Michigan

# Purpose: Snakemake file for running mothur 16S pipeline with
# OptiFit/OptiClust and comparing prediction performance

# Code for creating list of sample and sequence names after filtering out names of mock samples (not used in this study)
import pandas as pd
import re
data = pd.read_csv("data/metadata/SraRunTable.txt")
names = data["Sample Name"].tolist()
regex = re.compile(r'\d+')
sampleNames = set([i for i in names if regex.match(i)])
sequenceNames = set(data[data["Sample Name"].isin(sampleNames)]["Run"].tolist())

alogrithmNames = ['optifit','opticlust']
split_nums = range(1,101) # number of test/train splits to make
#split_nums = range(0,1)
#split_nums = range(1,21)

# Master rule for controlling workflow. Cleans up mothur log files when complete.
rule all:
    input:
        # "data/process/opticlust/split_1/train/glne.precluster.opti_mcc.0.03.subsample.0.03.pick.shared",
        # "data/process/opticlust/split_1/test/glne.precluster.pick.renamed.fit.optifit_mcc.0.03.subsample.shared",
        #"data/process/optifit/split_1/train/glne.precluster.pick.opti_mcc.0.03.subsample.shared",
        #"data/process/optifit/split_1/test/glne.precluster.pick.renamed.fit.optifit_mcc.shared",
        #"data/learning/results/opticlust/preproc_test_split_1.csv",
        #"data/learning/results/optifit/preproc_test_split_1.csv",
        #"data/learning/results/opticlust/cv_results_split_1.csv",
        #"data/learning/results/optifit/cv_results_split_1.csv",
        #"data/learning/results/opticlust/performance_split_1.csv",
        #"data/learning/results/optifit/performance_split_1.csv",
        # expand("data/process/optifit/split_{num}/test/glne.precluster.pick.renamed.fit.optifit_mcc.shared",
        #        num = split_nums)
        expand("data/learning/results/opticlust/prediction_results_split_{num}.csv",
              num = split_nums),
        expand("data/learning/results/optifit/prediction_results_split_{num}.csv",
               num = split_nums)        
    shell:
        '''
        if $(ls | grep -q "mothur.*logfile"); then
            mkdir -p logs/mothur/
            mv mothur*logfile logs/mothur/
        fi
        '''

rule results:
    input:
        #"results/tables/fraction_reads_mapped.tsv",
        "data/learning/summary/merged_predictions.csv",
        "data/learning/summary/merged_performance.csv",
        "data/learning/summary/merged_HP.csv",
        "data/learning/summary/merged_MCC.csv",
        "data/learning/summary/all_sens_spec.csv",
        "results/tables/pct_class_correct.csv",
        "results/tables/fracNonMapped.csv",
        "results/tables/pvalues.csv",
        "results/tables/splitTogetherFrequency.csv"
        #"results/tables/opticlust_20_mcc.csv"
        
rule plots: 
    input:
        "results/figures/view_splits.png",
        "results/figures/hp_performance.png",
        "results/figures/avg_auroc.png",
        "results/figures/avg_roc.png"

rule submission:
    input:
        "submission/figures/fig2.png"
        
##################################################################
#
# Part 1: Download Data
#
##################################################################

# Download 16S SRA sequences from SRP062005.
rule getSRASequences:
    input:
        script="code/bash/getSRAFiles.sh"
    params:
        sequence="{sequence}"
    output:
        read1="data/raw/{sequence}_1.fastq.gz",
        read2="data/raw/{sequence}_2.fastq.gz"
    resources:
        time_min=45
    shell:
        "bash {input.script} {params.sequence}"

# Retrieve tidied metadata from https://github.com/SchlossLab/Baxter_glne007Modeling_GenomeMed_2015
rule getMetadata:
    input:
        script="code/bash/getMetadata.sh"
    output:
        metadata="data/metadata/metadata.tsv"
    shell:
        "bash {input.script}"


# Downloading and formatting mothur SILVA and RDP reference databases. The v4 region is extracted from
# SILVA database for use as reference alignment.
rule get16SReferences:
    input:
        script="code/bash/mothurReferences.sh"
    output:
        silvaV4="data/references/silva.v4.align",
        rdpFasta="data/references/trainset16_022016.pds.fasta",
        rdpTax="data/references/trainset16_022016.pds.tax"
    resources:  
        ncores=4
    shell:
        "bash {input.script} {resources.ncores}"

##################################################################
#
# Part 2: Running Mothur
#
##################################################################

# Using SRA Run Selector RunInfo table to create mothur files file.
rule makeFilesFile:
    input:
        script="code/R/makeFilesFile.R",
        sra="data/metadata/SraRunTable.txt", # Output from https://trace.ncbi.nlm.nih.gov/Traces/study/?acc=SRP062005&o=acc_s%3Aa RunInfo
        sequences=expand(rules.getSRASequences.output,
            sequence = sequenceNames)
    output:
        files="data/process/glne.files"
    shell:
        "Rscript {input.script} {input.sra} {input.sequences}"

# Preclustering and preparing sequences for leave one out analysis.
rule preclusterSequences:
    input:
        script="code/bash/mothurPrecluster.sh",
        files=rules.makeFilesFile.output.files,
        refs=rules.get16SReferences.output
    output:
        fasta="data/process/precluster/glne.precluster.fasta",
        count_table="data/process/precluster/glne.precluster.count_table",
        tax="data/process/precluster/glne.precluster.taxonomy",
        dist="data/process/precluster/glne.precluster.dist"
    resources:
        ncores=12,
        time_min=500,
        mem_mb=10000
    shell:
        "bash {input.script} {input.files} {input.refs} {resources.ncores}"

##################################################################
#
# Part 3: Cluster OptiClust
#
##################################################################

# Creating subsampled shared file using all of the samples and OptiClust.
rule clusterOptiClust:
    input:
        script="code/bash/mothurOptiClust.sh",
        precluster=rules.preclusterSequences.output
    output:
        shared="data/process/opticlust/shared/glne.precluster.opti_mcc.0.03.subsample.shared",
        lst="data/process/opticlust/shared/glne.precluster.opti_mcc.list"
    resources:
        ncores=12,
        time_min=60,
        mem_mb=30000
    shell:
        "bash {input.script} {input.precluster} {resources.ncores}"

##################################################################
#
# Part 4: Generate Data Splits
#
##################################################################

rule make8020splits:
    input:
        script="code/R/generate_splits.R",
        shared=rules.clusterOptiClust.output.shared
    params:
        n_splits=len(split_nums)
    output:
        splits=expand("data/process/splits/split_{num}.csv", num = split_nums)
    shell:
        "Rscript {input.script} {input.shared} {params.n_splits}"

##################################################################
#
# Part N: Generate OptiClust data
#
##################################################################

rule generateOptiClustData:
    input: 
        script="code/bash/splitOptiClust.sh",
        shared=rules.clusterOptiClust.output.shared,
        split="data/process/splits/split_{num}.csv"
    output:
        train="data/process/opticlust/split_{num}/train/glne.precluster.opti_mcc.0.03.subsample.0.03.pick.shared",
        test="data/process/opticlust/split_{num}/test/glne.precluster.opti_mcc.0.03.subsample.0.03.pick.shared"
    resources:
        ncores=12,
        time_min=60,
        mem_mb=30000
    shell:
        "bash {input.script} {input.shared} {input.split} {resources.ncores}"

##################################################################
#
# Part N: Generate OptiFit data
#
##################################################################

# cluster the training datasets
rule clusterOptiFitData:
    input:
        script="code/bash/mothurClusterOptiFit.sh",
        precluster=rules.preclusterSequences.output,
        split="data/process/splits/split_{num}.csv"
    output:
        shared="data/process/optifit/split_{num}/train/glne.precluster.pick.opti_mcc.0.03.subsample.shared",
        reffasta="data/process/optifit/split_{num}/train/glne.precluster.pick.fasta",
        refdist="data/process/optifit/split_{num}/train/glne.precluster.pick.dist",
        reflist="data/process/optifit/split_{num}/train/glne.precluster.pick.opti_mcc.list",
        refCount="data/process/optifit/split_{num}/train/glne.precluster.pick.count_table"
    resources:
        ncores=12,
        time_min=60,
        mem_mb=30000
    shell:
        "bash {input.script} {input.precluster} {input.split} {resources.ncores}"

# fit test data to the training clusters
rule fitOptiFit:
    input:
        script="code/bash/mothurFitOptiFit.sh",
        precluster=rules.preclusterSequences.output,
        split="data/process/splits/split_{num}.csv",
        reffasta=rules.clusterOptiFitData.output.reffasta,
        refdist=rules.clusterOptiFitData.output.refdist,
        reflist=rules.clusterOptiFitData.output.reflist
    output:
        #fit="data/process/optifit/split_{num}/test/glne.precluster.pick.renamed.fit.optifit_mcc.shared",
        fit="data/process/optifit/split_{num}/test/glne.precluster.pick.renamed.fit.optifit_mcc.0.03.subsample.shared",
        query_count='data/process/optifit/split_{num}/test/glne.precluster.pick.renamed.count_table',
        list='data/process/optifit/split_{num}/test/glne.precluster.pick.renamed.fit.optifit_mcc.list',
        #list_accnos='data/process/optifit/split_{num}/test/glne.precluster.pick.subsample.renamed.fit.optifit_mcc.accnos'
    resources:
        ncores=12,
        time_min=120,
        mem_mb=30000
    shell:
        "bash {input.script} {input.precluster} {input.split} {input.reffasta} {input.refdist} {input.reflist} {resources.ncores}"

# rule calc_fraction_mapped:
#     input:
#         script="code/fraction_reads_mapped.py",
#         query=rules.fitOptiFit.output.query_count,
#         ref=rules.clusterOptiFitData.output.refCount,
#         mapped=rules.fitOptiFit.output.list_accnos
#     output:
#         tsv="data/process/optifit/split_{num}/test/fraction_reads_mapped.tsv"
#     script:
#         "code/fraction_reads_mapped.py"

# rule cat_fraction_mapped:
#     input:
#         expand("data/process/optifit/split_{num}/test/fraction_reads_mapped.tsv",
#             num = split_nums)
#     output:
#         tsv="results/tables/fraction_reads_mapped.tsv"
#     shell:
#         """
#         echo "sample\tfraction_mapped\n" > {output.tsv}
#         cat {input} >> {output.tsv}
#         """

##################################################################
#
# Part N: Preprocess Data
#
##################################################################

rule preprocessOptiClust:
    input:
        script="code/R/preprocess.R",
        metadata=rules.getMetadata.output.metadata,
        train=rules.generateOptiClustData.output.train,
        test=rules.generateOptiClustData.output.test
    output:
        preprocTrain="data/learning/results/opticlust/preproc_train_split_{num}.csv",
        preprocTest="data/learning/results/opticlust/preproc_test_split_{num}.csv" 
    resources:
        ncores=12,
        time_min="1:00:00",
        mem_mb=50000
    shell:
        "Rscript --max-ppsize=500000 {input.script} {input.metadata} {input.train} {input.test} {resources.ncores}"

rule preprocessOptiFit:
    input: 
        script="code/R/preprocess.R",
        metadata=rules.getMetadata.output.metadata,
        train=rules.clusterOptiFitData.output.shared,
        test=rules.fitOptiFit.output.fit
    output:
        preprocTrain="data/learning/results/optifit/preproc_train_split_{num}.csv",
        preprocTest="data/learning/results/optifit/preproc_test_split_{num}.csv"
    resources:
        ncores=12,
        time_min="1:00:00",
        mem_mb=50000
    shell:
        "Rscript --max-ppsize=500000 {input.script} {input.metadata} {input.train} {input.test} {resources.ncores}"


##################################################################
#
# Part N: Run Models
#
##################################################################

rule runOptiClustModels:
    input:
        script="code/R/run_model.R",
        train=rules.preprocessOptiClust.output.preprocTrain,
        test=rules.preprocessOptiClust.output.preprocTest
    params:
        model="rf",
        outcome="dx"
    output:
        performance="data/learning/results/opticlust/performance_split_{num}.csv",
        model="data/learning/results/opticlust/model_split_{num}.rds",
        prediction="data/learning/results/opticlust/prediction_results_split_{num}.csv",
        hp_performance="data/learning/results/opticlust/hp_split_{num}.csv"
    resources: 
        ncores=12,
        time_min="72:00:00",
        mem_mb=50000        
    shell:
        "Rscript --max-ppsize=500000 {input.script} {input.train} {input.test} {params.model} {params.outcome} {resources.ncores}"
        
rule runOptiFitModels:
    input:
        script="code/R/run_model.R",
        metadata=rules.getMetadata.output.metadata,
        train=rules.preprocessOptiFit.output.preprocTrain,
        test=rules.preprocessOptiFit.output.preprocTest
    params:
        model="rf",
        outcome="dx"
    output:
        performance="data/learning/results/optifit/performance_split_{num}.csv",
        model="data/learning/results/optifit/model_split_{num}.rds",
        prediction="data/learning/results/optifit/prediction_results_split_{num}.csv",
        hp_performance="data/learning/results/optifit/hp_split_{num}.csv"
    resources: 
        ncores=12,
        time_min="72:00:00",
        mem_mb=50000  
    shell:
        "Rscript --max-ppsize=500000 {input.script} {input.train} {input.test} {params.model} {params.outcome} {resources.ncores}"
        
##################################################################
#
# Part N: Merge Results
#
##################################################################        

rule quantifySplitTogetherFreq:
    input:
        splits=rules.make8020splits.output.splits
    output:
        splitTogetherFreq="results/tables/splitTogetherFrequency.csv"
    script:
        "code/R/quantifySplitTogether.R"

rule calcFracNonMapped:
    input:
        script="code/R/calc_nonmapped.R",
        OFshared=expand("data/process/optifit/split_{num}/test/glne.precluster.pick.renamed.fit.optifit_mcc.0.03.subsample.shared",
                             num = split_nums)
    output:
        optifitNonMapped="results/tables/fracNonMapped.csv"
    shell:
        "Rscript {input.script} {input.OFshared}"
    
rule mergePredictionResults:
    input:
        script="code/R/merge_predictions.R",
        opticlustPred=expand("data/learning/results/opticlust/prediction_results_split_{num}.csv",
                             num = split_nums),
        optifitPred=expand("data/learning/results/optifit/prediction_results_split_{num}.csv",
                           num = split_nums)
    output:
        mergedPrediction="data/learning/summary/merged_predictions.csv",
    shell:
        "Rscript {input.script} {input.opticlustPred} {input.optifitPred}"
        
rule mergePerformanceResults:
    input:
        script="code/R/mergePerformance.R",
        opticlustPerf=expand("data/learning/results/opticlust/performance_split_{num}.csv",
                           num = split_nums),
        optifitPerf=expand("data/learning/results/optifit/performance_split_{num}.csv",
                           num = split_nums)
    output:
        mergedPerf="data/learning/summary/merged_performance.csv"
    shell:
        "Rscript {input.script} {input.opticlustPerf} {input.optifitPerf}"

rule mergeHPperformance:
    input:
        script="code/R/mergeHP.R",
        opticlustHP=expand("data/learning/results/opticlust/hp_split_{num}.csv",
                           num = split_nums),
        optifitHP=expand("data/learning/results/optifit/hp_split_{num}.csv",
                         num = split_nums)
    output:
        mergedHP="data/learning/summary/merged_HP.csv"
    shell:
        "Rscript {input.script} {input.opticlustHP} {input.optifitHP}"
        
rule getMCCdata:
    input:
        script="code/R/get_mcc.R",
        opticlustSensspec="data/process/opticlust/shared/glne.precluster.opti_mcc.sensspec",
        optifitTrainSensspec=expand("data/process/optifit/split_{num}/train/glne.precluster.pick.opti_mcc.sensspec",
                                    num = split_nums),
        optifitTestSensspec=expand("data/process/optifit/split_{num}/test/glne.precluster.pick.renamed.fit.optifit_mcc.steps",
                                   num = split_nums)
    output:
        mergedMCC="data/learning/summary/merged_MCC.csv"
    shell:
        "Rscript {input.script} {input.opticlustSensspec} {input.optifitTrainSensspec} {input.optifitTestSensspec}"
    
rule get_sens_spec:
    input: 
        opticlust_pred=expand("data/learning/results/opticlust/prediction_results_split_{num}.csv",
                              num = split_nums),
        optifit_pred=expand("data/learning/results/optifit/prediction_results_split_{num}.csv",
                            num = split_nums)   
    output:
        allSensSpec="data/learning/summary/all_sens_spec.csv"
    script:
        "code/R/get_sens_spec.R"
        
rule get_opticlust_20_mcc: 
    input:
        script="code/bash/get_opticlust_20_mcc.sh",
        dist=rules.preclusterSequences.output.dist,
        count_table=rules.preclusterSequences.output.count_table,
        split="data/process/splits/split_{num}.csv"
    output:
        sensspec="data/process/opticlust/split_{num}/sub/glne.precluster.pick.opti_mcc.sensspec",
        shared="data/process/opticlust/split_{num}/sub/glne.precluster.pick.opti_mcc.0.03.subsample.shared"
    resources:
        ncores=12,
        time_min=60,
        mem_mb=30000
    shell:
        "bash {input.script} {input.dist} {input.count_table} {input.split} {resources.ncores}"

rule merge_opticlust_20_mcc:
    input:
        sensspec=expand("data/process/opticlust/split_{num}/sub/glne.precluster.pick.opti_mcc.sensspec",
                        num = split_nums)
    output:
        opticlust_20_mcc="results/tables/opticlust_20_mcc.csv"
    script:
        "code/R/merge_opticlust_20_mcc.R"

rule calc_pct_correct:
    input:
        opticlust_pred=expand("data/learning/results/opticlust/prediction_results_split_{num}.csv",
                              num = split_nums),
        optifit_pred=expand("data/learning/results/optifit/prediction_results_split_{num}.csv",
                            num = split_nums)
    output:
        pct_correct="results/tables/pct_class_correct.csv"
    script:
        "code/R/get_pct_correct.R"    
        
rule calcPvalues:
    input:
        mergedPerf=rules.mergePerformanceResults.output.mergedPerf
    output:
        pvalues="results/tables/pvalues.csv"
    script:
        "code/R/calculate_pvalues.R"
        
##################################################################
#
# Part N: Plots
#
##################################################################        

rule plotHPperformance:
    input:
        hp=rules.mergeHPperformance.output.mergedHP
    output:
        hpPlot="results/figures/hp_performance.png"
    script:
        "code/R/plot_HP_performance.R"

#view how many times each sample is in train/test set across splits
rule plot8020splits:
    input:
        splits=rules.make8020splits.output.splits
    output:
        split_plot="results/figures/view_splits.png"
    script:
        "code/R/view_splits.R"
            
rule plotAUROC:
    input:
        perf=rules.mergePerformanceResults.output.mergedPerf,
        pvals=rules.calcPvalues.output.pvalues
    output:
        fig_auc="results/figures/avg_auroc.png"
    script:
        "code/R/plot_auroc.R"
        
rule plotAvgROC:
    input:
        senspec=rules.get_sens_spec.output.allSensSpec
    output:
        fig_roc="results/figures/avg_roc.png"
    script:
        "code/R/plot_avgROC.R"
        
##################################################################
#
# DOCUMENTS
#
##################################################################                

rule update_pages:
    input: 
        exploratory="exploratory/exploratory.html"
    output:
        pages="docs/exploratory.html"
    shell:
        "cp {input.exploratory} docs/"

rule createFig2:
    input:    
        fig2ab=rules.plotAUROC.output.fig_auc,
        fig2c=rules.plotAvgROC.output.fig_roc
    output:
        fig2="submission/figures/fig2.png"
    script:
        "code/R/create_fig2.R"
    
rule createManuscript:
    input: 
        script="submission/manuscript.Rmd",
        fig1a="exploratory/figures/figure1_a.pdf",
        fig1b="exploratory/figures/figure1_b.pdf",
        fig2="exploratory/figures/figure2.pdf",
        ref="submission/references.bib"
    output:
        pdf="submission/manuscript.pdf",
        tex="submission/manuscript.tex"
    shell:
        """
        R -e 'library(rmarkdown);render("submission/manuscript.Rmd", output_format="all")'
        """
  
# FIX: has to be run from teh submission location because of figure relative paths
# rule createManuscriptWord:
#     input: 
#         tex="submission/manuscript.tex"
#     shell:
#         """
#         pandoc -s submission/manuscript.tex -o submission/manuscript.docx
#         """

##################################################################
#
# CLEAN UP
#
##################################################################                

# remove prior output to force recreation of all files
rule clean:
    shell:
        """
        rm -rf data/raw
        rm -rf data/process
        rm -rf data/learning
        rm analysis/*
        rm logs/mothur/*
        rm logs/slurm/*
        """
        
onsuccess:
    print("🎉 completed successfully")

onerror:
    print("💥 errors occured")