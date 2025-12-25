nextflow.enable.dsl = 2

include { CLAIR3_RNA_CALL }        from '../../modules/local/clair3_rna_call.nf'
include { CLAIR3_RNA_GENOTYPE }        from '../../modules/local/clair3_rna_genotype.nf'
include { SAMTOOLS_VIEW }     from '../../modules/nf-core/samtools/view'
include { SAMTOOLS_IDXSTATS } from '../../modules/nf-core/samtools/idxstats'
include { SAMTOOLS_INDEX as SAMTOOLS_INDEX_BAM }    from '../../modules/nf-core/samtools/index'
include { SAMTOOLS_INDEX as SAMTOOLS_INDEX_SPLIT_BAM }    from '../../modules/nf-core/samtools/index'
include { SAMTOOLS_INDEX as SAMTOOLS_INDEX_PHASED_BAM }    from '../../modules/nf-core/samtools/index'
include { BCFTOOLS_CONCAT }    from '../../modules/nf-core/bcftools/concat'
include { SPLIT_BAM_BY_BARCODE }    from '../../modules/local/split_bam_by_barcode.nf'
include { MAKE_REGION_FILE } from '../../modules/local/make_region_file.nf'
include { SNP_QUANT_MATRIX } from '../../modules/local/snp_matrix.nf'
import java.nio.file.Files


def makeBAMwithBAI(indexed_bams_ch) {

    def bam_bai_ch = indexed_bams_ch.bam
        .join(indexed_bams_ch.bai)
    return bam_bai_ch
}

def buildClairInputChannel(indexed_bams_ch, keyed_input_ch) {

    def bam_bai_ch = indexed_bams_ch.bam
        .map { meta, bam -> tuple(meta.id, [meta, bam]) }
        .join(indexed_bams_ch.bai.map { meta, bai -> tuple(meta.id, [meta, bai]) }, by: [0])
        .map { id, bam_val, bai_val ->
            def (meta, bam) = bam_val
            def (_meta, bai) = bai_val
            tuple(id, [meta, bam, bai])
        }

    def grouped_bam_bai_ch = bam_bai_ch.groupTuple()

    def clair_input_ch = keyed_input_ch
        .join(grouped_bam_bai_ch)
        .flatMap { id, input_vals, bam_bai_list ->
            def (_meta, _bam, _bai, fasta, fai) = input_vals
            bam_bai_list.collect { bam_bai_vals ->
                def (meta, bam, bai) = bam_bai_vals
                tuple(meta, bam, bai, fasta, fai)
            }
        }

    return clair_input_ch
}

