kubectl create -f namespace.json
kubectl create -f redis-master-controller.json
kubectl create -f redis-master-service.json
kubectl create -f redis-slave-controller.json
kubectl create -f redis-slave-service.json
kubectl create -f guestbook-controller.json
kubectl create -f guestbook-service.json