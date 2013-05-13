#! /bin/bash
set -o errexit

export GOPATH=$(cd "$(dirname "$0")"; pwd)
export GIT_DIR=$GOPATH/../.git
if [ $# == 1 ]; then
  export GOBIN=$GOPATH/$1
fi

ldflags="-X koding/tools/lifecycle.version $(git rev-parse HEAD)"
services=(
    koding/broker
    koding/rerouting
	koding/kites/os
	koding/kites/irc
	koding/virt/vmproxy
	koding/virt/vmtool
	koding/alice
	koding/kontrol/kontrolclient
)

go install -v -ldflags "$ldflags" "${services[@]}"

cd $GOPATH
cp bin/os bin/irc ../kites
rm -f ../kites/alice ../kites/broker ../kites/idshift ../kites/proxy ../kites/vmtool ../kites/ldapserver bin/ldapserver

mkdir -p build/broker
cp bin/broker build/broker/broker
