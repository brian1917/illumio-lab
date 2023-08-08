#!/bin/bash

# Make sure in right directory
cd /Users/brian.pitta/illumio-lab/k8s-lab/php-guestbook

# Apply files
kubectl create -f guestbook-namespace.yaml
kubectl apply -f redis-leader-deployment.yaml
kubectl apply -f redis-leader-service.yaml
kubectl apply -f redis-follower-deployment.yaml
kubectl apply -f redis-follower-service.yaml
kubectl apply -f frontend-deployment.yaml
kubectl apply -f frontend-service.yaml
# kubectl apply -f frontend-ingress.yaml