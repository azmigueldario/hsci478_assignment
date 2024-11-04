#!/usr/bin/env bash

########################################################
###     requires augur in your environment
########################################################

# Time: 1 minute each
augur align \
    --sequences processed_data/assignment_sequences.fasta \
    --reference-sequence input_data/reference_MN908947.3.fasta \
    --output processed_data/alignment_brazil.fasta \
    --method mafft 

augur tree \
    --alignment processed_data/alignment_brazil.fasta \
    --method iqtree \
    --output processed_data/tree_raw.nwk

# Time: 3 minutes
augur refine \
    --tree processed_data/tree_raw.nwk \
    --alignment processed_data/alignment_brazil.fasta \
    --metadata processed_data/merged_metadata.tsv \
    --output-tree results/time_tree.nwk \
    --output-node-data results/branch_lengths.json \
    --divergence-units mutations \
    --keep-root \
    --timetree \
    --date-inference marginal \
    --clock-filter-iqd 4 

# Time: 1 minute
augur traits \
    --tree results/time_tree.nwk \
    --metadata processed_data/merged_metadata.tsv  \
    --columns host division country \
    --output-node-data results/trait_node.json \
    --confidence

# Time: 10 seconds
augur export v2 \
    --tree results/time_tree.nwk \
    --metadata processed_data/merged_metadata.tsv  \
    --node-data results/branch_lengths.json \
                results/trait_node.json \
    --maintainers "hsci/mbb_478" \
    --title "Assignment 3 - viral surveillance" \
    --output results/analysis-package.json \
    --geo-resolutions division
