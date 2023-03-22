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
include { BCFTOOLS_CALL; BCFTOOLS_MPILEUP } from './modules/bcftools'
include { CURATE } from './modules/curate'

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
    reference = file(params.reference, checkIfExists: true)
    // reference_dir = file(params.reference, checkIfExists: true).getParent()
    // index_files = file(reference_dir, "*.bt2")
    ch_input = file(params.input)
    INPUT_CHECK (
        ch_input
    )
    INPUT_CHECK.out.shortreads.dump(tag: 'shortreads')
        .map{ meta, reads -> tuple(meta, reads, reference) }
        .dump(tag: 'ch_for_mapping')
        .set { ch_for_mapping }
    INPUT_CHECK.out.shortreads
        .dump(tag: 'ch_reads')
        .set { ch_reads }

    // BOWTIE2 INDEX
    ref_without_extension = "${reference.parent}/${reference.baseName}"
    bt2_index_files = file("${ref_without_extension}*.bt2")
    if (bt2_index_files) {
        Channel.fromPath(bt2_index_files)
            .collect()
            .map { bt2_index_files -> tuple(ref_without_extension, bt2_index_files) }
            .dump(tag: 'bt2_index')
            .set { ch_bt2_index }
    } else {
        BOWTIE2_INDEX(
            reference
        )
        BOWTIE2_INDEX.out.bt2_index.dump(tag: 'bt2_index').set { ch_bt2_index }
    }

    // MAPPING: Bowtie2
    BOWTIE2 (
        ch_reads,
        ch_bt2_index 
    )
    BOWTIE2.out.mapped_reads.dump(tag: 'bowtie2').set { ch_mapped }

    // SORT REFERENCE AND GET CHROM LENGTH
    // SORT_REF(
    //     reference
    // )
    // SORT_REF.out.sorted_ref.dump(tag: 'sorted_ref').set { ch_sorted_ref }
    // SORT_REF.out.ref_length.dump(tag: 'raw_ref_length')
    //     .map { raw_length -> raw_length.trim() }
    //     .dump(tag: 'ref_length')
    //     .set { ch_ref_length }
    //// or...
    // GET_CHROM_ID_AND_SIZE(
    //     reference
    // )
    // GET_CHROM_ID_AND_SIZE.out.stdout.dump(tag: 'stdout_get_chrom_id_and_size')
    //     .map { stdout -> stdout.trim().split() }
    //     .map { elems -> ['seq_id':elems[0], 'size':elems[1]] }
    //     .dump(tag: 'chrom_id_and_size')
    //     .set { chrom_id_and_size }

    // INDEX REF FASTA
    faidx_file = file("${reference}.fai")
    if (faidx_file.isFile()) {
        Channel.fromPath(faidx_file).set { ch_ref_index }
    } else {
        INDEX_REF(
            reference
        )
        INDEX_REF.out.ref_index.dump(tag: 'ref_index').set { ch_ref_index }
    }
    

    // POST-PROCESSING
    CONVERT_TO_BAM(
        ch_mapped
    )
    CONVERT_TO_BAM.out.mapped_reads_bam.dump(tag: 'convert_to_bam').set { ch_mapped_reads_bam }

    SAMTOOLS_SORT(
        ch_mapped_reads_bam
    )
    SAMTOOLS_SORT.out.sorted_reads.dump(tag: 'sorted_reads').set { ch_sorted_reads }

    BCFTOOLS_MPILEUP(
        ch_sorted_reads,
        Channel.fromPath(reference)
    )
    BCFTOOLS_MPILEUP.out.mpileup_file.dump(tag: 'mpileup_file').set { ch_mpileup_file }

    BCFTOOLS_CALL(
        ch_mpileup_file
    )
    BCFTOOLS_CALL.out.vcf_final.dump(tag: 'vcf_final').set { ch_vcf_final }

    CURATE(
        ch_vcf_final, ch_ref_index
    )
    CURATE.out.curated.dump(tag: 'curated').set { ch_curated }
}

/*
========================================================================================
    THE END
========================================================================================
*/