workflow QUANTIFY_SCRNA_SNP {

    take:
        // tuple(val(meta), path(bam), path(bai), path(fasta), path(fai))
        input_ch
    main:
        // ----------------------------
        // Step 1: 获取 contig 列表
        // ----------------------------
        idxstats_results_ch = SAMTOOLS_IDXSTATS(input_ch.map { meta, bam, bai, fasta, fai -> tuple(meta, bam, bai) } )

        contigs_ch = idxstats_results_ch.idxstats.map { meta, idxstats_file ->
            def contigs = []
            idxstats_file.eachLine { line ->
                def fields = line.split('\t')
                def contig = fields[0]
        	if (contig ==~ /^chr([1-9]|1[0-9]|2[0-2]|X|Y)$/ && 
            		fields[1].isInteger() && fields[2] != "0") {
            		contigs << contig
        	}
	    }
            tuple(meta, contigs)
        }
	.flatMap { meta, contig_list -> 
		contig_list.collect { ctg -> 
			def new_meta = meta.clone()
                	//new_meta.put("contig", ctg)
			tuple(new_meta, ctg)
		}
	}

        // ----------------------------
        // Step 2: 按 contig 拆分 BAM
        // ----------------------------
	
        region_ch = MAKE_REGION_FILE(contigs_ch)

	split_bams_ch = input_ch.cross(region_ch)
		.map { input_elem, region_elem ->  
			def (meta1, bam, bai, fasta, fai) = input_elem
			def (meta2, region_file) = region_elem
			tuple(meta1, bam, bai, fasta, fai, region_file)
		}
        input1_ch = split_bams_ch.map { meta, bam, bai, fasta, fai, region_file ->
            tuple(meta, bam, bai, region_file)
        }
        input2_ch = split_bams_ch.map { meta, bam, bai, fasta, fai, region_file ->
            tuple(meta, fasta)
        }
        input3_ch = split_bams_ch.map { meta, bam, bai, fasta, fai, region_file ->
            tuple(null)
        }
	
        split_bams_results = SAMTOOLS_VIEW(input1_ch, input2_ch, input3_ch)
	indexed_bams_ch = SAMTOOLS_INDEX_BAM(split_bams_results.bam)
	// ----------------------------
        // Step 3: Clair3-RNA（按 contig）
        // ----------------------------
	//indexed_bams_ch.bam.view()
	//indexed_bams_ch.bai.view()
	def bam_bai_ch = makeBAMwithBAI(indexed_bams_ch)
	clair_input_ch = input_ch.cross(bam_bai_ch)
		.map { input_elem, bam_bai_elem ->
                        def (meta1, _bam, _bai, fasta, fai) = input_elem
                        def (meta2, bam, bai) = bam_bai_elem
                        tuple(meta1, bam, bai, fasta, fai)
                }
	clair_results = CLAIR3_RNA_CALL(clair_input_ch)
        // ----------------------------
        // Step 4: 合并 VCF（每样本）
        // ----------------------------
        def vcf_grouped = clair_results.vcf.groupTuple()
        def tbi_grouped = clair_results.tbi.groupTuple()

        def merged_ch = vcf_grouped.join(tbi_grouped)
	
        merged_results = BCFTOOLS_CONCAT(
            merged_ch
        )

        // ----------------------------
        // Step 5: 按 barcode 拆分 BAM
        // ----------------------------
        barcode_split_results = SPLIT_BAM_BY_BARCODE(
            input_ch.map { meta, bam, bai, fasta, fai -> tuple(meta, bam) }
        )

	barcode_split_bams_ch = barcode_split_results.bam
	    .flatMap { meta, bam_list -> 
			bam_list.collect{ bam -> tuple(meta, bam) }	
		}
	
	indexed_barcode_bams_ch = SAMTOOLS_INDEX_SPLIT_BAM(barcode_split_bams_ch)

        // ----------------------------
        // Step 6: Clair3-rna genotype（按 barcode）
        // ----------------------------
	barcode_bam_bai_ch = makeBAMwithBAI(indexed_barcode_bams_ch)
	tmp_ch = input_ch.cross(barcode_bam_bai_ch)
                .map { input_elem, bam_bai_elem ->
                        def (meta1, _bam, _bai, fasta, fai) = input_elem
                        def (meta2, bam, bai) = bam_bai_elem
                        tuple(meta1, bam, bai, fasta, fai)
                }
	clair_gt_input_ch = merged_results.vcf.cross(tmp_ch)
		.map { merged_elem, last_elem ->
			def (meta1, bam, bai, fasta, fai) = last_elem
			def (meta2, vcf) = merged_elem
			tuple(meta1, bam, bai, fasta, fai, vcf)
		}

        def clair3_gt_output_ch = CLAIR3_RNA_GENOTYPE(clair_gt_input_ch)
	
	ch_str = Channel.of("sample1.vcf.gz", "sample2.vcf.gz", "sample3.vcf.gz")

	clair3_gt_output_ch.vcf
                .map { meta, vcf -> vcf }
    	.map { file_name -> "${file_name}\n" }  
    	.collectFile(name: "all_vcfs.txt")      
    	.set { all_vcf_file_ch }



	snp_quant_matrix_ch = SNP_QUANT_MATRIX(
    		all_vcf_file_ch
	)


       emit:
    		merged_vcf = merged_results.vcf
    		snp_matrix = snp_quant_matrix_ch.matrix
 
}

