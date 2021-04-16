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

if [[ ! -z "$CI" ]]; then
  mkdir -p .asv
  if [[ "$CI_PROJECT_NAMESPACE" == "inducer" ]]; then
    echo "$BENCHMARK_DATA_DEPLOY_KEY" > .deploy_key
    chmod 700 .deploy_key
    ssh-keyscan gitlab.tiker.net >> ~/.ssh/known_hosts
    chmod 644 ~/.ssh/known_hosts
    ssh-agent bash -c "ssh-add $PWD/.deploy_key; git clone git@gitlab.tiker.net:isuruf/benchmark-data"
  else
    git clone https://gitlab.tiker.net/isuruf/benchmark-data
  fi
  ln -s $PWD/benchmark-data/$PROJECT .asv/results

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
  cd benchmark-data
  git add $PROJECT
  export GIT_AUTHOR_NAME="Automated Benchmark Bot"
  export GIT_AUTHOR_EMAIL="bot@gitlab.tiker.net"
  export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME
  export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL
  git commit -m "Update benchmark data for $main_commit" --allow-empty
  ssh-agent bash -c "ssh-add $PWD/../.deploy_key; git push"
  cd ..
  git branch -v
  mkdir -p ~/.scicomp-benchmarks/asv
  asv publish --html-dir ~/.scicomp-benchmarks/asv/$PROJECT
fi
