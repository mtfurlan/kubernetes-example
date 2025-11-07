# kubernetes gateway deployment example


```
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
helm install kong --namespace kong --create-namespace --repo https://charts.konghq.com ingress

# build image
docker build -t example-docker-image .

# copy into k3s
docker save example-docker-image:latest | ssh $host k3s ctr images import -

kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f gateway.yaml
curl -i $host -H "Host: foo.tld"
```
