#! /bin/bash

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/main/ci-support.sh
source ci-support.sh

build_py_project_in_conda_env
setup_asv
clone_results_repo
run_asv
upload_benchmark_results
