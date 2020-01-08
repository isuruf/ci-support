#! /bin/bash

cd examples
for i in $(find . -name '*.py' -exec grep -q __main__ '{}' \; -print ); do
  echo "-----------------------------------------------------------------------"
  echo "RUNNING $i"
  echo "-----------------------------------------------------------------------"
  dn=$(dirname "$i")
  bn=$(basename "$i")
  (cd $dn; time ${PY_EXE} "$bn")
done
