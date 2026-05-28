# strain_mapper

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A521.04.0-23aa62.svg?labelColor=000000)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

[[_TOC_]]

## Pipeline overview

**strain_mapper** is a Nextflow DSL2 pipeline for mapping short-read bacterial sequencing data to a reference genome and calling variants. Starting from paired FASTQ files, it produces per-sample VCF files and consensus FASTA sequences.

The pipeline performs the following steps:

1. **Input** — reads are loaded (see [Input](#input)).
2. **Reference indexing** — Bowtie2 and Samtools indexes are built for the reference if not already present in the same directory.
3. **Mapping** — reads are aligned to the reference with Bowtie2.
4. **SAM → BAM processing** — the alignment is converted to sorted, indexed BAM; duplicate reads are marked with Picard.
5. **Variant calling** — bcftools mpileup generates genotype likelihoods and bcftools call calls variants.
6. **Variant filtering** — variants are classified as `PASS`, `Het` (heterozygous), or `LowQual` based on quality, strand support, and coverage thresholds.
7. **Consensus** — a consensus FASTA sequence is generated from the PASS variants.

Default quality filters applied during variant filtering:

| Filter                                | Threshold                    |
| ------------------------------------- | ---------------------------- |
| Minimum quality (QUAL)                | ≥ 50                         |
| Minimum forward strand reads (ADF[0]) | ≥ 3                          |
| Minimum reverse strand reads (ADR[0]) | ≥ 3                          |
| Minimum total depth (DP)              | ≥ 8                          |
| Genotype                              | Homozygous only (0/0 or 1/1) |

## Usage

### Quickstart

#### From source code

1. Clone this repository (including submodules):

   ```bash
   git clone --recurse-submodules https://gitlab.internal.sanger.ac.uk/sanger-pathogens/pipelines/strain_mapper.git
   cd strain_mapper
   ```

2. To run with `docker`, use the `-profile docker` option:

   ```bash
   nextflow run main.nf \
       -profile docker \
       --manifest_of_reads manifest.csv \
       --reference /path/to/reference.fna \
       --outdir my_output
   ```

   Other profiles are also supported (`singularity`).  
   :warning: If no profile is specified the pipeline will run with the Sanger HPC-specific configuration.

3. Once the run has finished, clean up intermediate files:

   ```bash
   rm -rf work .nextflow*
   ```

#### Using on the Sanger farm

First load the latest pipeline module:

```bash
module load strain-mapper
```

Then run on the command line with `strain-mapper <options>`. For instance, to see a help message:

```bash
strain-mapper --help
```

Submit to LSF:

```bash
bsub -o output.o -e error.e -q oversubscribed -R "select[mem>4000] rusage[mem=4000]" -M4000 \
    strain-mapper \
        --manifest_of_reads manifest.csv \
        --reference /path/to/reference.fna \
        --outdir my_output
```

### Input

#### Manifest (`--manifest`)

A CSV file with the required header `ID,R1,R2`, containing per-sample paths to paired `.fastq.gz` files:

```
ID,R1,R2
sampleA,/path/to/sampleA_1.fastq.gz,/path/to/sampleA_2.fastq.gz
sampleB,/path/to/sampleB_1.fastq.gz,/path/to/sampleB_2.fastq.gz
```

#### Generating a manifest

**Sanger users:** the [manifest_generator](https://gitlab.internal.sanger.ac.uk/sanger-pathogens/pipelines/manifest_generator/) tool can generate a compatible `ID,R1,R2` manifest from a directory of FASTQ files or from iRODS.

#### Other input modes

This pipeline supports additional input modes via the `mixed_input` sub-workflow — these can be combined in a single run:

- **iRODS** (Sanger internal) — specify `--studyid`, `--runid`, `--laneid`, and/or `--plexid` on the command line; at least `--studyid` or `--runid` is required. A batch CSV of multiple iRODS searches can be supplied via `--manifest_of_lanes`. Requires an active iRODS session (`iinit`).
- **ENA download** — supply a file of ENA accession IDs via `--manifest_ena`. Set `--accession_type` to `run` (default), `sample`, or `study`.
- **Directory scan** — provide a path to a directory of FASTQ files via `--manifest_from_dir`. Use `--fastq_validation` (`strict`/`relaxed`, default: `strict`) and `--max_depth` (default: `0`) to control discovery.

Run `--help` for the full parameter list.

### Output

Results are written to `--outdir` (default: `./results`):

```
results/
  bowtie2/
    <sample_ID>.bam                   # Sorted, deduplicated BAM
    <sample_ID>.bam.bai
  variants/
    <sample_ID>.vcf.gz                # Filtered VCF
    <sample_ID>.vcf.gz.tbi
  consensus/
    <sample_ID>.consensus.fasta       # Consensus FASTA
```

### Parameters

**Sequencing reads input**

| Option                | Type     | Default | Description                                                |
| --------------------- | -------- | ------- | ---------------------------------------------------------- |
| `--manifest_of_reads` | `path`   | `null`  | Manifest CSV with header `ID,R1,R2` for local FASTQ input. |
| `--manifest_of_lanes` | `path`   | `null`  | Manifest CSV with iRODS study/run/lane/plex IDs.           |
| `--studyid`           | `string` | `null`  | iRODS study ID.                                            |
| `--runid`             | `string` | `null`  | iRODS run ID.                                              |
| `--laneid`            | `string` | `null`  | iRODS lane ID.                                             |
| `--plexid`            | `string` | `null`  | iRODS plex ID.                                             |

---

**Reference**

| Option        | Type   | Default | Description                                   |
| ------------- | ------ | ------- | --------------------------------------------- |
| `--reference` | `path` | `""`    | Path to the reference FASTA file (mandatory). |

---

**Output options**

| Option              | Type      | Default     | Description                          |
| ------------------- | --------- | ----------- | ------------------------------------ |
| `--outdir`          | `path`    | `./results` | Directory where results are written. |
| `--monochrome_logs` | `boolean` | `false`     | Output logs in plain ASCII.          |

### Advanced usage

#### Customising variant filters

Variant filters are applied via a bcftools expression. To modify the default thresholds, refer to the [bcftools expressions documentation](https://samtools.github.io/bcftools/bcftools.html#expressions) and configure custom filter expressions via the pipeline's module parameters.

### Dependencies

All dependencies are containerised in publicly available Docker/Singularity images.

## Software versions

Key software used by the `strain_mapper` sub-workflow:

| Software | Version | Image                                                  |
| -------- | ------- | ------------------------------------------------------ |
| Bowtie2  | 2.5.1   | `quay.io/biocontainers/bowtie2:2.5.1--py310h8d7afc0_0` |
| Samtools | 1.17    | `quay.io/biocontainers/samtools:1.17--hd87286a_2`      |
| Picard   | 3.1.1   | `quay.io/biocontainers/picard:3.1.1--hdfd78af_0`       |
| bcftools | 1.17    | `quay.io/biocontainers/bcftools:1.17--h3cc50cf_1`      |

See `assorted-sub-workflows/strain_mapper/modules/` for pinned container versions.

## Troubleshooting

- **Reference index not found**: the pipeline builds Bowtie2 and Samtools indexes if not already present alongside the reference file. Ensure the reference directory is writable.
- **iRODS authentication**: if using iRODS input, run `iinit` to authenticate before launching the pipeline.
- **Resuming a failed run**: add `-resume` to your command to restart from cached intermediate results.
- For further help, check `.nextflow.log` and the per-process logs in the `work/` directory.

## Issues and Contributions

If you find an issue with this pipeline, or would like to suggest an improvement, please log an issue or open a pull request on this repository.

If you are at Sanger and need internal support, you can raise an issue on the PAM Freshservice portal: https://sanger.freshservice.com/support/catalog/items/426
