# kubernetes gateway deployment example
this repo is trying to show some different ways to blue/green a simple docker app in kubernetes
comparing:
* HTTPRoute with manual weights
* flagger
* argo rollouts


## basic global setup
```
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/experimental-install.yaml
helm install kong --namespace kong --create-namespace --repo https://charts.konghq.com ingress


# build image
docker build -t example-docker-image .

# copy into k3s
version=v3; docker build -t example-docker-image:$version . && docker save example-docker-image:$version | ssh 10.42.0.122 k3s ctr images import -

# create global kong gateway
# could also be done in a per-namespace way, I tried both
kubectl apply -f gateway.yaml
```

## different approaches
### manual blue/green
* two deployment/service pairs
* HTTP route that points to both with routing weights
* ingress that points to one of them

```
# apply the configs
kubectl apply -f "manual-blue-green/*.yaml"

echo "get gateway"
curl $host/gw
# see how it chooses blue and green 50/50

echo "get ingress"
curl $host/ingress
```

### flagger and flagger-example
* deployment(app-deployment) with 0 replicas
* Flagger Canary that points to the deployment
  * this will create another deployment (app-deployment-primary) with replicas
  * it will also create three services (app-deployment, app-deployment-primary, app-deployment-canary)

when you update the deployment
* flagger will create another deployment (app-deployment-canary)
* if all the steps pass for metrics like success rate and response time over the canary rollout:
  * copy canary deployment/svc settings into the primary, deploy those, and then route traffic back to them away from the canary and tear down the canary

flagger deployment metrics analysis: https://docs.flagger.app/usage/metrics

Flagger has webhooks that can be used to gate the canary deployment, based on what teh url it calls returns

Flagger has webhooks it uses in it's examples to generate load for the analyiss, but they seem to be poorly timed (the rollout hook fires at the same time the check for metrics happens, so unelss you apply load at the pre-rollout as well as rollout, it will complain about a lack of metrics)

flagger cannot retry (FAQ says to just edit an annotation and reapply the deployment) or pause/abort a deployment unlike argo rollouts
```
helm upgrade -i flagger flagger/flagger \
--namespace flagger \
--create-namespace \
--set prometheus.install=true \
--set meshProvider=kubernetes


kubectl create ns test
helm upgrade -i flagger-loadtester flagger/loadtester --namespace=test

kubectl apply -f "flagger/app/*.yaml"

# edit flagger/flagger-deployment.yaml attribute deployment_slot
# re-apply to trigger a deployment
kubectl apply -f flagger/flagger-deployment.yaml

# watch logs
kubectl -n flagger logs deployment/flagger -f  | jq -R -r 'fromjson? | .ts + ": " + .msg'

# show deployment status:
kubectl -n test describe canary/app-canary


# uninstall
kubectl delete -f "flagger/app/*.yaml"
helm uninstall -n flagger flagger
kubectl -n test delete service/flagger-loadtester
kubectl -n test delete deployment.apps/flagger-loadtester
kubectl delete namespace test
```

`flagger/example` is the [flagger Blue/Green](https://docs.flagger.app/tutorials/kubernetes-blue-green) example


### argo rollouts
traffic routing plugins are alpha, and the gateway api is a plugin unlike things directly supported meshes. Unlike flagger, they do call out having tested Kong instead of posts saying "it should work I dunno"

* two services
* http route pointing at those two services
* Argo Rollout pointing at the http route and two services, configured like a deployment cause it has stuff like replicas, rollout strategy, image

has rollout pause/abort/retry

analysis: https://argo-rollouts.readthedocs.io/en/stable/features/analysis/
```
# install argo
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# install argo kubectl plugin
curl -o ~/.local/bin/kubectl-argo-rollouts https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x ~/.local/bin/kubectl-argo-rollouts

# TODO https://argo-rollouts.readthedocs.io/en/stable/installation/#shell-auto-completion


# uninstall
kubectl delete -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
kubectl delete ns argo-rollouts
```
argo/argo.yaml is the argo gateway api install thing
argo/example/example.yaml is their base example
argo/example/gateway-api.yaml is their gateway-api example

## misc
get all dns records:
```
nameserver=$(kubectl -n kube-system get svc kube-dns -o json | jq -r '.spec.clusterIP')
kubectl get -A svc -o json | jq -r '.items[] | .spec.clusterIP | select(. != "None")' | xargs -I{} nslookup "{}" "$nameserver"
```
