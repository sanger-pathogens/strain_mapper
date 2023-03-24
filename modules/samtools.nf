process CONVERT_TO_BAM {
    label 'process_low'
    publishDir "${params.outdir}/samtools_view", mode: 'copy', overwrite: true

    container 'quay.io/biocontainers/samtools:1.16.1--h00cdaf9_2'

    input:
    tuple val(meta), file(mapped_reads)

    output:
    tuple val(meta), path("${mapped_reads_bam}"),  emit: mapped_reads_bam

    script:
    mapped_reads_bam = "${meta.id}.bam"
    """
    samtools view -@ ${task.cpus} \
                  -bS \
                  -o ${mapped_reads_bam} \
                  ${mapped_reads}
    """
}

process SAMTOOLS_SORT {
    label 'process_medium'
    publishDir "${params.outdir}/samtools_sort", mode: 'copy', overwrite: true

    container 'quay.io/biocontainers/samtools:1.16.1--h00cdaf9_2'

    input:
    tuple val(meta), file(mapped_reads_bam)

    output:
    tuple val(meta), path("${sorted_reads}"),  emit: sorted_reads

    script:
    sorted_reads = "${meta.id}_sorted.bam"
    """
    samtools sort -@ ${task.cpus} \
                  -o ${sorted_reads} \
                  ${mapped_reads_bam}
    """
}

process INDEX_REF {
    label 'process_low'
    publishDir "${params.outdir}/sorted_ref", mode: 'copy', overwrite: true

    container 'quay.io/biocontainers/samtools:1.16.1--h00cdaf9_2'

    input:
    path(reference)

    output:
    path("${faidx}"), emit: ref_index

    script:
    faidx = "${reference}.fai"
    """
    samtools faidx "${reference}" > "${faidx}"
    """
}