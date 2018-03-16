#! /bin/bash

set -e

if [ "$PY_EXE" == "" ]; then
  PY_EXE=python${py_version}
fi

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/master/build-py-project.sh
source build-py-project.sh

cd examples
for i in $(find . -name '*.py' -exec grep -q __main__ '{}' \; -print ); do
  echo "-----------------------------------------------------------------------"
  echo "RUNNING $i"
  echo "-----------------------------------------------------------------------"
  dn=$(dirname "$i")
  bn=$(basename "$i")
  (cd $dn; ${PY_EXE} "$bn")
done
