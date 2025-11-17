# kubernetes gateway deployment example


```
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
helm install kong --namespace kong --create-namespace --repo https://charts.konghq.com ingress

helm upgrade -i flagger flagger/flagger \
--namespace flagger \
--create-namespace \
--set prometheus.install=true \
--set meshProvider=kubernetes


helm upgrade -i flagger-loadtester flagger/loadtester --namespace=test


kubectl create namespace app-prod

# build image
docker build -t example-docker-image .

# copy into k3s
version=v3; docker build -t example-docker-image:$version . && docker save example-docker-image:$version | ssh 10.42.0.122 k3s ctr images import -
```

## manual blue/green
use http route weights to switch between blue/green
```
# apply the configs
kubectl apply -f "manual-blue-green/*.yaml"

echo "get gateway"
curl $host/gw

echo "get ingress"
curl $host/ingress
```

## flagger and flagger-example
flagger-example is the [flagger Blue/Green](https://docs.flagger.app/tutorials/kubernetes-blue-green) example

flagger is my attempt at it

## misc
get all dns records:
```
nameserver=$(kubectl -n kube-system get svc kube-dns -o json | jq -r '.spec.clusterIP')
kubectl get -A svc -o json | jq -r '.items[] | .spec.clusterIP | select(. != "None")' | xargs -I{} nslookup "{}" "$nameserver"
```
