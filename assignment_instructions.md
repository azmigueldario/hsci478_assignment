# Instruction for Nexstrain analysis 

The input data is taken from GISAID (EPI_SET_240315sp) as specified in the paper by [Piccoli et al. (2024)](https://doi.org/10.1038/s41598-024-67828-7) with a few modifications to improve the runtime. The specific accession numbers are available in the Supplementary table 1 of the paper.

## Preliminary steps

Index and filter sequences using augur (installation instructions are available at <https://docs.nextstrain.org/projects/augur/en/stable/installation/installation.html>).

During sampling, we select a maximum of 10 strains (`--sequences-per-group `) after grouping by Pango lineage and month (`--group-by`). To optimize the runtime and visualization, no more than 200 sequences are selected (`--subsample-max-sequences`). Finally, a few samples were flagged as having poor quality by the authors, so we exclude those from the final set (`--exclude`).

```sh
# Time: 2 minutes each

# index assemblies information for filtering by quality
augur index \
    --sequences input_data/brazil_sequences.fasta \
    --output processed_data/sequences_index.tsv

# filter out sequences
augur filter \
  --sequences input_data/brazil_sequences.fasta \
  --sequence-index processed_data/sequences_index.tsv \
  --metadata input_data/brazil_metadata.tsv \
  --exclude input_data/poor_quality_genomes.txt \
  --output processed_data/filtered.fasta \
  --group-by pangolin_lineage month \
  --subsample-max-sequences 200 \
  --max-length 29900 \
  --min-date 2021 \
  --subsample-seed 455

```

## Building phylogenetic tree

Create multiple sequence alignment to identify differences among sequences, a necessary input for the visualization step.

- The reference sequences is the Wuhan-Hu-1 strain from the beginning of the pandemic <https://www.ncbi.nlm.nih.gov/nuccore/MN908947>
- The new alignment is used to produce a phylogenetic tree in newick format. The algorithm behind this process is [IQTREE2](https://github.com/iqtree/iqtree2), a maximum likelihood approach with a GTR model\
- Output shows differences in substitutions (SNVs per site)

```sh
# Time: 1 minute each
augur align \
    --sequences processed_data/filtered.fasta \
    --reference-sequence input_data/reference_MN908947.3.fasta \
    --output results/alignment_brazil.fasta \
    --method mafft 

augur tree \
  --alignment results/alignment_brazil.fasta \
  --method iqtree \
  --output results/tree_raw.nwk
```

## Basic phylodynamics

With `augur`, we can try to approximate the ancestral relationships among the strains using the sampling dates available in the metadata. The tool employed in this process is called [TreeTime](https://github.com/neherlab/treetime).

- We use the metadata file we prepared previously, specify that mutations are the unit of divergence (`--divergence-units`), and keep the tree rooted (`--keep-root`)
- If tips deviate too much from the regression line, they will be removed from the tree (`--clock-filter-iqd`)
- The new tree will have branch lenghts that reflect the number of **mutations** instead of **mutations per site** (`--divergence-units`)

```sh
# Time: 3 minutes
augur refine \
  --tree results/tree_raw.nwk \
  --alignment results/alignment_brazil.fasta \
  --metadata input_data/brazil_metadata.tsv \
  --output-tree results/time_tree.nwk \
  --output-node-data results/branch_lengths.json \
  --divergence-units mutations \
  --keep-root \
  --timetree \
  --date-inference marginal \
  --clock-filter-iqd 4 
```

Now that we have adjusted the branch lengths according to the sample date, we will recalculate possible ancestral relationships based on the geographical location described in the metadata. This will predict the most likely location at the internal nodes (most recent common ancestors).

- In other settings, this could produce interesting data. Here, we have samples exclusively from a region and only humans, so no relevant changes will be shown.

```sh
# Time: 1 minute
augur traits \
    --tree results/time_tree.nwk \
    --metadata input_data/brazil_metadata.tsv  \
    --columns host division country \
    --output-node-data results/trait_node.json
    --confidence
```

Finally, we explore if there are nucleotide mutations in an internal node that can lead to its descendants. This will be a nice way to visualize possible recombinants or ancestral relationships.

```sh
augur ancestral \
  --tree results/time_tree.nwk \
  --alignment results/alignment_brazil.fasta \
  --output-node-data results/nt_muts.json \
  --inference joint
```

## Export the data

Now we have everything we need to visualize it on the web. After exporting the files, load them into the [Nextstrain Auspice webtool](https://auspice.us/). Augur sends all the information in a format called [JSON](https://en.wikipedia.org/wiki/JSON) that contains information about the phylogenetic relationship and also the node data we just inferred.

```sh
# Time: 10 second
augur export v2 \
    --tree results/time_tree.nwk \
    --metadata input_data/brazil_metadata.tsv  \
    --node-data results/branch_lengths.json \
                results/trait_node.json \
    --maintainers "hsci/mbb_478" \
    --title "Assignment 3 - viral surveillance" \
    --output results/analysis-package.json \
    --geo-resolutions division
```