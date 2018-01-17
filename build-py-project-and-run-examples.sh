#! /bin/bash

set -e

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/master/build-py-project.sh
source build-py-project.sh

for i in $(find examples -name '*.py' -exec grep -q __main__ '{}' \; -print ); do
  echo "-----------------------------------------------------------------------"
  echo "RUNNING $i"
  echo "-----------------------------------------------------------------------"

done
