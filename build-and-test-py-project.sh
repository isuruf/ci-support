py_exe=python${py_version}

rm -Rf .env
rm -Rf build

VIRTUALENV="${py_exe} -m venv"
${VIRTUALENV} -h > /dev/null || VIRTUALENV="virtualenv --no-setuptools -p ${py_exe}"

if [ -d ".env" ]; then
  echo "**> virtualenv exists"
else
  echo "**> creating virtualenv"
  ${VIRTUALENV} --system-site-packages .env
fi
curl -k https://bitbucket.org/pypa/setuptools/raw/0.7.2/ez_setup.py | python -
curl -k https://raw.github.com/pypa/pip/master/contrib/get-pip.py | python -

if test -f requirements.txt; then
  pip install -r requirements.txt
fi

find -name '*.pyc' -delete
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
