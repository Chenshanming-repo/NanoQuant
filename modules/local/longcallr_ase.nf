process LONGCALLR_ASE {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker.io/chenshanming/longcallr:v1.20-ps' :
        'docker.io/chenshanming/longcallr:v1.20-ps' }"
    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("*/*.vcf.gz"), emit: vcf
    tuple val(meta), path("*/*.vcf.gz.tbi"), emit: tbi
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def output_dir = "${prefix}_clair3_rna_output"

    def barcode = bam.getBaseName().replace('.phased','') 

    """
    longcallR-ase -b ${barcode}.phased.bam  -a ${params.gtf_path} -o ${barcode} -t $task.cpus

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        longcallR: v1.20
    END_VERSIONS
    """

    stub:
    """
    touch ${prefix}.vcf
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        longcallR: 0.0.0
    END_VERSIONS
    """
}

