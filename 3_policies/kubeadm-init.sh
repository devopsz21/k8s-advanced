#!/bin/sh

# Create an up and running k8s cluster

set -e

DIR=$(cd "$(dirname "$0")"; pwd -P)

WORKDIR="$DIR/../1_kubeadm"

. "$WORKDIR/env.sh"

echo "Copy scripts to all nodes"
echo "-------------------------"
parallel --tag -- $SCP --recurse "$WORKDIR/resource" "$USER"@{}:/tmp ::: "$MASTER" $NODES

echo "Install prerequisites"
echo "---------------------"
parallel -vvv --tag -- "$SSH $USER@{} -- sudo 'sh /tmp/resource/prereq.sh'" ::: "$MASTER" $NODES

echo "Initialize master"
echo "-----------------"
$SSH "$MASTER" -- /tmp/resource/init.sh -p

echo "Join nodes"
echo "----------"
# TODO test '-ttl' option
JOIN_CMD=$($SSH "$USER@$MASTER" -- 'sudo kubeadm token create --print-join-command')
echo "Join command: $JOIN_CMD"
parallel -vvv --tag -- "$SSH $USER@{} -- sudo '$JOIN_CMD'" ::: $NODES
