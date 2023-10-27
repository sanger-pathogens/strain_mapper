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
    if ( params.only_report_alts == true )
        """
        bcftools call -o ${vcf_final} \
            -O 'v' \
            -V indels \
            -m \
            -v \
            '${mpileup_file}'
        """
    else
        """
        bcftools call -o ${vcf_final} \
            -O 'v' \
            -V indels \
            -m \
            '${mpileup_file}'
        """
}

process BCFTOOLS_FILTERING {
    label 'cpu_2'
    label 'mem_1'
    label 'time_1'

    publishDir "${params.outdir}/bcftools_filter", mode: 'copy', overwrite: true

    container 'quay.io/biocontainers/bcftools:1.16--haef29d1_2'

    input:
    tuple val(meta), file(vcf_final)

    output:
    tuple val(meta), path("${filtered_vcf_final}"),  emit: filtered_vcf_final

    script:
    filtered_vcf_final = "${meta.id}_filtered.vcf"
    """
    bcftools view -o ${filtered_vcf_final} \
                  -O 'v' \
                  -i '${params.VCF_filters}' \
                  '${vcf_final}'
    """
}