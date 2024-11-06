Create namespaces, Role- and ClusterRoleBindings, and kubeconfig files to allow temporary namespace admin access to a Kubernetes cluster

As a user with cluster-admin level access, run the create-namespaces.sh script with three arguments

* The start number to append to the namespace name 
* The end number to append to the namespace name
* The expiration time in days of certificate in the kubeconfig file

For example, `./create-namespaces.sh 1 15 3` will create 15 namespaces named kube01 through kube15. Each kubeconfig file will be able to access the cluster for 3 days. 

This will also create a new ClusterRole called view-all that enables the user to get, watch, and list all resources, as well as to create, update patch, and delete prometheus resources (this is necessary to allow the user to see metrics in OpenLens). The script uses a ClusterRoleBinding to assign this ClusterRole to users whose names match the namespace names. It also uses a RoleBinding to assign the admin ClusterRole to each user, scoped to their matching namespace.

This will create a number of kubeconfig files, matching each namespace, that you can distribute to people who need temporary access.

The delete-content.sh script can be used in a similar fashion to delete all the namespaces. **WARNING**: this script will also delete any released Persistent Volumes. That's necessary for my use case, but you may not want that behavior.
