# strain_mapper

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A521.04.0-23aa62.svg?labelColor=000000)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

**strain_mapper** is a pipeline for mapping short read sequences of single chromosome bacteria to a given reference.

## Pipeline summary

**strain_mapper** maps short read sequences to a given reference genome using bowtie2. It generates a VCF containing genotype likelihoods for the alignment using `bcftools mpileup` and subsequently uses `bcftools call` to call the variants. This variant information is then used to create a consensus sequence based on the mapped reads.

The pipeline assumes that the largest sequence in the `--reference` is bacteria's chromosome and will only generate a consensus sequence for this sequence.

The pipeline will build reference and bowtie2 indexes if it doesn't find them in the same directory as the supplied `--reference`.

All relevant intermediate files are currently published in process-specific directories within the supplied `--output` directory.

## Getting started

### Running on the farm (Sanger HPC clusters)

1. Load nextflow and singularity modules:
   ```bash
   module load nextflow ISG/singularity
   ```

2. Clone the repo:
   ```bash
   git clone --recurse-submodules git@gitlab.internal.sanger.ac.uk:sanger-pathogens/pipelines/strain_mapper.git
   cd strain_mapper
   ```

3. Start the pipeline  
   For example input, please see [Generating a manifest](#generating-a-manifest).  
   Note: To use the appropriate Sanger configuration, please run with `-profile sanger_lsf` option.

   Example:
   ```bash
   nextflow run . -profile sanger_lsf --input ./test_data/inputs/test_manifest.csv --reference ./test_data/ref/test_ref.fna --outdir my_output
   ```

   It is good practice to submit a dedicated job for the nextflow master process (use the `oversubscribed` queue):
   ```bash
   bsub -o output.o -e error.e -q oversubscribed -R "select[mem>4000] rusage[mem=4000]" -M4000 nextflow run . -profile sanger_lsf --input ./test_data/inputs/test_manifest.csv --reference ./test_data/ref/test_ref.fna --outdir my_output
   ```

   See [usage](#usage) for all available pipeline options.

4. Once your run has finished, check output in the `outdir` and clean up any intermediate files. To do this (assuming no other pipelines are running from the current working directory) run:

   ```bash
   rm -rf work .nextflow*
   ```

## Generating a manifest

Manifests supplied as an argument to `--input`, should be of of the following format:

```console
ID,R1,R2
test_id,./test_data/inputs/test_1.fastq.gz,./test_data/inputs/test_2.fastq.gz
```

Where column `ID` can be an arbitrary sample identifier, `R1` is a .fastq.gz file of forward reads, `R2` is the mate .fastq.gz file containing reverse reads. 

Scripts have been developed to generate manifests appropriate for this pipeline:

- To generate a manifest from a file of lane identifiers visible to `pf`, use [this script](https://gitlab.internal.sanger.ac.uk/sanger-pathogens/pipelines/metawrap_qc/-/blob/main/generate_manifest_from_lanes.sh).

- To generate a manifest from a file of custom .fastq.gz paths, use [this script](https://gitlab.internal.sanger.ac.uk/sanger-pathogens/pipelines/metawrap_qc/-/blob/main/generate_manifest.sh).

Please run `--help` on these scripts or see [this README](https://gitlab.internal.sanger.ac.uk/sanger-pathogens/pipelines/metawrap_qc#generating-manifests) for information on script usage.

## Usage

```console
Usage:
   nextflow run main.nf
Options:
   --input                      Manifest containing per-sample paths to .fastq.gz files (mandatory)
   --reference                  Reference to map reads against (mandatory)
   --outdir                     Specify output directory [default: ./results] (optional)
   --help                       Print this help message (optional)
```

## Credits

strain_mapper was originally produced by Marta Matuszewska and adapted for nextflow by PAM informatics.

## Support

For further information or help, don't hesitate to get in touch via [path-help@sanger.ac.uk](mailto:path-help@sanger.ac.uk).

## Citations

If you use strain_mapper for your analysis, please cite the following doi: <PLACEHOLDER_FOR_CITATION>

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.