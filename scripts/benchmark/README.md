## Scripts for benchmarking of read mapping/variant calling pipeline results

### Set up required dependencies

```
conda create -n plotlibs matplotlib pysam biopython
```

### Usage
```
conda activate plotlibs
python3 strain_mapper/scripts/benchmark/compare_consensus.py \
  -1 mm2b_no_indel/31663_7#10_BWA/31663_7#10.mfa \
  -2 results/31663_7#10/curated_consensus/31663_7#10_Streptococcus_agalactiae_NGBS128_GCF_001552035_1.fa \
  -m 'mm2b' -M 'sm-bwa'
```