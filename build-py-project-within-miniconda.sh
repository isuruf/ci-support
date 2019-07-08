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

rm -Rf .env
rm -Rf build
find . -name '*.pyc' -delete

rm -Rf env
git clean -fdx -e siteconf.py -e boost-numeric-bindings $GIT_CLEAN_EXCLUDE

if test `find "siteconf.py" -mmin +1`; then
  echo "siteconf.py older than a minute, assumed stale, deleted"
  rm -f siteconf.py
fi

# }}}

if [ "$(uname)" = "Darwin" ]; then
  PLATFORM=MacOSX
else
  PLATFORM=Linux
fi

# {{{ download and install

MINICONDA_VERSION=3
MINICONDA_INSTALL_DIR=.miniconda${MINICONDA_VERSION}

MINICONDA_INSTALL_SH=Miniconda${MINICONDA_VERSION}-latest-${PLATFORM}-x86_64.sh
curl -O "https://repo.continuum.io/miniconda/$MINICONDA_INSTALL_SH"

rm -Rf "$MINICONDA_INSTALL_DIR"

bash "$MINICONDA_INSTALL_SH" -b -p "$MINICONDA_INSTALL_DIR"

# }}}

# {{{ set up testing environment

PATH="$MINICONDA_INSTALL_DIR/bin/:$PATH" conda update conda --yes --quiet

PATH="$MINICONDA_INSTALL_DIR/bin/:$PATH" conda update --all --yes --quiet

PATH="$MINICONDA_INSTALL_DIR/bin:$PATH" conda env create --quiet --file "$CONDA_ENVIRONMENT" --name testing

source "$MINICONDA_INSTALL_DIR/bin/activate" testing

# https://github.com/conda-forge/ocl-icd-feedstock/issues/11#issuecomment-456270634
rm -f .miniconda3/envs/testing/etc/OpenCL/vendors/system-*.icd
# https://gitlab.tiker.net/inducer/pytential/issues/112
rm -f .miniconda3/envs/testing/etc/OpenCL/vendors/apple.icd

# https://github.com/pypa/pip/issues/5345#issuecomment-386443351
export XDG_CACHE_HOME=$HOME/.cache/$CI_RUNNER_ID

# }}}

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

${PY_EXE} setup.py install

conda list
