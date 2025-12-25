process ISOSCELES {
    tag "$meta.id"
    label 'process_medium'

    container 'docker.io/chenshanming/scnanoquantisoform:v1.2'

    input:
        tuple val(meta), path(bam), path(bai), path(fasta), path(fai)

    output:
	tuple val(meta), path("output/isosceles/*"), emit: matrix

    script:
    """
    /opt/conda/envs/isoform-quant-pipeline/bin/Rscript /pipeline/methods/isosceles/run/run.r \\
        --reference-fasta  ${fasta} \\
        --reference-gtf    ${params.gtf} \\
        --sample-bam       ${bam} \\
        --output           ./output
    """

}

