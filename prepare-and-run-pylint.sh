#! /bin/bash

set -e
set -x

PY_EXE=python3.6

echo "-----------------------------------------------"
echo "Current directory: $(pwd)"
echo "Python executable: ${PY_EXE}"
echo "-----------------------------------------------"

# {{{ clean up

rm -Rf .env
rm -Rf build
find . -name '*.pyc' -delete

rm -Rf env
git clean -fdx -e siteconf.py -e boost-numeric-bindings -e local_settings.py

if test `find "siteconf.py" -mmin +1`; then
  echo "siteconf.py older than a minute, assumed stale, deleted"
  rm -f siteconf.py
fi

# }}}

git submodule update --init --recursive

# {{{ virtualenv

${PY_EXE} -m venv .env
. .env/bin/activate

${PY_EXE} -m ensurepip

# }}}

$PY_EXE -m pip install pylint

if ! test -f .pylintrc; then
  curl -o .pylintrc https://gitlab.tiker.net/inducer/ci-support/raw/master/.pylintrc-default
fi

python -m pylint --rcfile=.pylintrc "$@"
