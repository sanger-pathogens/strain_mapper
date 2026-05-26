# strain_mapper

[[_TOC_]]

## Pipeline overview

**strain_mapper** maps short-read bacterial sequence data to a supplied reference genome.

The pipeline maps reads with `bowtie2`, generates genotype likelihoods with `bcftools mpileup`, calls variants with `bcftools call`, and uses those variants to create a consensus sequence from the mapped reads.

The pipeline will build reference and `bowtie2` indexes if it does not find them in the same directory as the supplied `--reference`.

All relevant intermediate files are currently published in process-specific directories within the supplied `--outdir` directory.

## Usage

Command synopsis:

```text
strain-mapper (--manifest_of_reads <path> | --manifest_of_lanes <path> | --studyid <study_id> [--runid <run_id>] [--laneid <lane_id>] [--plexid <plex_id>]) --reference <path> [--outdir <path>]
```

### Quickstart

#### From source code

To run the pipeline from source:

1. Clone the repository:

   ```bash
   git clone --recurse-submodules git@gitlab.internal.sanger.ac.uk:sanger-pathogens/pipelines/strain_mapper.git
   cd strain_mapper
   ```

2. Run the pipeline:

   ```bash
   nextflow run . \
       --manifest_of_reads ./test_data/inputs/new_manifest.csv \
       --reference ./test_data/inputs/ref/GCF_000011265.1.fna \
       --outdir my_output
   ```

Common profiles include `docker` and `singularity`.

