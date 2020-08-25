#! /bin/bash

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/master/ci-support.sh
source ci-support.sh

build_py_project_in_venv

# https://github.com/sphinx-doc/sphinx/issues/8084
$PY_EXE -m pip install docutils "sphinx<3.2"

cd doc

cat > doc_upload_ssh_config <<END
Host doc-upload
   User doc
   IdentityFile doc_upload_key
   IdentitiesOnly yes
   Hostname marten.tiker.net
   StrictHostKeyChecking false
END

make html SPHINXOPTS="-W --keep-going -n"

if test -n "${DOC_UPLOAD_KEY}"; then
  echo "${DOC_UPLOAD_KEY}" > doc_upload_key
  chmod 0600 doc_upload_key
  RSYNC_RSH="ssh -F doc_upload_ssh_config" ./upload-docs.sh || { rm doc_upload_key; exit 1; }
  rm doc_upload_key
else
  echo "Skipping upload. DOC_UPLOAD_KEY was not provided."
fi
