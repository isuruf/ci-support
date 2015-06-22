#! /bin/bash

if [ "$PY_EXE" == "" ]; then
  PY_EXE=python${py_version}
fi

echo "-----------------------------------------------"
echo "Current directory: $(pwd)"
echo "Python executable: ${PY_EXE}"
echo "PYOPENCL_TEST: ${PYOPENCL_TEST}"
echo "-----------------------------------------------"

rm -Rf .env
rm -Rf build
find -name '*.pyc' -delete

rm -Rf env

git submodule update --init --recursive

VENV_VERSION="virtualenv-13.0.3"
rm -Rf "$VENV_VERSION"
curl -k https://pypi.python.org/packages/source/v/virtualenv/$VENV_VERSION.tar.gz | tar xfz -

VIRTUALENV="${PY_EXE} -m venv"
${VIRTUALENV} -h > /dev/null || VIRTUALENV="$VENV_VERSION/virtualenv.py --no-setuptools -p ${PY_EXE}"

if [ -d ".env" ]; then
  echo "**> virtualenv exists"
else
  echo "**> creating virtualenv"
  ${VIRTUALENV} .env
fi

. .env/bin/activate

#curl -k https://bitbucket.org/pypa/setuptools/raw/bootstrap-py24/ez_setup.py | python -
#curl -k https://ssl.tiker.net/software/ez_setup.py | python -
curl -k https://bootstrap.pypa.io/ez_setup.py | python -

curl -k https://gitlab.tiker.net/inducer/pip/raw/7.0.3/contrib/get-pip.py | python -

# Not sure why the hell pip ends up there, but in Py3.3, it sometimes does.
export PATH=`pwd`/.env/local/bin:$PATH

PIP="${PY_EXE} $(which pip)"

if test "$EXTRA_INSTALL" != ""; then
  for i in $EXTRA_INSTALL ; do
    if [ "$i" = "numpy" ] && [[ "${PY_EXE}" == pypy* ]]; then
      $PIP install git+https://bitbucket.org/pypy/numpy.git
    else
      $PIP install $i
    fi
  done
fi

if test -f requirements.txt; then
  $PIP install -r requirements.txt
fi

$PIP install pytest

${PY_EXE} setup.py install

TESTABLES=""
if [ -d test ]; then
  cd test

  TESTABLES="$TESTABLES ."

  if [ -z "$NO_DOCTESTS" ]; then
    RST_FILES=(../doc/*.rst)

    if [ -e "${RST_FILES[0]}" ]; then
      TESTABLES="$TESTABLES ${RST_FILES[*]}"
    fi
  fi

  if ! test -z "$TESTABLES"; then
    if test -f /tmp/enable-amd-compute; then
      . /tmp/enable-amd-compute
    fi

    echo "TESTABLES: $TESTABLES"
    ulimit -c unlimited

    # Need to set both _TEST and _CTX because doctests do not use _TEST.
    ${PY_EXE} -m pytest --tb=native  -rxs $TESTABLES

    # Avoid https://github.com/pytest-dev/pytest/issues/754:
    # add --tb=native

    # Avoid https://github.com/pytest-dev/pytest/issues/785:
    # omit --junitxml=pytest.xml
  fi
fi
