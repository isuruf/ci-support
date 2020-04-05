#! /bin/bash

set -e
set -x

if [ "$py_version" == "" ]; then
  py_version=3
fi

if [ "$PY_EXE" == "" ]; then
  PY_EXE=python${py_version}
fi

echo "-----------------------------------------------"
echo "Current directory: $(pwd)"
echo "Python executable: ${PY_EXE}"
echo "-----------------------------------------------"

# {{{ clean up

rm -Rf .env
rm -Rf build
find . -name '*.pyc' -delete

rm -Rf env
git clean -fdx -e siteconf.py -e local_settings.py

# }}}

git submodule update --init --recursive

# {{{ virtualenv

${PY_EXE} -m venv .env
. .env/bin/activate

${PY_EXE} -m ensurepip

# }}}

$PY_EXE -m pip install flake8 pep8-naming

python -m flake8 "$@"
