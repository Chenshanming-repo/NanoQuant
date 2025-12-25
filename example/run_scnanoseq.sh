#!/bin/bash

SCNANOSEQ_DIR="/homeb/chensm/github_repos/scnanoseq"
REF_DIR="/homeb/chensm/reference/sc_ref/gencodev49"
OUTPUT_DIR="/homeb/chensm/expr/10x-genomics-process/lung_cancer/results"
DATA_DIR="/homeb/chensm/expr/10x-genomics-process/lung_cancer"

mkdir -p $OUTPUT_DIR

nextflow run $SCNANOSEQ_DIR -resume   \
  --input $DATA_DIR/samplesheet.csv \
  --outdir $OUTPUT_DIR \
  -params-file $DATA_DIR/params.yml \
  -c $DATA_DIR/custom.conf \
  -profile docker
