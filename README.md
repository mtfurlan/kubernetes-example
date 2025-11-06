# kubernetes gateway deployment example

https://boxunix.com/2020/05/15/a-better-way-of-organizing-your-kubernetes-manifest-files/
https://dev.to/abhay_yt_52a8e72b213be229/how-to-deploy-docker-images-in-kubernetes-step-by-step-guide-2jj0

```
#something something minikube setup

# use minikube docker env, not your local
eval $(minikube docker-env)

# build image
docker build -t example-docker-image .


kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

minikube tunnel --cleanup

kubectl get svc

http://$external_IP
```
