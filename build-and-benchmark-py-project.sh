curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/master/build-py-project-within-miniconda.sh
source build-py-project-within-miniconda.sh

# Can't use v0.3 because https://github.com/airspeed-velocity/asv/pull/721 is needed
# Can't use v0.4 because of https://github.com/airspeed-velocity/asv/issues/822
pip install git+https://github.com/airspeed-velocity/asv@baeec6e096947f735ed3917ed0c2b9361366dd52#egg=asv

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
  # Fetch the master branch as git repository in gitlab ci env doesn't have it.
  git fetch origin master
  git branch master origin/master
fi

if [[ ! -f ~/.asv-machine.json ]]; then
  asv machine --yes
fi

master_commit=`git rev-parse master`
test_commit=`git rev-parse HEAD`

# cf. https://github.com/pandas-dev/pandas/pull/25237
# for reasoning on --launch-method=spawn
asv run $master_commit...$master_commit~ --skip-existing --verbose --show-stderr --launch-method=spawn
asv run $test_commit...$test_commit~ --skip-existing --verbose --show-stderr --launch-method=spawn

output=`asv compare $master_commit $test_commit --factor 1 -s`
echo "$output"

if [[ "$output" = *"worse"* ]]; then
  echo "Some of the benchmarks have gotten worse"
  exit 1
fi

if [[ "$CI_PROJECT_NAMESPACE" == "inducer" ]]; then
  asv publish --html-dir ~/.scicomp-benchmarks/asv/$PROJECT
fi
