process BCFTOOLS_MPILEUP {
    label 'cpu_2'
    label 'mem_1'
    label 'time_1'

    publishDir "${params.outdir}/bcftools_mpileup", mode: 'copy', overwrite: true

    container 'quay.io/biocontainers/bcftools:1.16--haef29d1_2'

    input:
    tuple val(meta), path(sorted_reads), path(reference), path(reference_index)

    output:
    tuple val(meta), path("${mpileup_file}"),  emit: mpileup_file

    script:
    mpileup_file = "${meta.id}.mpileup"
    """
    bcftools mpileup -o ${mpileup_file} \
                     -O 'u' \
                     -f ${reference} \
                     ${sorted_reads} 
    """
}

process BCFTOOLS_CALL {
    label 'cpu_2'
    label 'mem_1'
    label 'time_1'

    publishDir "${params.outdir}/bcftools_call", mode: 'copy', overwrite: true

    container 'quay.io/biocontainers/bcftools:1.16--haef29d1_2'

    input:
    tuple val(meta), file(mpileup_file)

    output:
    tuple val(meta), path("${vcf_final}"),  emit: vcf_final

    script:
    vcf_final = "${meta.id}.vcf"
    """
    bcftools call -o ${vcf_final} \
                  -O 'v' \
                  -V indels \
                  -m \
                  '${mpileup_file}'
    """
}