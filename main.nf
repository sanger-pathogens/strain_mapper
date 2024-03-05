#!/usr/bin/env nextflow

/*
========================================================================================
    HELP
========================================================================================
*/

def logo = NextflowTool.logo(workflow, params.monochrome_logs)

log.info logo


def printHelp() {
    NextflowTool.help_message("${workflow.ProjectDir}/schema.json", 
                               ["${workflow.ProjectDir}/assorted-sub-workflows/combined_input/schema.json",
                                "${workflow.ProjectDir}/assorted-sub-workflows/irods_extractor/schema.json",
                                "${workflow.ProjectDir}/assorted-sub-workflows/strain_mapper/schema.json"],
    params.monochrome_logs, log)
}

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
    if (params.help) {
        printHelp()
        exit 0
    }

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

workflow.onComplete {
        NextflowTool.summary(workflow, params, log)
}
/*
========================================================================================
    THE END
========================================================================================
*/
