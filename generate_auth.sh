#!/bin/bash
if [[ $# -eq 0 ]] ; then
    echo "Run the script with the required auth user and namespace for the secret: ${0} [user] [namespace]"
    exit 0
fi
PASSWORDHASH=$(openssl passwd -apr1) || exit
printf "${1}:${PASSWORDHASH}\n" >> ingress_auth.tmp
kubectl delete secret -n ${2} ingress-auth
kubectl create secret generic ingress-auth --from-file=ingress_auth.tmp -n ${2}
rm ingress_auth.tmp
