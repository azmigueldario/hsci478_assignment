# Instruction for Nexstrain analysis 

The input data is taken from GISAID (EPI_SET_240315sp) as specified in the paper by [Piccoli et al. (2024)](https://doi.org/10.1038/s41598-024-67828-7) with a few modifications to improve the runtime. The specific accession numbers are available in the Supplementary table 1 of the paper.

## Preliminary steps

Index and filter sequences using augur (installation instructions are available at <https://docs.nextstrain.org/projects/augur/en/stable/installation/installation.html>).

During sampling, we select a maximum of 10 strains (`--sequences-per-group `) after grouping by Pango lineage and month (`--group-by`). To optimize the runtime and visualization, no more than 200 sequences are selected (`--subsample-max-sequences`). Finally, a few samples were flagged as having poor quality by the authors, so we exclude those from the final set (`--exclude`).

```sh

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

- The reference sequences is the Wuhan-1 strain from the beginning of the pandemic

```sh
augur align \
    --sequences processed_data/filtered.fasta \
    --reference-sequence input_data/reference_MN908947.3.fasta \
    --output results/alignment_brazil.fasta \
    --method mafft

```
