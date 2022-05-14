#!/bin/bash

########################
# include the magic
########################
wget
. ./demo-magic.sh
TYPE_SPEED=80
clear


pe 'ls -l'
pe 'cd aws'
pe './get-kubecconfig.sh'
pe 'cp ./kubeconfig /tmp/kubeconfig'
pe 'export KUBECONFIG=/tmp/kubeconfig'
pe 'cd ../hcp'
pe 'ls -l'
pe 'cat outputs.tf'
pe 'export CONSUL_HTTP_TOKEN=$(terraform output --raw consul_root_token_secret_id )'
pe "echo ${CONSUL_HTTP_TOKEN}"

pe 'terraform output --raw consul_ca_file |  base64 -d> ./ca.pem'

pe "kubectl create secret generic \"consul-ca-cert\" --from-file='tls.crt=./ca.pem'"

pe 'terraform output --raw consul_config_file | base64 -d | jq > client_config.json'
pe 'cat client_config.json'
pe 'kubectl create secret generic "consul-gossip-key" --from-literal="key=$(jq -r .encrypt client_config.json)"'

pe 'kubectl create secret generic "consul-bootstrap-token" --from-literal="token=${CONSUL_HTTP_TOKEN}"'
# read about bootstrap ACL
#https://learn.hashicorp.com/tutorials/consul/access-control-setup-production?in=consul/security

pe 'export DATACENTER=$(jq -r .datacenter client_config.json)'
pe 'export RETRY_JOIN=$(jq -r --compact-output .retry_join client_config.json)'
pe 'export K8S_HTTP_ADDR=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"$(kubectl config current-context)\")].cluster.server}")'
pe 'echo $DATACENTER && \
  echo $RETRY_JOIN && \
  echo $K8S_HTTP_ADDR'

cat > config.yaml << EOF
global:
  logLevel: "debug"
  name: terasky-consul
  enabled: false
  datacenter: ${DATACENTER}
  acls:
    manageSystemACLs: true
    bootstrapToken:
      secretName: consul-bootstrap-token
      secretKey: token
  gossipEncryption:
    secretName: consul-gossip-key
    secretKey: key
  tls:
    enabled: true
    enableAutoEncrypt: true
    caCert:
      secretName: consul-ca-cert
      secretKey: tls.crt
  enableConsulNamespaces: true
externalServers:
  enabled: true
  hosts: ${RETRY_JOIN}
  httpsPort: 443
  useSystemRoots: true
  k8sAuthMethodHost: ${K8S_HTTP_ADDR}
client:
  enabled: true
  join: ${RETRY_JOIN}
connectInject:
  enabled: true
controller:
  enabled: false
ingressGateways:
  enabled: false
syncCatalog:
  enabled: true
EOF

#TODO check inject false clients true faile with acl issue no such host
#consul-k8s-control-plane acl-init -component-name=client  -acl-auth-method="terasky-consul-k8s-component-auth-method"  -log-level=trace  -log-json=false   -use-http
 #s  -server-address="terasky-consul.private.consul.11eb5efd-82fb-db6e-a22f-0242ac11000b.aws.hashicorp.cloud"  -server-port=443  -init-type="client"
 #2022-05-14T15:05:11.716Z [ERROR] unable to login: error="Unexpected response code: 500 (Post "https://kubernetes.default.svc/apis/authentication.k8s.io/v1/tokenreviews": dial tcp: lookup kubernetes.default.svc on 127.0.0.53:53: no such host)"
 #2022-05-14T15:05:12.722Z [ERROR] unable to login: error="Unexpected response code: 500 (Post "https://kubernetes.default.svc/apis/authentication.k8s.io/v1/tokenreviews": dial tcp: lookup kubernetes.default.svc on 127.0.0.53:53: no such host)"
 #2022-05-14T15:05:13.729Z [ERROR] unable to login: error="Unexpected response code: 500 (Post "https://kubernetes.default.svc/apis/authentication.k8s.io/v1/tokenreviews": dial tcp: lookup kubernetes.default.svc on 127.0.0.53:53: no such host)"
#TODO check why only sync true catalog fails with Error: INSTALLATION FAILED: Deployment.apps "terasky-consul-sync-catalog" is invalid: [spec.template.spec.containers[0].volumeMounts[1].name: Not found: "consul-ca-cert", spec.template.spec.initContainers[0].volumeMounts[1].name: Not found: "consul-auto-encrypt-ca-cert"]

pe 'cat config.yaml'
pe 'helm install --wait consul -f config.yaml hashicorp/consul --version "0.43.0" --set global.image=hashicorp/consul-enterprise:1.12.0-ent'

pe 'kubectl get pods'

p "Open $(terraform output consul_public_endpoint) and use ${CONSUL_HTTP_TOKEN} token to login"
pe 'kubectl get svc'
