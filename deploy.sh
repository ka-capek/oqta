#!/usr/bin/env bash
# Deploy to the Pi:  ./deploy.sh        site/ -> kacapek.dev
#                    ./deploy.sh pro    pro/  -> pro.kacapek.dev
# Each deploy is a new folder in releases/, then `current` is switched atomically.
# Only nginx serves from it; nothing gets reloaded or restarted.
set -euo pipefail

HOST=k@176.62.231.116
case "${1:-site}" in
	site) SRC=site BASE=/var/www/kacapek.dev ;;
	pro)  SRC=pro  BASE=/var/www/pro.kacapek.dev ;;
	*)    echo "usage: $0 [site|pro]" >&2; exit 1 ;;
esac
REL=$(date +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD 2>/dev/null || echo local)
KEEP=5

cd "$(dirname "$0")"
ssh "$HOST" "rm -rf ~/oqta-stage && mkdir ~/oqta-stage"
rsync -a --delete --exclude '.DS_Store' "$SRC/" "$HOST:oqta-stage/"
ssh "$HOST" "set -e
	sudo mkdir -p $BASE/releases
	sudo cp -r ~/oqta-stage $BASE/releases/$REL
	sudo chown -R root:root $BASE/releases/$REL
	sudo chmod -R a+rX $BASE/releases/$REL
	sudo ln -sfn releases/$REL $BASE/current.tmp
	sudo mv -T $BASE/current.tmp $BASE/current
	cd $BASE/releases && ls -1t | tail -n +$((KEEP + 1)) | xargs -r sudo rm -rf
	rm -rf ~/oqta-stage
	echo deployed $REL"
echo "rollback: ssh $HOST 'sudo ln -sfn releases/<old> $BASE/current'"
