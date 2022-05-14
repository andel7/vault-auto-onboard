#!/bin/bash

helm uninstall consul
rm ./hcp/ca.pem
kubectl delete secret consul-ca-cert
rm ./hcp/client_config.json
kubectl delete secret consul-gossip-key
kubectl delete secret consul-bootstrap-token
rm ./hcp/config.yaml
kubectl get pods

rm /tmp/kubeconfig