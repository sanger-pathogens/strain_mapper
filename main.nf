#!/usr/bin/env nextflow

/*
========================================================================================
    HELP
========================================================================================
*/

def printHelp() {
    log.info """
    Usage:
        nextflow run main.nf
    Options:
        --input                      Manifest containing per-sample paths to .fastq.gz files (mandatory)
        --reference                  Reference to map reads against (mandatory)
        --outdir                     Specify output directory [default: ./results] (optional)
        --only_report_alts           When included this flag reports only ALT variants in the VCF output. default = null (optional)
        --VCF_filters                Default filtering removing records below 50 quality score and also requiring 3 reads from each strand with overall greater than 8. default = "QUAL>=50 & MIN(DP)>=8 & DP4[2]>3 & DP4[3]>3" (optional)
        --skip_filtering             Do not generate a filtered output of the BCFTOOLS call vcf  default = false
        --help                       Print this help message (optional)
    """.stripIndent()
}

if (params.help) {
    printHelp()
    exit(0)
}

/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def validate_path_param(
    param_option, 
    param, 
    type="file", 
    mandatory=true) {
        valid_types=["file", "directory"]
        if (!valid_types.any { it == type }) {
                log.error("Invalid type '${type}'. Possibilities are ${valid_types}.")
                return 1
        }
        param_name = (param_option - "--").replaceAll("_", " ")
        if (param) {
            def file_param = file(param)
            if (!file_param.exists()) {
                log.error("The given ${param_name} '${param}' does not exist.")
                return 1
            } else if (
                (type == "file" && !file_param.isFile())
                ||
                (type == "directory" && !file_param.isDirectory())
            ) {
                log.error("The given ${param_name} '${param}' is not a ${type}.")
                return 1
            }
        } else if (mandatory) {
            log.error("No ${param_name} specified. Please specify one using the ${param_option} option.")
            return 1
        }
        return 0
    }

def validate_parameters() {
    def errors = 0

    errors += validate_path_param("--input", params.input)
    errors += validate_path_param("--reference", params.reference)

    if (errors > 0) {
        log.error(String.format("%d errors detected", errors))
        exit 1
    }
}

validate_parameters()

/*
========================================================================================
    IMPORT MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES
//
include { BOWTIE2; BOWTIE2_INDEX } from './modules/bowtie2'
include { CONVERT_TO_BAM; SAMTOOLS_SORT; INDEX_REF } from './modules/samtools'
include { BCFTOOLS_CALL; BCFTOOLS_MPILEUP; FINAL_VCF } from './modules/bcftools'
include { CURATE_CONSENSUS } from './modules/curate'

//
// SUBWORKFLOWS
//
include { INPUT_CHECK } from './subworkflows/input_check'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow {

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    ch_input = file(params.input)
    INPUT_CHECK (
        ch_input
    )
    INPUT_CHECK.out.shortreads
        .dump(tag: 'ch_reads')
        .set { ch_reads }

    //
    // REFERENCE PROCESSING 
    //
    reference = file(params.reference, checkIfExists: true)

    // BOWTIE2 INDEX
    ref_without_extension = "${reference.parent}/${reference.baseName}"
    bt2_index_files = file("${ref_without_extension}*.bt2")
    if (bt2_index_files) {
        Channel.fromPath(bt2_index_files)
            .collect()
            .dump(tag: 'bt2_index')
            .set { ch_bt2_index }
    } else {
        BOWTIE2_INDEX(
            reference
        )
        BOWTIE2_INDEX.out.bt2_index.dump(tag: 'bt2_index').set { ch_bt2_index }
    }

    // INDEX REF FASTA
    faidx_file = file("${reference}.fai")
    if (faidx_file.isFile()) {
        Channel.of( [reference, faidx_file] ).dump(tag: 'ref_index').set { ch_ref_index }
    } else {
        INDEX_REF(
            reference
        )
        INDEX_REF.out.ref_index.dump(tag: 'ref_index').set { ch_ref_index }
    }
    
    //
    // MAPPING: Bowtie2
    //
    BOWTIE2 (
        ch_reads,
        ch_bt2_index 
    )
    BOWTIE2.out.mapped_reads.dump(tag: 'bowtie2').set { ch_mapped }

    //
    // POST-PROCESSING
    //
    CONVERT_TO_BAM(
        ch_mapped
    )
    CONVERT_TO_BAM.out.mapped_reads_bam.dump(tag: 'convert_to_bam').set { ch_mapped_reads_bam }

    SAMTOOLS_SORT(
        ch_mapped_reads_bam
    )
    SAMTOOLS_SORT.out.sorted_reads.dump(tag: 'sorted_reads').set { ch_sorted_reads }

    ch_sorted_reads
        .combine(ch_ref_index)
        .dump(tag: 'sorted_reads_and_ref')
        .set { sorted_reads_and_ref }

    BCFTOOLS_MPILEUP(
        sorted_reads_and_ref
    )
    BCFTOOLS_MPILEUP.out.mpileup_file.dump(tag: 'mpileup_file').set { ch_mpileup_file }

    BCFTOOLS_CALL(
        ch_mpileup_file
    )
    BCFTOOLS_CALL.out.vcf_final.dump(tag: 'vcf_final').set { ch_vcf_final }

    if (keep_raw_vcf == true){
        RAW_VCF(
            ch_vcf_final
        )
    }

    if (!params.skip_filtering) {
        BCFTOOLS_FILTERING(
            ch_vcf_final
        )
    }

    FINAL_VCF(ch_vcf_final)

    ch_vcf_final
        .combine(ch_ref_index)
        .dump(tag: 'vcf_and_ref')
        .set { ch_vcf_and_ref }

    CURATE_CONSENSUS(
        ch_vcf_and_ref
    )
    CURATE_CONSENSUS.out.curated.dump(tag: 'curated_consensus').set { ch_curated }
}

/*
========================================================================================
    THE END
========================================================================================
*/
