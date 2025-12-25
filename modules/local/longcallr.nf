process LONGCALLR {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker.io/chenshanming/longcallr:v1.20-ps' :
        'docker.io/chenshanming/longcallr:v1.20-ps' }"
    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("*.phased.bam"), emit: phased_bam
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def output_dir = "${prefix}_clair3_rna_output"

    def bam_name = bam.getName()
    def matcher = (bam_name =~ /TAG_CB_([A-Z]+)/)
    def uniq_id = matcher ? matcher[0][1] : "no_barcode" 

    """
    longcallR -b $bam -f ${params.fasta_path} -o ${uniq_id}  -t $task.cpus -p ${params.longcallr_platform} 

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        longcallR: v1.20
    END_VERSIONS
    """

    stub:
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        longcallR: v1.20
    END_VERSIONS
    """
}

