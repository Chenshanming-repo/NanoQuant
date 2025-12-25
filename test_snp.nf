nextflow.enable.dsl = 2

include { CALL_GENOTYPE_SNP } from './subworkflows/local/call_genotype_snp.nf'

meta = [id: 'test_sample']
//bam_file = file('/homeb/chensm/expr/10x-genomics-process/lung_cancer_chr22/LUNGCANCER_ONT.tagged.chr22.bam')
//bai_file = file('/homeb/chensm/expr/10x-genomics-process/lung_cancer_chr22/LUNGCANCER_ONT.tagged.chr22.bam.bai')
bam_file = file('/homeb/chensm/expr/10x-genomics-process/lung_cancer_chr20_chr22/LUNGCANCER_ONT.genome.dedup.bam') 
bai_file = file('/homeb/chensm/expr/10x-genomics-process/lung_cancer_chr20_chr22/LUNGCANCER_ONT.genome.dedup.bam.bai')
fasta_file = file('/homeb/chensm/reference/sc_ref/gencodev49/GRCh38.p14.genome.fa')
fai_file   = file('/homeb/chensm/reference/sc_ref/gencodev49/GRCh38.p14.genome.fa.fai')

input_ch = Channel.from([
    tuple(meta, bam_file, bai_file, fasta_file, fai_file)
])

workflow {

    results = CALL_GENOTYPE_SNP(input_ch)
    
    emit:
        results.merged_vcf
        results.snp_matrix
}
