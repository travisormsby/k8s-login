#! /bin/bash

cluster=$(kubectl config view --minify -o jsonpath="{.contexts[0].context.cluster}")
server=$(kubectl config view --minify -o jsonpath="{.clusters[0].cluster.server}")

# create certificate authority cert
kubectl config view --minify --flatten -o jsonpath="{.clusters[0].cluster.certificate-authority-data}" | base64 --decode > ca_cert.pem


for i in $(seq -f '%02.f' $1 $2); do
  name=arcgis${i}
  csrname=${name}-$(date +%s)
  openssl genrsa -out ${name}.key 2048
  openssl req -new -key ${name}.key -out ${name}.csr -subj "/CN=${name}/O=kube"
  request=$(cat ${name}.csr | base64 | tr -d "\n")

cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $csrname
spec:
  request: $request
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 172800  # two days
  usages:
  - client auth
EOF

  kubectl certificate approve $csrname
  kubectl get csr $csrname -o jsonpath='{.status.certificate}'| base64 -d > ${name}.crt
  cp configtemplate ${name}-config
  kubectl config --kubeconfig ${name}-config set-cluster $cluster --server=$server --certificate-authority=ca_cert.pem --embed-certs=true 
  kubectl config --kubeconfig ${name}-config set-credentials $name --client-key ${name}.key --client-certificate=${name}.crt --embed-certs=true
  kubectl config --kubeconfig ${name}-config set-context $name --cluster=$cluster --user=$name
  kubectl config --kubeconfig ${name}-config use-context $name
  rm ${name}.*
done
