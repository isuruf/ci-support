#! /bin/bash

apt-get update
apt-get install -y jq curl git

# pending https://github.com/codimd/cli/pull/36
git clone https://github.com/inducer/codimd-cli.git

CODIMD=$(pwd)/cli/bin/codimd
export CODIMD_SERVER='https://codimd.tiker.net'
$CODIMD login --email inform+codibackup@tiker.net "$CODIMD_PASSWORD"
while read -r DOCID FILEPATH; do
    echo "Reading note $DOCID into $FILEPATH"
    codimd export --md "$DOCID" "$FILEPATH"
done < .codi-backup.txt
