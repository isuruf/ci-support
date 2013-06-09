# requires: py_exe

echo "MAKE-VENV VERSION 1"

rm -Rf .env

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
