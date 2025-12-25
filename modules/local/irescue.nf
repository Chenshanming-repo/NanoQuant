process IRESCUE {
    tag "$meta.id"
    label 'process_medium'

    container "quay.io/biocontainers/irescue:1.2.0--pyhdfd78af_0"

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("irescue_out/counts/*"), emit: matrix

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """

    irescue \\
        -b ${bam} \\
        -r ${params.te_bed} \\
        ${args}


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        irescue: \$(irescue --version 2>&1 || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    mkdir -p irescue_out/counts
    touch irescue_out/counts/barcodes.tsv.gz
    touch irescue_out/counts/features.tsv.gz
    touch irescue_out/counts/matrix.mtx.gz
    touch irescue_out/ec_dump.tsv.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        irescue: 0.0.0
    END_VERSIONS
    """
}

