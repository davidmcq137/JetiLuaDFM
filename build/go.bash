#!/usr/bin/env bash

set -ex
BB="$(dirname $0)/bb"
if [[ ! -f "$BB" ]]; then
    curl -L -o /tmp/bb.tar.gz "https://github.com/babashka/babashka/releases/download/v1.1.173/babashka-1.1.173-linux-amd64-static.tar.gz"
    pushd $(dirname $0)
    tar -xvzf /tmp/bb.tar.gz
    rm /tmp/bb.tar.gz
    chmod +x bb
    popd
fi

# npm i

exec "$BB" clojure -M -e '(user/go)'

