#! /bin/bash

# create ClusterRole to see all resources and get Prometheus metrics
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: view-all
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "watch", "list"]
- apiGroups: [""]
  resources: ["services/proxy"]
  resourceNames: ["prometheus-operated:9090"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF


for i in $(seq -f '%02.f' $1 $2); do
name=kube${i}
csrname=${name}-$(date +%s)
openssl genrsa -out ${name}.key 2048
openssl req -new -key ${name}.key -out ${name}.csr -subj "/CN=${name}/O=kube"
request=$(cat ${name}.csr | base64 | tr -d "\n")

# create namespace
kubectl create ns ${name}

# grant the admin role scoped to the specific namespace
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: namespace-admin
  namespace: ${name}
subjects:
- kind: User
  name: ${name}
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
EOF

# apply resource quota to namespace
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${name}-resource-quota
  namespace: ${name}
spec:
  hard:
    limits.cpu: "130"
    limits.memory: 200Gi
    requests.cpu: "20"
    requests.memory: 100Gi
EOF

# Assign the view-all ClusterRole
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${name}-view-all
subjects:
- kind: User
  name: ${name}
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: view-all
  apiGroup: rbac.authorization.k8s.io
EOF

# Create kubeconfig files for each namespace
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
