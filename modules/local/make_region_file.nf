process MAKE_REGION_FILE {

    tag "$meta.id"
    label 'process_medium'
    
    input:
    tuple val(meta), val(contig_name)

    output:
    tuple val(meta), path("*.txt"), emit: regionFile

    script:
    """
	echo "${contig_name}" > ${contig_name}.region.txt
    """
}

