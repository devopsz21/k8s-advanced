#!/bin/sh

set -e
set -x

# Run on kubeadm cluster
# see "kubernetes in action" p391

NS="psp-advanced"

kubectl delete ns,psp -l "policies=$NS"

kubectl create namespace "$NS"
kubectl label ns "$NS" "policies=$NS"

KUBIA_DIR="/tmp/kubernetes-in-action"
if [ ! -d "$KUBIA_DIR" ]; then
    git clone https://github.com/luksa/kubernetes-in-action.git /tmp/kubernetes-in-action

fi

# Exercice: define default policy
kubectl apply -f /tmp/resource/psp/default-psp-with-rbac.yaml

# Exercice: enable alice to create pod
kubectl create rolebinding alice:edit \
    --clusterrole=edit \
    --user=alice \
    --namespace "$NS"

# Check
alias kubectl-user="kubectl --as=alice --namespace '$NS'"

kubectl-user run --generator=run-pod/v1 -it ubuntu --image=ubuntu id

# Remark: cluster-admin has access to all psp (see cluster-admin role), and use the most permissive in each section

cd "$KUBIA_DIR"/Chapter13

# 13.3.1 Introducing the PodSecurityPolicy resource
kubectl apply -f pod-security-policy.yaml
kubectl-user create --namespace "$NS" -f pod-privileged.yaml && >&2 echo "ERROR this command should have failed"

# 13.3.2 Understanding runAsUser, fsGroup, and supplementalGroups
# policies
kubectl apply -f psp-must-run-as.yaml
# DEPLOYING A POD WITH RUN_AS USER OUTSIDE OF THE POLICY’S RANGE
kubectl-user create --namespace "$NS" -f pod-as-user-guest.yaml && >&2 echo "ERROR this command should have failed"
# DEPLOYING A POD WITH A CONTAINER IMAGE WITH AN OUT-OF-RANGE USER ID
kubectl-user run --generator=run-pod/v1 --namespace "$NS" run-as-5 --image luksa/kubia-run-as-user-5 --restart Never
kubectl  wait -n "$NS" --for=condition=Ready pods run-as-5
kubectl exec --namespace "$NS" run-as-5 -- id

kubectl apply -f psp-capabilities.yaml
kubectl-user create -f pod-add-sysadmin-capability.yaml && >&2 echo "ERROR this command should have failed"
kubectl apply -f psp-volumes.yaml

# 13.3.5 Assigning different PodSecurityPolicies to different users
# and groups
# Enable bob to create pod
kubectl create rolebinding bob:edit \
    --clusterrole=edit \
    --user=bob\
    --namespace "$NS"
# WARN: book says 'psp-privileged', p.398
kubectl create clusterrolebinding psp-bob --clusterrole=privileged-psp --user=bob
kubectl --namespace "$NS" --user alice create -f pod-privileged.yaml && >&2 echo "ERROR this command should have failed"
kubectl --namespace "$NS" --user bob create -f pod-privileged.yaml 