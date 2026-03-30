process BARCODE_OPTIM {
    tag "$meta.id"
    label 'process_high'

    container "docker.io/chenshanming/barcode_optim:latest"

    input:
    tuple val(meta), path(reads)
    path fasta
    path gtf

    output:
    tuple val(meta), path("*.whitelist.csv")             , emit: whitelist
    tuple val(meta), path("*.putative_bc.no_header.csv") , emit: putative_bc
    tuple val(meta), path("*.bc_count.txt")              , emit: bc_count
    path "versions.yml"                                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args       = task.ext.args ?: ''
    def prefix     = task.ext.prefix ?: "${meta.id}"

    def raw_format = params.barcode_format ? params.barcode_format.toString().trim() : ""
    
    def barcode_format_ver = raw_format.replaceFirst(/^(?i)["']?10x_/, "").replaceFirst(/["']$/, "")
    """
    python /app/barcode_optim/main.py \\
        --auto-detect-cells \\
        --threads $task.cpus \\
        --output-prefix ${prefix}_ \\
        --do-alignment \\
        --do-isoquant \\
        --do-post-isoquant \\
        --reference-fasta ${fasta} \\
        --genedb ${gtf} \\
	--10x-kit-version ${barcode_format_ver} \\
        --isoquant-output isoquant_sc \\
        --isoquant-threads $task.cpus \\
        ${args} \\
        ${reads}

    # 1. Map algorithm output to BLAZE compatible names
    if [ -f "${prefix}_whitelist.csv" ]; then
        mv ${prefix}_whitelist.csv ${prefix}.whitelist.csv
    else
        touch ${prefix}.whitelist.csv
    fi

    # 2. Process Putative BC (remove header)
    if [ -f "${prefix}_putative_bc.csv" ]; then
        tail -n +2 ${prefix}_putative_bc.csv > ${prefix}.putative_bc.no_header.csv
    else
        touch ${prefix}.putative_bc.no_header.csv
    fi

    # 3. Generate BC Count file (format: barcode,count)
    if [ -s "${prefix}.putative_bc.no_header.csv" ]; then
        cat ${prefix}.putative_bc.no_header.csv | \\
            cut -f2 -d',' | \\
            sort -T \$(pwd) | \\
            uniq -c | \\
            awk '{print \$2","\$1}' > ${prefix}.bc_count.txt
    else
        touch ${prefix}.bc_count.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        barcode_optim: "1.0.0"
    END_VERSIONS
    """
}
