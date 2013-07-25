py_exe=python${py_version}

rm -Rf .env
rm -Rf build
find -name '*.pyc' -delete

VIRTUALENV="${py_exe} -m venv"
${VIRTUALENV} -h > /dev/null || VIRTUALENV="virtualenv --no-setuptools -p ${py_exe}"

if [ -d ".env" ]; then
  echo "**> virtualenv exists"
else
  echo "**> creating virtualenv"
  ${VIRTUALENV} --system-site-packages .env
fi
curl -k https://bitbucket.org/pypa/setuptools/raw/0.7.2/ez_setup.py | python -
# pip 1.3 is the last release with Python 2.5 support
curl -k https://raw.github.com/pypa/pip/1.3.1/contrib/get-pip.py | python -

# Not sure why the hell pip ends up there, but in Py3.3, it sometimes does.
export PATH=`pwd`/.env/local/bin:$PATH

if test -f requirements.txt; then
  pip install -r requirements.txt
fi

pip install pytest

if test "$EXTRA_INSTALL" != ""; then
  for i in $EXTRA_INSTALL ; do
    pip install $i
  done
fi

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
