#! /bin/bash

echo "-----------------------------------------------"
echo "Current directory: $(pwd)"
echo "Conda environment file: ${CONDA_ENVIRONMENT}"
echo "Extra pip requirements: ${REQUIREMENTS_TXT}"
echo "PYOPENCL_TEST: ${PYOPENCL_TEST}"
echo "PYTEST_ADDOPTS: ${PYTEST_ADDOPTS}"
echo "git revision: $(git rev-parse --short HEAD)"
echo "git status:"
git status -s
echo "-----------------------------------------------"

# {{{ clean up

# keep this consistent in build-py-project.sh and build-py-project-within-miniconda.sh

# Append --editable to PROJECT_INSTALL_FLAGS, if not there already.
# See: https://gitlab.tiker.net/inducer/ci-support/-/issues/3
# Can be removed after pip 20.1 is released.
if [[ ! $PROJECT_INSTALL_FLAGS =~ (^|[[:space:]]*)(--editable|-e)[[:space:]]*$ ]]; then
    PROJECT_INSTALL_FLAGS="$PROJECT_INSTALL_FLAGS --editable"
fi

rm -Rf .env
rm -Rf build
find . -name '*.pyc' -delete

rm -Rf env
git clean -fdx \
  -e siteconf.py \
  -e boost-numeric-bindings \
  -e '.pylintrc.yml' \
  -e 'prepare-and-run-*.sh' \
  -e 'run-*.py' \
  -e '.test-*.yml' \
  $GIT_CLEAN_EXCLUDE


if test `find "siteconf.py" -mmin +1`; then
  echo "siteconf.py older than a minute, assumed stale, deleted"
  rm -f siteconf.py
fi

if [[ "$NO_SUBMODULES" = "" ]]; then
  git submodule update --init --recursive
fi

# }}}

if [ "$(uname)" = "Darwin" ]; then
  PLATFORM=MacOSX
else
  PLATFORM=Linux
fi

# {{{ download and install

MINIFORGE_VERSION=3
MINIFORGE_INSTALL_DIR=.miniforge${MINIFORGE_VERSION}

MINIFORGE_INSTALL_SH=Miniforge3-$PLATFORM-x86_64.sh
curl -O "https://github.com/conda-forge/miniforge/releases/latest/download/$MINIFORGE_INSTALL_SH"

rm -Rf "$MINIFORGE_INSTALL_DIR"

bash "$MINIFORGE_INSTALL_SH" -b -p "$MINIFORGE_INSTALL_DIR"

# }}}

# {{{ set up testing environment

PATH="$MINIFORGE_INSTALL_DIR/bin/:$PATH" conda update conda --yes --quiet

PATH="$MINIFORGE_INSTALL_DIR/bin/:$PATH" conda update --all --yes --quiet

PATH="$MINIFORGE_INSTALL_DIR/bin:$PATH" conda env create --file "$CONDA_ENVIRONMENT" --name testing

source "$MINIFORGE_INSTALL_DIR/bin/activate" testing

# https://github.com/conda-forge/ocl-icd-feedstock/issues/11#issuecomment-456270634
rm -f $MINIFORGE_INSTALL_DIR/envs/testing/etc/OpenCL/vendors/system-*.icd
# https://gitlab.tiker.net/inducer/pytential/issues/112
rm -f $MINIFORGE_INSTALL_DIR/envs/testing/etc/OpenCL/vendors/apple.icd

# https://github.com/pypa/pip/issues/5345#issuecomment-386443351
export XDG_CACHE_HOME=$HOME/.cache/$CI_RUNNER_ID

# }}}

conda list

PY_EXE=python

# {{{ install pytest

# Using pip instead of conda here avoids ridiculous uninstall chains
# like these: https://gitlab.tiker.net/inducer/pyopencl/-/jobs/61543

PY_VER=$($PY_EXE -c 'import sys; print(".".join(str(s) for s in sys.version_info[:2]))')
if [[ "${PY_VER}" == 2* ]]; then
  $PY_EXE -mpip install "pytest<5"
else
  $PY_EXE -mpip install pytest
fi

# }}}

if test -f "$REQUIREMENTS_TXT"; then
  conda install --quiet --yes pip
  pip install -r "$REQUIREMENTS_TXT"
fi

if test -f .conda-ci-build-configure.sh; then
  source .conda-ci-build-configure.sh
fi

pip install $PROJECT_INSTALL_FLAGS .
