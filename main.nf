#!/usr/bin/env nextflow

/*
========================================================================================
    HELP
========================================================================================
*/

def logo = NextflowTool.logo(workflow, params.monochrome_logs)

log.info logo

def printHelp()  {
    NextflowTool.help_message("${workflow.ProjectDir}/schema.json", ["${workflow.ProjectDir}/assorted-sub-workflows/irods_extractor/schema.json"],
    params.monochrome_logs, log)
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

    errors += validate_path_param("--reference", params.reference)

    if ((params.manifest_of_reads == "") || (params.manifest_of_lanes == "") || (params.studyid == -1)){
        log.error(String.format("No input provided; please spcify at least one of the following options: --manifest_of_reads, --manifest_of_lanes or --studyid", errors))
        errors += 1
    }

    if (errors > 0) {
        log.error(String.format("%d errors detected", errors))
        exit 1
    }
}

//validate_parameters()

/*
========================================================================================
    IMPORT MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// SUBWORKFLOWS
//
include { COMBINE_IRODS ; 
          COMBINE_READS   } from './assorted-sub-workflows/combined_input/subworkflows/combined_input.nf'
include { IRODS_EXTRACTOR } from './assorted-sub-workflows/irods_extractor/subworkflows/irods.nf'
include { STRAIN_MAPPER   } from './assorted-sub-workflows/strain_mapper/strain_mapper.nf'


/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow {

    //
    // REFERENCE PROCESSING 
    //
    reference = file(params.reference, checkIfExists: true)

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    COMBINE_IRODS
    | IRODS_EXTRACTOR
    | COMBINE_READS

    COMBINE_READS.out.all_reads_ready_to_map_ch.set{ all_reads_ready_to_map_ch }

    //
    // SUBWORKFLOW: actual processing; 
    // please refer to  the Nextflow subworkflow strain_mapper
    // in the submodule repository assorted-sub-workflows
    //

    STRAIN_MAPPER( all_reads_ready_to_map_ch, reference )

}
/*
========================================================================================
    THE END
========================================================================================
*/
