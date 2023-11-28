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
        --only_report_alts           When included this flag reports only ALT variants in the VCF output. default = true (optional)
        --VCF_filters                Parameters for filtering variants in VCF file. Default is to removing records below 50 quality score 
                                      and also requiring 3 reads from each strand with overall greater than 8. 
                                      default = "QUAL>=50 & MIN(DP)>=8 & ((ALT!="." & DP4[2]>3 & DP4[3]>3) | (ALT="." & DP4[0]>3 & DP4[1]>3))" (optional)
        --skip_filtering             Do not filter variants called using `bcftools call` based on metrics defined with --VCF_filters.  default = false
        --keep_raw_vcf               Also publish the unfiltered VCF file i.e. direct output of `bcftools call`; can be combined with 
                                      --only_report_alts=false to report all (unfiltered, REF and ALT) variants; 
                                      only relevant when --skip_filtering=false; default = false
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
// SUBWORKFLOWS
//
include { INPUT_CHECK } from './subworkflows/input_check'
include { STRAIN_MAPPER } from './assorted-sub-workflows/strain_mapper/strain_mapper.nf'

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

    //
    // SUBWORKFLOW: actual processing; 
    // please refer to  the Nextflow subworkflow strain_mapper
    // in the submodule repository assorted-sub-workflows
    //
    STRAIN_MAPPER( ch_reads, reference )

}
/*
========================================================================================
    THE END
========================================================================================
*/
