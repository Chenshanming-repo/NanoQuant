process ASE_QUANT_MATRIX {
    tag "ase_quant_matrix"
    label 'process_medium'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker.io/chenshanming/scnanoquantsnp:v1.3' :
        'docker.io/chenshanming/scnanoquantsnp:v1.3' }"

    input:
    tuple val(meta), path(bam), path(bai), path(vcf), path(tbi)

    output:
    tuple val(meta), path("matrix/*"), emit: matrix

    script:
    """
    source activate base
    conda activate scNanoQuantSNPEnv
    mkdir matrix
    mkdir matrix_unsorted
    python /app/ASE_pysam.py --vcf_file $vcf \\
	--out_dir matrix_unsorted \\
	--gtf ${params.gtf} \\
        --bam $bam \\
        --threads ${task.cpus}
    python /app/sort_coo_matrix.py --in_dir matrix_unsorted --out_dir matrix

    """

    stub:
    """
    touch matrix/barcodes.tsv.gz
    touch matrix/features.tsv.gz
    touch matrix/matrix.mtx.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ase: 0.0.0
    END_VERSIONS
    """
}