See [Input](#input) for input requirements and [Parameters](#parameters) for available pipeline options.

#### Using on the Sanger farm

First load the required modules:

```bash
module load nextflow ISG/singularity
```

If you are using the installed pipeline module, you can run the pipeline with `strain-mapper`. For example, to see a help message:

```bash
module load strain-mapper
strain-mapper --help
```

It is good practice to submit a dedicated job for the Nextflow master process using the `oversubscribed` queue:

```bash
bsub -o output.o -e error.e -q oversubscribed -R "select[mem>4000] rusage[mem=4000]" -M4000 nextflow run . \
    --manifest_of_reads ./test_data/inputs/new_manifest.csv \
    --reference ./test_data/inputs/ref/GCF_000011265.1.fna \
    --outdir my_output
```

Once your run has finished, check output in the `outdir` and clean up any intermediate files. Assuming no other pipelines are running from the current working directory, run:

```bash
rm -rf work .nextflow*
```

### Input

There are two broad ways to provide input reads. These can be combined.

#### Manifest of reads

Use `--manifest_of_reads` to provide compressed FASTQ read files directly. The manifest should list one pair of read files per sample, one sample per row.

The manifest should use the following format:

```console
ID,R1,R2
test_id,./test_data/inputs/test_1.fastq.gz,./test_data/inputs/test_2.fastq.gz
```

Where:

- `ID` is an arbitrary sample identifier.
- `R1` is a `.fastq.gz` file of forward reads.
- `R2` is the mate `.fastq.gz` file containing reverse reads.

Scripts are available to generate manifests for this pipeline:

- To generate a manifest from a file of lane identifiers visible to `pf`, use [`scripts/generate_manifest_from_lanes.sh`](./scripts/generate_manifest_from_lanes.sh).
- To generate a manifest from a file of custom `.fastq.gz` paths, use [`scripts/generate_manifest.sh`](./scripts/generate_manifest.sh).

Run `--help` on these scripts for more information on script usage.

#### Sequencing data from iRODS

Use `--studyid`, `--runid`, `--laneid`, and `--plexid` to specify data to download from iRODS. Each sample is defined by a combination of study, run, lane, and plex identifiers.

Run, lane, and plex identifiers are not mandatory. When provided, these parameters gradually restrict the files to be downloaded. When omitted, samples for all possible values are retrieved.

Alternatively, use `--manifest_of_lanes` to provide a manifest listing a batch of study, run, lane, and plex combinations. Run, lane, and plex identifiers can be left blank in the CSV.

The real lane identifier is different from the "lane" identifier commonly used at Sanger for sequencing run output units, usually labelled with syntax such as `48106_1#83`. In this example:

- `48106` is the run identifier.
- `1` is the real lane identifier.
- `83` is the plex identifier.

#### Reference

Use `--reference` to provide the reference genome to map reads against.

### Output

For each sample, the pipeline writes the variant file (`.vcf.gz`) and curated consensus sequence (`.fasta`) under the corresponding sample directory within the supplied `--outdir` directory.

To retain sorted BAM files, use:

```bash
--keep_sorted_bam=true
```

### Parameters

#### Required Parameters

At least one input method is required: either provide `--manifest_of_reads`, provide `--manifest_of_lanes`, or provide sequencing identifiers with `--studyid`, `--runid`, `--laneid`, and `--plexid`.

| Option      | Type   | Required | Default | Description                            |
| ----------- | ------ | -------- | ------- | -------------------------------------- |
| `reference` | `path` | Yes      | `null`  | Reference genome to map reads against. |

#### Optional Parameters

##### Sequencing reads

| Option              | Type   | Required                  | Default | Description                                                                                                                        |
| ------------------- | ------ | ------------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `manifest_of_reads` | `path` | At least one input method | `null`  | Manifest containing per-sample paths to paired `.fastq.gz` files.                                                                  |
| `manifest_of_lanes` | `path` | At least one input method | `null`  | Manifest containing sequencing datasets to download from iRODS, defined by combinations of study, run, lane, and plex identifiers. |
| `studyid`           | `str`  | At least one input method | `null`  | Sequencing study identifier for read data to use as pipeline input.                                                                |
| `runid`             | `str`  | No                        | `null`  | Sequencing run identifier used to restrict iRODS input when `studyid` is supplied.                                                 |
| `laneid`            | `str`  | No                        | `null`  | Sequencing lane identifier used to restrict iRODS input when `studyid` is supplied.                                                |
| `plexid`            | `str`  | No                        | `null`  | Sequencing lane multiplex tag index used to restrict iRODS input when `studyid` is supplied.                                       |

##### Pipeline Parameters

| Option            | Type   | Required | Default     | Description                                                    |
| ----------------- | ------ | -------- | ----------- | -------------------------------------------------------------- |
| `keep_sorted_bam` | `bool` | No       | `false`     | Retain sorted BAM files in the output directory.               |
| `skip_filtering`  | `bool` | No       | `false`     | Skip variant filtering. See [Advanced Usage](#advanced-usage). |
| `outdir`          | `path` | No       | `./results` | Path to the directory where results will be written.           |

##### General Parameters

| Option            | Type | Required | Default | Description                                     |
| ----------------- | ---- | -------- | ------- | ----------------------------------------------- |
| `help`            | bool | No       | `false` | Print summary of main parameters and options.   |
| `help_all`        | bool | No       | `false` | Print extensive list of parameters and options. |
| `monochrome_logs` | bool | No       | `false` | Output logs in plain ASCII.                     |

### Default filtering

The pipeline applies stringent quality filters to support high-confidence consensus sequence generation.

**Quality thresholds**

- Minimum quality score: `>=50` (`QUAL`).
- Read support: `>=3` forward reads (`INFO/ADF[0]`).
- Read support: `>=3` reverse reads (`INFO/ADR[0]`).
- Coverage: `>=8` total reads at the position (`INFO/DP`).

**Genotype requirements**

- Only homozygous calls (`0/0` or `1/1`) are included.
- Multiallelic or heterozygous calls (`0/1`) are marked as `Het` and excluded.

**Filter classification**

- `PASS`: Meets all quality thresholds.
- `Het`: Passes quality but has a heterozygous genotype, and is excluded.
- `LowQual`: Fails one or more quality thresholds, and is excluded.

To edit these filters, see the BCFtools documentation on expressions: https://samtools.github.io/bcftools/bcftools.html#expressions

### Advanced Usage

#### Unfiltered mode

Use `--skip_filtering` to include all variants regardless of:

- Quality scores.
- Read depth.
- Genotype, including heterozygous calls.

Results may contain:

- Lower-confidence variants.
- More ambiguous positions.
- Potential sequencing artefacts.

Unfiltered mode is not recommended for standard consensus generation, but may be useful for debugging or specialised analyses.

### Dependencies

Pipeline dependencies are containerised. The pipeline can be run with Docker or Singularity.

The pipeline requires a reference genome supplied with `--reference`. Reference and `bowtie2` indexes are built automatically if they are not found next to the supplied reference.

## Software versions

Key tools used by the pipeline include:

| Software | Version                | Image URL                  |
| -------- | ---------------------- | -------------------------- |
| Nextflow | `>=21.04.0`            | See pipeline configuration |
| bowtie2  | See pipeline container | See pipeline container     |
| SAMtools | See pipeline container | See pipeline container     |
| BCFtools | See pipeline container | See pipeline container     |

## Troubleshooting

If the pipeline fails, check the Nextflow log, process-specific logs, and the contents of the supplied `--outdir`.

Common things to check include:

- The manifest has the required `ID`, `R1`, and `R2` columns.
- Input FASTQ paths are readable from the system where the pipeline is running.
- The reference path supplied to `--reference` is readable.
- The Sanger farm modules have been loaded before running on the farm.
- Enough disk space is available for `work`, `.nextflow*`, and the output directory.

## Issues and Contributions

If you find an issue with this pipeline, or would like to suggest an improvement, please log an issue or open a pull request on this repository.

If you are at Sanger and need internal support, you can raise an issue on the PAM Freshservice portal: https://sanger.freshservice.com/support/catalog/items/426

Developer contributions to this pipeline will only be accepted if all pipeline tests pass. To check:

1. Make your changes.

2. Download the test data:

   ```bash
   python3 scripts/download_test_data.py
   ```

3. Install [`nf-test`](https://code.askimed.com/nf-test/installation/) (`>=0.7.0`) and run the tests:

   ```bash
   nf-test test tests/*.nf.test
   ```

   If running on the Sanger HPC cluster, add the option `--profile sanger_local`.

4. Submit a pull request.

strain_mapper was originally produced by Marta Matuszewska and adapted for Nextflow by PaM Informatics.

Pipeline/tool citations are listed in [`CITATIONS.md`](CITATIONS.md).
