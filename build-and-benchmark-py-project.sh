curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/master/build-py-project-within-miniconda.sh
source build-py-project-within-miniconda.sh

pip install asv

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
fi

if [[ ! -f ~/.asv-machine.json ]]; then
  asv machine --yes
fi

master_commit=`git rev-parse master`
test_commit=`git rev-parse HEAD`

asv run $master_commit...$master_commit~ --skip-existing --verbose
asv run $test_commit...$test_commit~ --skip-existing --verbose

output=`asv compare $master_commit $test_commit --factor 1 -s`
echo "$output"

if [[ "$output" = *"worse"* ]]; then
  echo "Some of the benchmarks have gotten worse"
  exit 1
fi

if [[ "$CI_PROJECT_NAMESPACE" == "inducer" ]]; then
  asv publish --html-dir ~/.scicomp-benchmarks/asv/$PROJECT
fi
