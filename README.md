# kubernetes gateway deployment example


```
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
helm install kong --namespace kong --create-namespace --repo https://charts.konghq.com ingress


kubectl create namespace app-prod
# build image
docker build -t example-docker-image .

# copy into k3s
version=v3; docker build -t example-docker-image:$version . && docker save example-docker-image:$version | ssh 10.42.0.122 k3s ctr images import -

# apply the configs
kubectl apply -f "*.yaml"

# get host ip addr or just set this manually
host=$(kubectl get -n app-prod gateway example-app-gw -o json | jq -r '.status.addresses[0].value')


echo "get gateway"
curl $host/gw

echo "get ingress"
curl $host/ingress

```

get all dns records:
```
nameserver=$(kubectl -n kube-system get svc kube-dns -o json | jq -r '.spec.clusterIP')
kubectl get -A svc -o json | jq -r '.items[] | .spec.clusterIP | select(. != "None")' | xargs -I{} nslookup "{}" "$nameserver"
```
