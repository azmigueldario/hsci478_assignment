# Instruction for Nexstrain assignment analysis

The input data is taken from GISAID (EPI_SET_240315sp) as specified in the paper by [Piccoli et al. (2024)](https://doi.org/10.1038/s41598-024-67828-7) with a few modifications to improve the runtime. The specific accession numbers are available in the Supplementary table 1 of the paper.

## Environment requirements

Most bioinformatics pipelines require a Unix-type environment, which can be Linux, MacOS, or the Windows Subsystem for Linux (WSL2) in Windows. We use the **conda** environment management to install all dependencies and guarantee reproducibility.

We will mainly use **Nextstrain - Augur**. The installation instructions and additional details are available at the [Nextstrain documentation](https://docs.nextstrain.org/projects/augur/en/stable/installation/installation.html).

Once you have [`conda`](https://docs.conda.io/projects/conda/en/latest/index.html#) (or [`mamba`](https://github.com/mamba-org/mamba)) ready, you can use the `environment.yml` from this folder to reproduce the environment:

```sh

conda create --name augur -f environment.yml

# for mamba
mamba create --name augur -f environment.yml
```

## Preliminary steps

To optimize runtime and provide additional context for the samples, we run a few preliminary filter steps. During sampling, we select a maximum of 150 strains (`--subsample-max-sequences`) after grouping by month (`--group-by`). Finally, a few samples were flagged as having poor quality by the authors, so we exclude those from the final set (`--exclude`). To obtain the same results, a random seed has been added to the command.

```sh
# Time: 2 minutes each

# index assemblies information for filtering by quality
augur index \
    --sequences input_data/study_sequences.fasta \
    --output processed_data/study_index.tsv


# filter out sequences
augur filter \
  --sequences input_data/study_sequences.fasta \
  --sequence-index processed_data/study_index.tsv \
  --metadata input_data/study_metadata.tsv \
  --exclude input_data/poor_quality_genomes.txt \
  --output processed_data/filtered_study.fasta \
  --output-metadata processed_data/metadata_filtered.tsv \
  --group-by  month \
  --subsample-max-sequences 150 \
  --max-length 29900 \
  --min-date 2020 \
  --subsample-seed 455
```

To provide additional context, a few more Brazilian strains will be added after filtering. The `.fasta` files can be merged with simple command line magic, but its better to handle the metadata carefully, so we merge the contextual information with `augur` too.

```sh
cat input_data/complementary_sequences.fasta \
    processed_data/filtered_study.fasta > processed_data/assignment_sequences.fasta

# merge metadata tables
augur merge \
    --metadata  STUDY=processed_data/metadata_filtered.tsv \
                ADDITIONAL=input_data/complementary_metadata.tsv \
    --output-metadata processed_data/merged_metadata.tsv

```

## Building phylogenetic tree

Create multiple sequence alignment to identify differences among sequences, a necessary input for the visualization step.

- The reference sequences is the Wuhan-Hu-1 strain from the beginning of the pandemic <https://www.ncbi.nlm.nih.gov/nuccore/MN908947>
- The new alignment is used to produce a phylogenetic tree in newick format. The algorithm behind this process is [IQTREE2](https://github.com/iqtree/iqtree2), a maximum likelihood approach with a GTR model
- Output shows differences in substitutions per site (SNVs per site)

```sh
# Time: 1 minute each
augur align \
    --sequences processed_data/assignment_sequences.fasta \
    --reference-sequence input_data/reference_MN908947.3.fasta \
    --output processed_data/alignment_assignment.fasta \
    --method mafft 

augur tree \
    --alignment processed_data/alignment_assignment.fasta \
    --method iqtree \
    --output processed_data/tree_raw.nwk
```

## Basic phylodynamics

With `augur`, we can try to approximate the ancestral relationships among the strains using the sampling dates available in the metadata. The tool employed in this process is called [TreeTime](https://github.com/neherlab/treetime).

- We use the metadata file we prepared previously, specify that mutations are the unit of divergence (`--divergence-units`), and keep the tree rooted (`--keep-root`)
- If tips deviate too much from the regression line, they will be removed from the tree (`--clock-filter-iqd`)
- The new tree will have branch lenghts that reflect the number of **mutations** instead of **mutations per site** (`--divergence-units`)

```sh
# Time: 3 minutes
augur refine \
  --tree processed_data/tree_raw.nwk \
  --alignment processed_data/alignment_assignment.fasta \
  --metadata processed_data/merged_metadata.tsv \
  --output-tree results/time_tree.nwk \
  --output-node-data results/branch_lengths.json \
  --divergence-units mutations \
  --keep-root \
  --timetree \
  --clock-filter-iqd 4 
```

Now that we have adjusted the branch lengths according to the sample date, we will recalculate possible ancestral relationships based on the geographical location described in the metadata. This will predict the most likely location at the internal nodes (most recent common ancestors).

- In other settings, this could produce interesting data. Here, we have samples exclusively from a region and only humans, so no relevant changes will be shown.

```sh
# Time: 1 minute
augur traits \
    --tree results/time_tree.nwk \
    --metadata processed_data/merged_metadata.tsv  \
    --columns pangolin_lineage \
    --output-node-data results/trait_node.json
    --confidence
```

Finally, we explore if there are nucleotide mutations in an internal node that can lead to its descendants. This will be a nice way to visualize possible recombinants or ancestral relationships.

```sh
# optional
augur ancestral \
  --tree results/time_tree.nwk \
  --alignment processed_data/alignment_assignment.fasta \
  --output-node-data results/nt_muts.json \
  --inference joint
```

## Export the data

Now we have everything we need to visualize it on the web. After exporting the files, load them into the [Nextstrain Auspice webtool](https://auspice.us/). Augur sends all the information in a format called [JSON](https://en.wikipedia.org/wiki/JSON) that contains information about the phylogenetic relationship and also the node data we just inferred.

```sh
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
```

## References

We gratefully acknowledge all data contributors, i.e., the Authors and their Originating laboratories responsible for obtaining the specimens, and their Submitting laboratories for generating the genetic sequence and metadata and sharing via the GISAID Initiative, on which this research is based. Elbe, S. and Buckland-Merrett, G. (2017) [Data, disease and diplomacy: GISAID’s innovative contribution to global health.](http://dx.doi.org/10.46234/ccdcw2021.255) Global Challenges, 1:33-46. [
**Note:** _The complete list of used sequences is availble in the file [sample_list_gisaid.txt](./input_data/sample_list_gisaid.txt)_ ]

Nextstrain - Hadfield et al. [Nextstrain: real-time tracking of pathogen evolution](https://doi.org/10.1093/bioinformatics/bty407), Bioinformatics (2018).

IQTREE2 - B.Q. Minh, et al. (2020) [IQ-TREE 2: New models and efficient methods for phylogenetic inference in the genomic era.]( https://doi.org/10.1093/molbev/msaa015) Mol. Biol. Evol., 37:1530-1534.

TimeTree - Pavel Sagulenko, Vadim Puller, Richard A Neher. (2018) [TreeTime: Maximum-likelihood phylodynamic analysis.](https://doi.org/10.1093/ve/vex042) Virus evolution.

MAGFFT - Katoh K and Standley D. (2013) [MAFFT Multiple Sequence Alignment Software Version 7](https://doi.org/10.1093/molbev/mst010). Mol Biol Evo Jan 16;30(4)
