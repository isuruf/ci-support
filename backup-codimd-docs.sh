#! /bin/bash

git clone https://gitlab.tiker.net/inducer/codimd-cli.git codimd-cli
CODIMD=$(pwd)/codimd-cli/bin/codimd

git clone "$CI_REPOSITORY_URL" codimd-backup-subrepo
cd codimd-backup-subrepo
git checkout master

SECONDS_SINCE_LAST_COMMIT=$((git show HEAD --format=%cI -s && date --iso-8601=seconds) | python3 -c 'import sys; import datetime as dt; fromiso=dt.datetime.fromisoformat; s=fromiso(sys.stdin.readline().strip()); e=fromiso(sys.stdin.readline().strip()); print(int((e-s).total_seconds()))')

if (( SECONDS_SINCE_LAST_COMMIT < 10*60 )); then
    echo "last commit is too recent, aborting."
    exit
fi

export CODIMD_SERVER='https://codimd.tiker.net'
$CODIMD login --email inform+codibackup@tiker.net "$CODIMD_PASSWORD"

# read will not return the last line if there isn't a newline :facepalm:
DONE=false
until $DONE; do
    DOCID=""
    read -r DOCID FILEPATH || DONE=true
    if test "$DOCID" != ""; then
        echo "Reading note $DOCID into $FILEPATH"
        {
                echo "**DO NOT EDIT**"
                echo "This file will be automatically overwritten. "
                echo "Instead, edit the file at ${CODIMD_SERVER}/${DOCID} "
                echo "**DO NOT EDIT**"
                echo ""
                $CODIMD export --md "$DOCID" "-"
        } > "$FILEPATH"
        git add "$FILEPATH"
    fi
done < .codimd-backup.txt

if [[ `git status --porcelain --untracked-files=no ` ]]; then
    # There are changes in the index
    eval $(ssh-agent)
    trap "kill $SSH_AGENT_PID" EXIT
    echo "${CODIMD_BACKUP_PUSH_KEY}" > id_codimd_backup_push
    chmod 600 id_codimd_backup_push
    ssh-add id_codimd_backup_push
    git config --global user.name "CodiMD backup service"
    git config --global user.email "inform@tiker.net"
    git commit -m "Automatic update from CodiMD: $(date)"
    mkdir -p ~/.ssh
    echo -e "Host gitlab.tiker.net\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
    git push git@gitlab.tiker.net:${CI_PROJECT_PATH}.git master
fi

# vim: sw=4
