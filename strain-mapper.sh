#!/usr/bin/env bash

THIS_DIR=$(dirname -- "${BASH_SOURCE[0]}")

nextflow run ${THIS_DIR}/main.nf
