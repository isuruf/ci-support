echo "-----------------------------------------------"
echo "Current directory: $(pwd)"
echo "Python executable: ${PY_EXE}"
echo "PYOPENCL_TEST: ${PYOPENCL_TEST}"
echo "PYTEST_ADDOPTS: ${PYTEST_ADDOPTS}"
echo "PROJECT_INSTALL_FLAGS: ${PROJECT_INSTALL_FLAGS}"
echo "git revision: $(git rev-parse --short HEAD)"
echo "git status:"
git status -s
echo "-----------------------------------------------"

# {{{ clean up

# keep this consistent in build-py-project.sh and build-py-project-within-miniconda.sh

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

# {{{ virtualenv

VENV_VERSION="virtualenv-15.1.0"
rm -Rf "$VENV_VERSION"
curl -k https://files.pythonhosted.org/packages/d4/0c/9840c08189e030873387a73b90ada981885010dd9aea134d6de30cd24cb8/$VENV_VERSION.tar.gz | tar xfz -

VIRTUALENV="${PY_EXE} -m venv"
${VIRTUALENV} -h > /dev/null || VIRTUALENV="$VENV_VERSION/virtualenv.py --no-setuptools -p ${PY_EXE}"

if [ -d ".env" ]; then
  echo "**> virtualenv exists"
else
  echo "**> creating virtualenv"
  ${VIRTUALENV} .env
fi

. .env/bin/activate

# }}}

# {{{ setuptools

#curl -k https://bitbucket.org/pypa/setuptools/raw/bootstrap-py24/ez_setup.py | python -
#curl -k https://ssl.tiker.net/software/ez_setup.py | python -
#curl -k https://bootstrap.pypa.io/ez_setup.py | python -

# SETUPTOOLS_VERSION="setuptools-33.1.1"
# curl -k -O https://pypi.python.org/packages/dc/8c/7c9869454bdc53e72fb87ace63eac39336879eef6f2bf96e946edbf03e90/$SETUPTOOLS_VERSION.zip
# unzip $SETUPTOOLS_VERSION
# (cd $SETUPTOOLS_VERSION; $PY_EXE setup.py install)

# }}}

if [[ "${PY_EXE}" == python3.[56789] ]]; then
  $PY_EXE -m ensurepip
elif [[ "${PY_EXE}" == python2.6 ]]; then
  curl https://bootstrap.pypa.io/2.6/get-pip.py | python -
else
  curl https://bootstrap.pypa.io/get-pip.py | python -
fi

# Not sure why the hell pip ends up there, but in Py3.3, it sometimes does.
export PATH=`pwd`/.env/local/bin:$PATH

PIP="${PY_EXE} $(which pip)"

# https://github.com/pypa/pip/issues/5345#issuecomment-386443351
export XDG_CACHE_HOME=$HOME/.cache/$CI_RUNNER_ID

$PIP install --upgrade pip
$PIP install setuptools

# Pinned to 3.0.4 because of https://github.com/pytest-dev/pytest/issues/2434
# Install before a newer version gets pulled in as a dependency
$PIP install pytest==3.0.4 pytest-warnings==0.2.0

if test "$EXTRA_INSTALL" != ""; then
  for i in $EXTRA_INSTALL ; do
    if [ "$i" = "numpy" ] && [[ "${PY_EXE}" == pypy* ]]; then
      $PIP install git+https://bitbucket.org/pypy/numpy.git
    elif [[ "$i" = *pybind11* ]] && [[ "${PY_EXE}" == pypy* ]]; then
      # Work around https://github.com/pypa/virtualenv/issues/1198
      # Running virtualenv --always-copy or -m venv --copies should also do the trick.
      L=$(readlink .env/include)
      rm .env/include
      cp -R $L .env/include

      $PIP install $i
    elif [ "$i" = "numpy" ] && [[ "${PY_EXE}" == python2.6* ]]; then
      $PIP install 'numpy==1.10.4'
    else
      $PIP install $i
    fi
  done
fi

if test "$REQUIREMENTS_TXT" == ""; then
  REQUIREMENTS_TXT="requirements.txt"
fi

if test -f $REQUIREMENTS_TXT; then
  $PIP install -r $REQUIREMENTS_TXT
fi

$PIP install $PROJECT_INSTALL_FLAGS .
