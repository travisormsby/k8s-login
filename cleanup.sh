for ns in $(kubectl get namespaces -o name | grep "kube[0-9][0-9]" | cut -c 11-); 
do 
  kubectl delete all --all -n $ns; 
done
