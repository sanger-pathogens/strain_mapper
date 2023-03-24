process CURATE {
    label 'process_low'
    publishDir "${params.outdir}/final_mapping", mode: 'copy', overwrite: true

    container 'quay.io/biocontainers/python:3.10.2'

    input:
    tuple val(meta), file(vcf_final)
    path(ref_index)

    output:
    tuple val(meta), path("*.fa"),  emit: curated

    script:
    ref_basename = file(params.reference).baseName
    align_script = "${projectDir}/scripts/generate_consensus.py"
    """
    python3 ${align_script} -v '${vcf_final}' -i '${ref_index}' -o '${meta.id}_${ref_basename}.fa' -s '${meta.id}'
    """
}