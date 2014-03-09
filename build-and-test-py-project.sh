py_exe=python${py_version}

rm -Rf .env
rm -Rf build
find -name '*.pyc' -delete

rm -Rf env

VENV_VERSION="virtualenv-1.9.1"
rm -Rf "$VENV_VERSION"
curl -k https://pypi.python.org/packages/source/v/virtualenv/$VENV_VERSION.tar.gz | tar xfz -

VIRTUALENV="${py_exe} -m venv"
${VIRTUALENV} -h > /dev/null || VIRTUALENV="$VENV_VERSION/virtualenv.py --no-setuptools -p ${py_exe}"

if [ -d ".env" ]; then
  echo "**> virtualenv exists"
else
  echo "**> creating virtualenv"
  ${VIRTUALENV} .env
fi

curl -k https://bitbucket.org/pypa/setuptools/raw/bootstrap-py24/ez_setup.py | python -
if test "$py_version" = "2.5"; then
  # pip 1.3 is the last release with Python 2.5 support
  hash -r
  which easy_install
  easy_install 'pip==1.3.1'
  PIP="pip --insecure"
else
  #curl -k https://raw.github.com/pypa/pip/1.4/contrib/get-pip.py | python -
  curl http://git.tiker.net/pip/blob_plain/77f959a3ce9cc506efbf3a17290d387d0a6624f5:/contrib/get-pip.py | python -

  PIP="pip"
fi

# Not sure why the hell pip ends up there, but in Py3.3, it sometimes does.
export PATH=`pwd`/.env/local/bin:$PATH

if test "$EXTRA_INSTALL" != ""; then
  for i in $EXTRA_INSTALL ; do
    $PIP install $i
  done
fi

if test -f requirements.txt; then
  $PIP install -r requirements.txt
fi

$PIP install pytest

${py_exe} setup.py install

if test -d test; then
  cd test

  if test "$cl_dev" != ""; then
    cl_dev_real=`echo ${cl_dev} | tr '_+' ': '`
  fi

  if test -f /tmp/enable-amd-compute; then
    . /tmp/enable-amd-compute
  fi

  ulimit -c unlimited
  PYOPENCL_TEST=${cl_dev_real} ${py_exe} -m pytest --junitxml=pytest.xml
fi
