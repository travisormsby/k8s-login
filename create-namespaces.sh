#! /bin/bash

# create ClusterRole to see everything and get metrics
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
done
