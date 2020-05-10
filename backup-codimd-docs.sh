#! /bin/bash

apt update
apt install jq curl git
git clone https://github.com/codimd/cli.git

CODIMD=$(pwd)/cli/bin/codimd
export CODIMD_SERVER='https://codimd.tiker.net'
$CODIMD login inform+codibackup@tiker.net "$CODIMD_PASSWORD"
while read -r DOCID FILEPATH; do
    echo "Reading note $DOCID into $FILEPATH"
    codimd export --md "$DOCID" "$FILEPATH"
done < .codi-backup.txt
