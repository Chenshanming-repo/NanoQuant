process WHATSHAP_GENOTYPE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://jlalli/whatshap:2.1' :
        'jlalli/whatshap:2.1' }"

    input:
    tuple val(meta), path(merged_vcf), path(bam), path(bai)

    output:
    tuple val(meta), path("*.genotype.vcf"), emit: genotype_vcf

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    export HOME=\$(pwd)

    whatshap genotype \\
        --output ${prefix}.genotype.vcf \\
        --reference ${bam} \\
        ${merged_vcf} \\
        ${bam} \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        whatshap: \$(whatshap --version)
    END_VERSIONS
    """

    stub:
    """
    touch ${prefix}.genotype.vcf
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        whatshap: 0.0.0
    END_VERSIONS
    """
}

