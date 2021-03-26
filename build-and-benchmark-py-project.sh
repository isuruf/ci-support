#! /bin/bash

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/main/ci-support.sh
source ci-support.sh

build_py_project_in_conda_env

# See https://github.com/airspeed-velocity/asv/pull/965
pip install git+https://github.com/airspeed-velocity/asv@ef016e233cb9a0b19d517135104f49e0a3c380e9#egg=asv

conda list

if [[ -z "$PROJECT" ]]; then
    echo "PROJECT env var not set"
    exit 1
fi

if [[ -z "$PYOPENCL_TEST" ]]; then
    echo "PYOPENCL_TEST env var not set"
    exit 1
fi

mkdir -p ~/.$PROJECT/asv/results

if [[ ! -z "$CI" ]]; then
  mkdir -p .asv/env
  if [[ "$CI_PROJECT_NAMESPACE" == "inducer" ]]; then
    ln -s ~/.$PROJECT/asv/results .asv/results
  else
    # Copy, so that the original folder is not changed.
    cp -r ~/.$PROJECT/asv/results .asv/results
  fi
  rm -rf .asv/env

  # Fetch the origin/main branch and setup main to track origin/main
  git fetch origin main || true
  git branch main origin/main -f
fi

if [[ ! -f ~/.asv-machine.json ]]; then
  asv machine --yes
fi

main_commit=`git rev-parse main`
test_commit=`git rev-parse HEAD`

# cf. https://github.com/pandas-dev/pandas/pull/25237
# for reasoning on --launch-method=spawn
asv run $main_commit...$main_commit~ --skip-existing --verbose --show-stderr --launch-method=spawn
asv run $test_commit...$test_commit~ --skip-existing --verbose --show-stderr --launch-method=spawn

output=`asv compare $main_commit $test_commit --factor ${ASV_FACTOR:-1} -s`
echo "$output"

if [[ "$output" = *"worse"* ]]; then
  echo "Some of the benchmarks have gotten worse"
  exit 1
fi

if [[ "$CI_PROJECT_NAMESPACE" == "inducer" ]]; then
  git branch -v
  asv publish --html-dir ~/.scicomp-benchmarks/asv/$PROJECT
fi
