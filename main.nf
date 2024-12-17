#!/usr/bin/env nextflow

/*
========================================================================================
    HELP
========================================================================================
*/

def logo = NextflowTool.logo(workflow, params.monochrome_logs)

log.info logo

NextflowTool.commandLineParams(workflow.commandLine, log, params.monochrome_logs)


def printHelp() {
    NextflowTool.help_message("${workflow.ProjectDir}/schema.json", 
                               ["${workflow.ProjectDir}/assorted-sub-workflows/mixed_input/schema.json",
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
include { MIXED_INPUT       } from './assorted-sub-workflows/mixed_input/mixed_input.nf'
include { IRODS_EXTRACTOR   } from './assorted-sub-workflows/irods_extractor/subworkflows/irods.nf'
include { STRAIN_MAPPER     } from './assorted-sub-workflows/strain_mapper/strain_mapper.nf'


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

    MIXED_INPUT
    | set{all_reads_ready_to_map_ch}

    //
    // SUBWORKFLOW: actual processing; 
    // please refer to  the Nextflow subworkflow strain_mapper
    // in the submodule repository assorted-sub-workflows
    //

    STRAIN_MAPPER( all_reads_ready_to_map_ch, reference )
}

workflow.onComplete {
        NextflowTool.summary(workflow, params, log)

        log.info """
                To rerun from ${workflow.launchDir}:
                bsub -q oversubscribed -R "select[mem>4000] rusage[mem=4000]" -M4000 -o ${workflow.runName}_repeat.o -e ${workflow.runName}_repeat.e -J ${workflow.runName}_repeat ${workflow.commandLine}
                """
}
/*
========================================================================================
    THE END
========================================================================================
*/
