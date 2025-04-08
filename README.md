# strain_mapper

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A521.04.0-23aa62.svg?labelColor=000000)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

**strain_mapper** is a pipeline for mapping short read sequences of bacteria to a given reference.

## Pipeline summary

**strain_mapper** maps short read sequences to a given reference genome using bowtie2. It generates a VCF containing genotype likelihoods for the alignment using `bcftools mpileup` and subsequently uses `bcftools call` to call the variants. This variant information is then used to create a consensus sequence based on the mapped reads.

The pipeline will build reference and bowtie2 indexes if it doesn't find them in the same directory as the supplied `--reference`.

All relevant intermediate files are currently published in process-specific directories within the supplied `--outdir` directory.

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

   Example:

   ```bash
   nextflow run . --manifest_of_reads ./test_data/inputs/new_manifest.csv --reference ./test_data/inputs/ref/GCF_000011265.1.fna --outdir my_output
   ```

   It is good practice to submit a dedicated job for the nextflow master process (use the `oversubscribed` queue):

   ```bash
   bsub -o output.o -e error.e -q oversubscribed -R "select[mem>4000] rusage[mem=4000]" -M4000 nextflow run . --manifest_of_reads ./test_data/inputs/new_manifest.csv --reference ./test_data/inputs/ref/GCF_000011265.1.fna --outdir my_output
   ```

   See [usage](#usage) for all available pipeline options.

4. Once your run has finished, check output in the `outdir` and clean up any intermediate files. To do this (assuming no other pipelines are running from the current working directory) run:

   ```bash
   rm -rf work .nextflow*
   ```

## Generating a manifest

Manifests supplied as an argument to `--manifest_of_reads` should be of of the following format:

```console
ID,R1,R2
test_id,./test_data/inputs/test_1.fastq.gz,./test_data/inputs/test_2.fastq.gz
```

Where column `ID` can be an arbitrary sample identifier, `R1` is a .fastq.gz file of forward reads, `R2` is the mate .fastq.gz file containing reverse reads.

Scripts have been developed to generate manifests appropriate for this pipeline:

- To generate a manifest from a file of lane identifiers visible to `pf`, use [this script](./scripts/generate_manifest_from_lanes.sh).

- To generate a manifest from a file of custom .fastq.gz paths, use [this script](./scripts/generate_manifest.sh).

Please run `--help` on these scripts for more information on script usage.

## Usage

```console
Usage:
strain-mapper [--manifest_of_reads <path to manifest>] [--manifest_of_lanes <path to manifest>] [--studyid <study_id>, [--runid <run_id>, [--laneid <lane_id>, [--plexid <plex_id>]]]] --reference <path to reference> --outdir <path to results folder>

Input parameters:

  Sequencing reads:
    There are two ways of providing input reads, which can be combined:

    1) through direct input of compressed fastq sequence reads files. This kind of input is passed by specifying the paths to the
       read files via a manifest listing the pair of read files pertaing to a sample, one per row.

    --manifest_of_reads          Manifest containing per-sample paths to .fastq.gz files (optional)

    2) through specification of data to be downloaded from iRODS. Each sample is defined by a combination of study, run, lane and plex ids
       (these ids correspond to the reference of the sequencing experiment). Run, lane and plex ids are not mandatory: when provided, these
       parameters gradually restrict of files to be downloaded; when ommitted, samples for all possible values are retrieved.
       This information can be provided via a combination of workflow parameters passed on through command line options: --study, --runid,
       --laneid and --plexid; this defines a single sequencing dataset based on a combination of study, run, lane and plex ids.

    --studyid                    ID of sequencing study including read data to use as pipeline input (mandatory)
    --runid                      ID of sequencing run including read data to use as pipeline input (mandatory)
    --laneid                     ID of sequencing lane (as in a lane within of a flow cell) including read data to use as pipeline input (mandatory)
    --plexid                     ID of sequencing lane multiplex tag index including read data to use as pipeline input (mandatory)

        Alternatively, the user can provide a manifest listing a batch of such combinations.

   --manifest_of_lanes          Manifest containing specification of data to be downloaded from iRODS (optional)
                                 Each row defines a sequencing dataset based on a combination of study, run, lane and plex ids.
                                 Run, lane and plex ids are not mandatory (field in csv file can be left blank);
                                 when provided, these gradually restrict of files to be downloaded.

  NB: the real lane id is different from the the so-called "lane" id, a term commonly used in Sanger referring to this sequencing run output unit, usually labelled with this syntax: 48106_1#83.
  In this, the run id is 48106, the (real) lane id is 1 and the plex id is 83.

  Other input parameters:
    --reference                  Reference to map reads against (mandatory)

Output parameters:
    --outdir                     Specify output directory [default: ./results] (optional)

General options:
  --help                       Print summary of main parameters and options (optional)
  --help_all                   Print extensive list of parameters and options (optional)
    --help                       Print this help message (optional)
```

## Default filtering

The pipeline applies stringent quality filters to ensure high-confidence consensus sequences:

1. Quality Thresholds:

- Minimum quality score: `≥50 (QUAL)`

- Read support:

  - ≥3 forward reads (`INFO/ADF[0]`)

  - ≥3 reverse reads (`INFO/ADR[0]`)

- Coverage: ≥8 total reads at position (`INFO/DP`)

2. Genotype Requirements:

- Only homozygous calls (`0/0 `or `1/1`) are included

- All multiallelic/heterozygous calls (`0/1`) are marked as `'Het'` and excluded

3. Filter Classification:

- `'PASS'`: Meets all quality thresholds

- `'Het'`: Passes quality but has heterozygous genotype (excluded)

- `'LowQual'`: Fails one or more quality thresholds (excluded)

To edit these filters, please follow the documentation as seen on the BCFTOOLS view page under expressions:

https://samtools.github.io/bcftools/bcftools.html#expressions

### Unfiltered Mode (Advanced Use)

When using --skip_filtering:

- All variants are included regardless of:

      - Quality scores
      - Read depth
      - Genotype (including heterozygous calls)

- Results may contain:

      - Lower-confidence variants
      - More ambiguous positions
      - Potential sequencing artifacts

> **_NOTE_** Unfiltered mode is not recommended for standard consensus generation but may be useful for debugging or specialized analyses.

## Output

You will find the variant (.vcf.gz) file and the curated consensus sequence (.fasta) for each sample under the corresponding sample directory within the supplied --outdir directory. If you also wish to retain the sorted BAM files, please use --keep_sorted_bam=true.

## Contributions and testing

Developer contributions to this pipeline will only be accepted if all pipeline tests pass. To check:

1. Make your changes.

2. Download the test data. A utility script is provided:

   ```
   python3 scripts/download_test_data.py
   ```

3. Install [`nf-test`](https://code.askimed.com/nf-test/installation/) (>=0.7.0) and run the tests:

   ```
   nf-test test tests/*.nf.test
   ```

   If running on Sanger HPC cluster, add the option `--profile sanger_local`.

4. Submit a PR.

## Credits

strain_mapper was originally produced by Marta Matuszewska and adapted for nextflow by PAM informatics.

## Support

For further information or help, don't hesitate to get in touch via [path-help@sanger.ac.uk](mailto:path-help@sanger.ac.uk).

## Citations

If you use strain_mapper for your analysis, please cite the following doi: <PLACEHOLDER_FOR_CITATION>

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.
