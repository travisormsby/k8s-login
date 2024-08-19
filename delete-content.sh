#! /bin/bash

# Delete the kube namespaces to destroy all namespace resources
for i in $(seq -f '%02.f' $1 $2); do
  name=kube${i}
  kubectl delete ns ${name}
done

# Delete all retained persistent volumes
kubectl get pv | grep Released | awk '{print $1}' | xargs kubectl delete pv

