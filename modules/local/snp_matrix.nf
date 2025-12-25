process SNP_QUANT_MATRIX {
    tag "snp_quant_matrix"
    label 'process_medium'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker.io/scnanoquantsnp:v1.0' :
        'docker.io/scnanoquantsnp:v1.0' }"

    input:
    path(vcf_file)

    output:
    path "matrix/*", emit: matrix

    script:
    """
    source activate base
    conda activate scNanoQuantSNPEnv
    mkdir -p matrix

    python /app/make_snp_quant_matrix.py \\
        --vcf_file $vcf_file \\
        --out_dir matrix

    """
}

