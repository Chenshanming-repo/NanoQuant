process CLAIR3_RNA_GENOTYPE {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker.io/hkubal/clair3-rna:latest' :
        'docker.io/hkubal/clair3-rna:latest' }"
    input:
    tuple val(meta), path(bam), path(bai), path(fasta), path(fai), path(vcf)

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

    def bam_name = bam.getName()
    def matcher = (bam_name =~ /TAG_CB_([A-Z]+)/)
    def uniq_id = matcher ? matcher[0][1] : "no_barcode" 

    """

    /opt/bin/run_clair3_rna \\
        --bam $bam \\
        --ref $fasta \\
        --platform ${params.clair3_rna_platform} \\
        --threads ${task.cpus} \\
        --output_dir $output_dir \\
	-G $vcf
        $args

    mv $output_dir/output.vcf.gz $output_dir/${uniq_id}.vcf.gz
    mv $output_dir/output.vcf.gz.tbi $output_dir/${uniq_id}.vcf.gz.tbi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        clair3_rna: \$(/opt/bin/run_clair3_rna --version)
    END_VERSIONS
    """

    stub:
    """
    touch ${prefix}.vcf
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        clair3_rna: 0.0.0
    END_VERSIONS
    """
}

