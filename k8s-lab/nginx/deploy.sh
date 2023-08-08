#!/bin/bash

#Make sure in right directory
cd /Users/brian.pitta/illumio-lab/k8s-lab/nginx

#Apply the files
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
# kubectl apply -f ingress.yaml