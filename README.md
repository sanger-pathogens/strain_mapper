# strain_mapper

[[_TOC_]]

## Pipeline overview

**strain_mapper** maps short read sequences from bacteria to a supplied reference genome.

The pipeline maps reads with `bowtie2`, generates a VCF containing genotype likelihoods for the alignment using `bcftools mpileup`, and then uses `bcftools call` to call variants. This variant information is used to create a consensus sequence based on the mapped reads.

The pipeline will build reference and `bowtie2` indexes if it does not find them in the same directory as the supplied `--reference`.

All relevant intermediate files are currently published in process-specific directories within the supplied `--outdir` directory.

## Usage

Command synopsis:

```text
strain-mapper [--manifest_of_reads <path to manifest>] [--manifest_of_lanes <path to manifest>] [--studyid <study_id> [--runid <run_id> [--laneid <lane_id> [--plexid <plex_id>]]]] --reference <path to reference> --outdir <path to results folder>
```

### Quickstart

#### From source code

To run the pipeline from source:

1. Clone the repository.

   ```bash
   git clone --recurse-submodules git@gitlab.internal.sanger.ac.uk:sanger-pathogens/pipelines/strain_mapper.git
   cd strain_mapper
   ```

2. Run the pipeline with `nextflow`:

   ```bash
   nextflow run . \
       --manifest_of_reads ./test_data/inputs/new_manifest.csv \
       --reference ./test_data/inputs/ref/GCF_000011265.1.fna \
       --outdir my_output
   ```

