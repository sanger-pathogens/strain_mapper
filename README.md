# Strain Mapper

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A521.04.0-23aa62.svg?labelColor=000000)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

[[_TOC_]]

## Pipeline overview

Strain Mapper is a Nextflow DSL2 pipeline for mapping short-read bacterial sequencing data to a reference genome and calling variants. Starting from paired FASTQ files, it produces per-sample VCF files and consensus FASTA sequences.

The pipeline performs the following steps:

1. **Reference indexing** — Bowtie2 and Samtools indexes are built for each reference used in the run, if not already present in the same directory. Samples can share one reference or be mapped against different references (see [Reference input](#reference-input)).
2. **Mapping** — reads are aligned to the reference with [Bowtie2](https://github.com/benlangmead/bowtie2).
3. **SAM → BAM processing** — the alignment is converted to sorted, indexed BAM; duplicate reads are marked with [Picard](https://github.com/broadinstitute/picard).
4. **Variant calling** — [BCFtools'](https://samtools.github.io/bcftools/) `mpileup` generates genotype likelihoods and `bcftools call` calls variants.
5. **Variant filtering** — variants are classified as `PASS`, `Het` (heterozygous), or `LowQual` based on quality, strand support, and coverage thresholds.
6. **Consensus** — a consensus FASTA sequence is generated from the PASS variants.

Default quality filters applied during variant filtering:

| Filter                                | Threshold                    |
| ------------------------------------- | ---------------------------- |
| Minimum quality (QUAL)                | ≥ 50                         |
| Minimum forward strand reads (ADF[0]) | ≥ 3                          |
| Minimum reverse strand reads (ADR[0]) | ≥ 3                          |
| Minimum total depth (DP)              | ≥ 8                          |
| Genotype                              | Homozygous only (0/0 or 1/1) |

### Quickstart

#### From source code

1. Clone this repository:

   ```bash
   git clone --recurse-submodules https://github.com/sanger-pathogens/strain_mapper.git && \
     cd strain_mapper && \
     git submodule init
   ```

2. To run with Docker containers, use the `-profile docker` option:

   ```bash
   nextflow run main.nf -profile docker [options]
   ```

   Similarly, the `singularity` profile enables support for Singularity/Apptainer containers.

   :warning: If no profile is specified the pipeline will run with the Sanger HPC-specific configuration. Non-Sanger users should use either `docker` or `singularity` profiles

3. Once the run has finished successfully and you have inspected the output, clean up intermediate files. The `work/` directory and `.nextflow.log` are useful for troubleshooting — do not delete them until you are satisfied the outputs are correct:

   ```bash
   rm -rf work .nextflow*
   ```

   Alternatively, use `nextflow clean` for more fine-grained control over which runs and intermediate files are removed.

#### Using on the Sanger "farm" HPC

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
jobname="my_strain_mapper_run" # you can edit this!
bsub -o ${jobname}.%J.o -e ${jobname}.%J.e -q oversubscribed -J ${jobname} -R "select[mem>4000] rusage[mem=4000]" -M4000 \
    strain-mapper [options]
```

#### From code archive downloaded from the Github Release section or from Zenodo

Please be aware that the code archive asset attached to a release will have empty folders for the dependcy submodules `assorted-sub-workflows` ([repository](https://github.com/sanger-pathogens/assorted-sub-workflows)) and `lib` (points to `nextflowtool` [repository](https://github.com/sanger-pathogens/nextflowtool)). The code executed from these archives will therefore **NOT** be functional. Unfortunately, the `.git` folder will be missing too, meaning that it is not a working `git` repository and submodule folders _cannot_ be populated with `git submodule init`.

It is thus recommended to use the `git clone` approach described above, adding the commands below to get the code version referred to in the release:

```bash
git checkout <revision_tag> # e.g. revision_tag can be "v1.8.1"
git pull --recurse-submodules
```

### General usage

This pipeline requires a few mandatory options, outlined below:

```sh
nextflow run main.nf  \
        --manifest manifest.csv \
        --outdir "results" \
        --reference generic_reference.fa \
        --reference_manifest sample_specific_references.fa
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

#### Reference input

Every sample must have a reference to map against. There are two ways to supply one, and they can be combined:

- **One reference for the whole run (`--reference`)** — a path to a single reference FASTA, applied to every sample.
- **A reference per sample (`--reference_manifest`)** — a CSV with the required header `ID,reference`, assigning a specific reference to individual samples:

  ```
  ID,reference
  sampleA,/path/to/strain_1.fasta
  sampleB,/path/to/strain_2.fasta
  ```

  `ID` must match a sample ID from the reads input. Reference paths are validated up front and the run fails immediately if one is missing. `NA` means the sample has no specific reference and falls back to `--reference`.

At least one of the two options is required. A sample listed in the reference manifest is mapped against its own reference; any sample not listed is mapped against `--reference`. Samples with neither are dropped from the run (with a warning), so supply `--reference` as a fallback unless you intend to process only the manifested samples.

Each distinct reference is indexed once, regardless of how many samples use it. Consensus FASTA filenames include the reference they were called against, so results from a multi-reference run remain distinguishable.

For the full description of this feature, including index reuse rules and known limitations, see the [strain_mapper sub-workflow README](assorted-sub-workflows/strain_mapper/README.md).

### Output

Results are written to `--outdir` (default: `./results`):

```
results/
  bowtie2/                                          # Bowtie2 index files (if --mapper bowtie2 and index was built by the pipeline)
  bwa/                                              # BWA index files (if --mapper bwa and index was built by the pipeline)
  sorted_ref/                                       # Reference FASTA index (.fai)
  <sample_ID>/
    vcf/
      <sample_ID>.vcf.gz                            # Final compressed VCF (all sites or alt-only)
      heterozygous_sites/
        <sample_ID>_heterozygous_sites.vcf.gz       # Heterozygous sites extracted from filtered VCF
    curated_consensus/
      <sample_ID>_<reference>.fa                    # Consensus FASTA sequence
    samtools_sort/                                  # Sorted BAM and index (if --keep_sorted_bam)
      <sample_ID>_sorted.bam
      <sample_ID>_sorted.bai
    picard/                                         # Deduplicated BAM (if --keep_dedup_bam)
      <sample_ID>_duplicates_removed.bam
      <sample_ID>_duplicates_removed.bai
    samtools_stats/                                 # SAMtools stats and flagstats (if --samtools_stats)
      <sample_ID>.stats
      <sample_ID>.flagstats
    deeptools_bigwigs/                              # BigWig coverage track (if --bigwig)
      <sample_ID>.bw
```

### Parameters

**Sequencing reads input options**

Multiple input options are available, and can be combined. Providing at least one is mandatory.

| Option                                          | Type   | Default | Description                                                                                                                                                                                                                   |
| ----------------------------------------------- | ------ | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--manifest_of_reads`                           | `path` | `null`  | Input manifest CSV with required header `ID,R1,R2`.                                                                                                                                                                           |
| `--manifest`                                    | `path` | `null`  | Same as `--manifest_of_reads` (alias).                                                                                                                                                                                        |
| `--manifest_of_lanes`                           | `path` | `null`  | **Sanger users only:** Input manifest CSV for submission of multiple iRODS (meta)data queries; various header fields can be used that refer to iRODS metadata fields, including `sudyid`,`runid`,`laneid`,`plexid` or `type`. |
| `--manifest_ena`                                | `path` | `null`  | Input manifest for submission of multiple ENA (meta)data queries; no header required, the only required content should be ENA accessions, one per line. This option should be accopanied by the `--accession_type` option.    |
| `--accession_type`                              | `str`  | `"run"` | One of the following types: `run`, `study`, `sample`.                                                                                                                                                                         |
| `--manifest_from_dir`                           | `path` | `null`  | Path to a folder containing paired Fastq files; file pairing will be done automatically; see help message from [the executed script](./assorted-sub-workflows/mixed_input/bin/generate_manifest.py).                          |
| `sudyid`,`runid`,`laneid`,`plexid`, `type`, ... | `str`  | `null`  | **Sanger users only:** Individual fields to be combined to form a single iRODS query (similar syntax as with `--manifest_of_lanes`, but resulting in a separate, additional query).                                           |

For more information, please read [the MIXED_INPUT workflow documentation](./assorted-sub-workflows/README.md).

---

**Reference input options**

At least one of these is required.

| Option                 | Type   | Default | Description                                                                                                                                                            |
| ---------------------- | ------ | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--reference`          | `path` | `null`  | Path to a reference FASTA file, used for every sample that has no entry in `--reference_manifest`.                                                                     |
| `--reference_manifest` | `path` | `null`  | Manifest CSV with header `ID,reference`, assigning a reference FASTA per sample ID. Samples not listed fall back to `--reference`. Use `NA` to leave a row unassigned. |

---

**Output options**

| Option          | Type      | Default     | Description                                                                                            |
| --------------- | --------- | ----------- | ------------------------------------------------------------------------------------------------------ |
| `--outdir`      | `path`.   | `./results` | Directory where results are written.                                                                   |
| `--save_fastqc` | `boolean` | `false`     | Save individual FastQC report (both pre- and post-filtering; redundant with combined MultiQC reports). |

---

**Mapping options**

| Option                      | Type      | Default                                                                                             | Description                                                                                                                                                                                         |
| --------------------------- | --------- | --------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--mapper`                  | `string`  | `bowtie2`                                                                                           | Mapping tool to use. Options: bwa, bowtie2                                                                                                                                                          |
| `--minimum_base_quality`    | `int`     | `20`                                                                                                | Minimum quality of a base for it to be carried forwards into the pileup and downstream to variant calling                                                                                           |
| `--only_report_alts`        | `boolean` | `true`                                                                                              | Only include ALT variants in the VCF output. Set false to also report reference-matching sites (REF).                                                                                               |
| `--VCF_filters`             | `string`  | `QUAL>=50 & MIN(DP)>=8 & ((ALT!=\".\" & DP4[2]>3 & DP4[3]>3) \| (ALT=\".\" & DP4[0]>3 & DP4[1]>3))` | bcftools expression for filtering VCF records. By default, retains only sites with quality scores of 50 or more, read depth of 8 or more, and at least 4 reads per strand supporting the call.      |
| `--skip_filtering`          | `boolean` | `false`                                                                                             | Do not filter variants called using `bcftools call` based on metrics defined with `--VCF_filters`.                                                                                                  |
| `--keep_raw_vcf`            | `boolean` | `false`                                                                                             | Save the unfiltered VCF generated directly by bcftools call. Can be combined with `--only_report_alts false` to report all called sites (REF and ALT). Only relevant when `--skip_filtering false`. |
| `--keep_sorted_bam`         | `boolean` | `false`                                                                                             | Save the mapping file (sorted BAM) and its index (.bai file).                                                                                                                                       |
| `--keep_dedup_bam`          | `boolean` | `false`                                                                                             | Save the mapping file (sorted, then deduplicated BAM) generated with Picardtools.                                                                                                                   |
| `--skip_read_deduplication` | `boolean` | `false`                                                                                             | Skip removal of duplicate reads using Picard.                                                                                                                                                       |
| `--bigwig`                  | `boolean` | `false`                                                                                             | Produce BigWig genome coverage file from sorted BAM file using Deeptools. Saves the BAM index (.bai) file alongside.                                                                                |
| `--samtools_stats`          | `boolean` | `false`                                                                                             | Produce statistics summary files from sorted BAM using `samtools stats` and `samtools flagstat` commands.                                                                                           |
| `--skip_cleanup`            | `boolean` | `true`                                                                                              | Retain intermediate files that would by default be deleted after successful pipeline completion.                                                                                                    |

---

**Logging options**

| Option              | Type      | Default | Description                 |
| ------------------- | --------- | ------- | --------------------------- |
| `--monochrome_logs` | `boolean` | `false` | Output logs in plain ASCII. |

### Advanced usage

#### Customising variant filters

Variant filters are applied via a bcftools expression. To modify the default thresholds, refer to the [bcftools expressions documentation](https://samtools.github.io/bcftools/bcftools.html#expressions) and configure custom filter expressions via the pipeline's module parameters.

### Dependencies

All dependencies are containerised in publicly available images.

## Software versions

| Software | Version | Image                                                  |
| -------- | ------- | ------------------------------------------------------ |
| Bowtie2  | 2.5.1   | `quay.io/biocontainers/bowtie2:2.5.1--py310h8d7afc0_0` |
| Samtools | 1.22    | `quay.io/biocontainers/samtools:1.22--h96c455f_0`      |
| Picard   | 3.1.1   | `quay.io/biocontainers/picard:3.1.1--hdfd78af_0`       |
| bcftools | 1.17    | `quay.io/biocontainers/bcftools:1.17--h3cc50cf_1`      |

See `assorted-sub-workflows/strain_mapper/modules/` for pinned container versions.

## Troubleshooting

- **iRODS authentication**: if using iRODS input, run `iinit` to authenticate before launching the pipeline.
- **Resuming a failed run**: add `-resume` to your command to restart from cached intermediate results.

For further help, check `.nextflow.log` and the per-process `.command.log` logs in the `work/` directory.

Sanger users may find [this page](https://ssg-confluence.internal.sanger.ac.uk/spaces/PaMI/pages/181078206/General+pipeline+info#Generalpipelineinfo-Troubleshootingafailedpipelinerunandsendingabugreport) useful for troubleshooting Nextflow pipeline runs.

## Issues and Contributions

Strain Mapper's workflow was originally produced by Marta Matuszewska and adapted into a Nextflow pipeline by PAM Informatics.

**GitHub users:** if you find an issue with this pipeline, or would like to suggest an improvement, please log an issue or open a pull request on this repository.

**Sanger users:** if you need internal support, you can raise an issue on the PAM Freshservice portal: https://sanger.freshservice.com/support/catalog/items/426
