#! /bin/bash

git clone https://github.com/codimd/cli.git codimd-cli

CODIMD=$(pwd)/codimd-cli/bin/codimd
export CODIMD_SERVER='https://codimd.tiker.net'
$CODIMD login --email inform+codibackup@tiker.net "$CODIMD_PASSWORD"
while read -r DOCID FILEPATH; do
    echo "Reading note $DOCID into $FILEPATH"
    echo "<!-- DO NOT EDIT -->" > "$FILEPATH"
    echo "<!-- THIS FILE WILL BE OVERWRITTEN AUTOMATICALLY -->" >> "$FILEPATH"
    echo "<!-- INSTEAD, EDIT THE FILE AT ${CODIMD_SERVER}/${DOCID} -->" >> "$FILEPATH"
    $CODIMD export --md "$DOCID" "-" >> "$FILEPATH"
    git add "$FILEPATH"
done < .codimd-backup.txt

if [[ `git status --porcelain --untracked-files=no ` ]]; then
  # There are changes in the index
  eval $(ssh-agent)
  trap "kill $SSH_AGENT_PID" EXIT
  echo "${CODIMD_BACKUP_PUSH_KEY}" > id_codimd_backup_push
  chmod 600 id_codimd_backup_push
  cat id_codimd_backup_push
  ssh-add id_codimd_backup_push
  git commit -m "Automatic update from CodiMD: $(date)"
  echo -e "Host gitlab.tiker.net\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
  git push git@gitlab.tiker.net:${CI_PROJECT_PATH}.git master
fi