For example input, see [Input](#input).

See [Parameters](#parameters) for available pipeline options.

#### Using on the Sanger farm

First load the `nextflow` and `ISG/singularity` modules:

```bash
module load nextflow ISG/singularity
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

There are two ways to provide input reads. These can be combined.

#### Manifest of reads

Use `--manifest_of_reads` to provide direct input of compressed FASTQ sequence read files. The manifest should list one pair of read files per sample, one sample per row.

The manifest should have the following format:

```console
ID,R1,R2
test_id,./test_data/inputs/test_1.fastq.gz,./test_data/inputs/test_2.fastq.gz
```

Where:

- `ID` is an arbitrary sample identifier
- `R1` is a `.fastq.gz` file of forward reads
- `R2` is the mate `.fastq.gz` file containing reverse reads

Scripts have been developed to generate manifests appropriate for this pipeline:

- To generate a manifest from a file of lane identifiers visible to `pf`, use [`scripts/generate_manifest_from_lanes.sh`](./scripts/generate_manifest_from_lanes.sh).
- To generate a manifest from a file of custom `.fastq.gz` paths, use [`scripts/generate_manifest.sh`](./scripts/generate_manifest.sh).

Run `--help` on these scripts for more information on script usage.

#### Sequencing data from iRODS

Use `--studyid`, `--runid`, `--laneid`, and `--plexid` to specify data to be downloaded from iRODS. Each sample is defined by a combination of study, run, lane, and plex identifiers.

Run, lane, and plex identifiers are not mandatory. When provided, these parameters gradually restrict the files to be downloaded. When omitted, samples for all possible values are retrieved.

Alternatively, use `--manifest_of_lanes` to provide a manifest listing a batch of study, run, lane, and plex combinations. Run, lane, and plex identifiers can be left blank in the CSV.

The real lane identifier is different from the "lane" identifier commonly used at Sanger for sequencing run output units, usually labelled with syntax such as `48106_1#83`. In this example:

- `48106` is the run identifier
- `1` is the real lane identifier
- `83` is the plex identifier

#### Reference

Use `--reference` to provide the reference genome to map reads against.

### Output

For each sample, the pipeline writes the variant file (`.vcf.gz`) and curated consensus sequence (`.fasta`) under the corresponding sample directory within the supplied `--outdir` directory.

To retain sorted BAM files, use:

```bash
--keep_sorted_bam=true
```

### Parameters

**Sequencing reads**

| Flag                | Type   | Default | Description                                                                                                                        |
| ------------------- | ------ | ------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `manifest_of_reads` | `path` | `null`  | Manifest containing per-sample paths to paired `.fastq.gz` files.                                                                  |
| `manifest_of_lanes` | `path` | `null`  | Manifest containing sequencing datasets to download from iRODS, defined by combinations of study, run, lane, and plex identifiers. |
| `studyid`           | `str`  | `null`  | Sequencing study identifier for read data to use as pipeline input.                                                                |
| `runid`             | `str`  | `null`  | Sequencing run identifier for read data to use as pipeline input.                                                                  |
| `laneid`            | `str`  | `null`  | Sequencing lane identifier for read data to use as pipeline input.                                                                 |
| `plexid`            | `str`  | `null`  | Sequencing lane multiplex tag index for read data to use as pipeline input.                                                        |
| `reference`         | `path` | `null`  | Reference genome to map reads against. Required.                                                                                   |
| `keep_sorted_bam`   | `bool` | `false` | Retain sorted BAM files in the output directory.                                                                                   |

---

**Output options**

| Flag     | Type   | Default       | Description            |
| -------- | ------ | ------------- | ---------------------- |
| `outdir` | `path` | `"./results"` | Output directory path. |

---

**General options**

| Flag       | Type | Default | Description                                     |
| ---------- | ---- | ------- | ----------------------------------------------- |
| `help`     | bool | `false` | Print summary of main parameters and options.   |
| `help_all` | bool | `false` | Print extensive list of parameters and options. |

### Default filtering

The pipeline applies stringent quality filters to ensure high-confidence consensus sequences.

**Quality thresholds**

- Minimum quality score: `>=50` (`QUAL`)
- Read support: `>=3` forward reads (`INFO/ADF[0]`)
- Read support: `>=3` reverse reads (`INFO/ADR[0]`)
- Coverage: `>=8` total reads at position (`INFO/DP`)

**Genotype requirements**

- Only homozygous calls (`0/0` or `1/1`) are included.
- Multiallelic or heterozygous calls (`0/1`) are marked as `Het` and excluded.

**Filter classification**

- `PASS`: Meets all quality thresholds.
- `Het`: Passes quality but has a heterozygous genotype, and is excluded.
- `LowQual`: Fails one or more quality thresholds, and is excluded.

To edit these filters, see the BCFTOOLS documentation on expressions: https://samtools.github.io/bcftools/bcftools.html#expressions

### Advanced Usage

#### Unfiltered mode

Use `--skip_filtering` to include all variants regardless of:

- Quality scores
- Read depth
- Genotype, including heterozygous calls

Results may contain:

- Lower-confidence variants
- More ambiguous positions
- Potential sequencing artefacts

Unfiltered mode is not recommended for standard consensus generation, but may be useful for debugging or specialised analyses.

### Dependencies

Pipeline dependencies are containerised. The pipeline can be run with Docker or Singularity.

## Software versions

Key tools used by the pipeline include:

| Software      | Version                    | Reference                                                                   |
| ------------- | -------------------------- | --------------------------------------------------------------------------- |
| Nextflow      | See pipeline configuration | [Di Tommaso et al. 2017](https://pubmed.ncbi.nlm.nih.gov/28398311/)         |
| Bowtie2       | See pipeline container     | [Langmead and Salzberg 2012](https://doi.org/10.1038/nmeth.1923)            |
| SAMtools      | See pipeline container     | [Li et al. 2009](https://www.ncbi.nlm.nih.gov/pubmed/19505943/)             |
| BCFtools      | See pipeline container     | [Li 2011](https://www.ncbi.nlm.nih.gov/pubmed/21903627/)                    |
| BioContainers | See pipeline container     | [da Veiga Leprevost et al. 2017](https://pubmed.ncbi.nlm.nih.gov/28379341/) |
| Docker        | Optional runtime           | [Docker](https://dl.acm.org/doi/10.5555/2600239.2600241)                    |
| Singularity   | Optional runtime           | [Kurtzer et al. 2017](https://pubmed.ncbi.nlm.nih.gov/28494014/)            |

Exact software versions are defined by the pipeline configuration and containers used for the run.

## Troubleshooting

If the pipeline fails, check the Nextflow log, process-specific logs, and the contents of the supplied `--outdir`.

Common things to check include:

- The manifest has the required columns and points to readable input files.
- The reference path supplied to `--reference` is readable.
- The Sanger farm modules have been loaded before running on the farm.
- Enough disk space is available for `work`, `.nextflow*`, and the output directory.

## Issues and Contributions

If you find an issue with this pipeline, or would like to suggest an improvement, please log an issue or open a pull request in GitHub.

If you are at Sanger and need internal support, you can also contact the IDS Service Desk. For more information about IDS and to raise a support ticket, read the guidance here: https://fred.sanger.ac.uk/page/6946

For further pipeline-specific information or help, contact [path-help@sanger.ac.uk](mailto:path-help@sanger.ac.uk).

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
