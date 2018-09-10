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

if test -f "$REQUIREMENTS_TXT"; then
  conda install --quiet --yes pip
  pip install -r "$REQUIREMENTS_TXT"
fi

# }}}

PY_EXE=python

${PY_EXE} setup.py install

conda list
