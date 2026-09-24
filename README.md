# Master Microservices with Spring Boot, Docker, Kubernetes

[![Image](https://github.com/eazybytes/microservices/blob/3.2.0/Microservice.png "Master Microservices with Java, Spring, Docker, Kubernetes")](https://www.udemy.com/course/master-microservices-with-spring-docker-kubernetes/?referralCode=9365DB9B7EE637F629A9)

Learn how to create enterprise and production ready Microservices with Spring, Spring Cloud, Docker and Kubernetes.

## Topics covered in the course
* Section 1 - Introduction to Microservices Architecture
* Section 2- Building microservices using Spring Boot
* Section 3 - How do we right size our microservices & identify boundaries
* Section 4 - Handle deployment, portability &  scalability of microservices using Docker
* Section 5 - Deep Dive on Cloud Native Apps & 15-Factor methodology
* Section 6 - Configurations Management in Microservices
* Section 7 - Using MySQL DBs inside microservices
* Section 8 - Service Discovery & Service Registration in microservices
* Section 9 - Gateway, Routing & Cross cutting concerns in Microservices
* Section 10 - Making Microservices Resilient
* Section 11 - Observability and monitoring of microservices
* Section 12 - Microservices Security
* Section 13 - Event Driven microservices using RabbitMQ,Spring Cloud Functions & Stream
* Section 14 - Event Driven microservices using Kafka,Spring Cloud Functions & Stream
* Section 15 - Container Orchestration using Kubernetes
* Section 16 - Deep dive on Helm
* Section 17 - Server-side service discovery and load balancing using Kubernetes
* Section 18 - Deploying microservices into cloud K8s cluster
* Section 19 - Introduction to K8s Ingress, Service Mesh (Istio) & mTLS
* Section 20 - Congratulations & Thank You

## Pre-requisite for the course
- Good understanding on Java and Spring concepts
- Basic understanding on SpringBoot & REST services is a bonus but not mandatory
- Interest to learn and explore about Microservices

# Important Links
- Spring Boot - https://spring.io/projects/spring-boot
- Create SpringBoot project - https://start.spring.io
- DTO pattern blog - https://martinfowler.com/eaaCatalog/dataTransferObject.html
- Model Mapper - http://modelmapper.org/
- Map Struct - https://mapstruct.org/
- Spring Doc - https://springdoc.org/
- Open API - https://www.openapis.org/
- Lucidchart Blog - https://www.lucidchart.com/blog/ddd-event-storming
- Docker website - https://www.docker.com
- Docker hub website - https://hub.docker.com
- Buildpacks website - https://buildpacks.io
- Google Jib website - https://github.com/GoogleContainerTools/jib
- Docker compose website - https://docs.docker.com/compose/
- Twelve-Factor methodology - https://12factor.net
- Beyond the Twelve-Factor App book - https://www.oreilly.com/library/view/beyond-the-twelve-factor/9781492042631/
- Spring Cloud website - https://spring.io/projects/spring-cloud
- Spring Cloud Config website - https://spring.io/projects/spring-cloud-config
- Spring Cloud Bus website - https://spring.io/projects/spring-cloud-bus
- RabbitMQ website - https://www.rabbitmq.com
- Hookdeck website- https://hookdeck.com
- Spring Cloud Netflix website - https://spring.io/projects/spring-cloud-netflix
- Spring Cloud OpenFeign - https://spring.io/projects/spring-cloud-openfeign
- Netflix Blog - https://netflixtechblog.com/netflix-oss-and-spring-boot-coming-full-circle-4855947713a0
- Resilience4j website - https://resilience4j.readme.io
- Spring Cloud Gateway website - https://spring.io/projects/spring-cloud-gateway
- Stripe RateLimitter pattern blog - https://stripe.com/blog/rate-limiters
- Apache Benchmark website - https://httpd.apache.org
- Grafana website - https://grafana.com
- Grafana Loki setup - https://grafana.com/docs/loki/latest/get-started/quick-start/
- Micrometer website - https://micrometer.io
- Prometheus website - https://prometheus.io/
- Grafana Dashboards - https://grafana.com/grafana/dashboards/
- OpenTelemetry website - https://opentelemetry.io/
- OpenTelemetry automatic instrumentation - https://opentelemetry.io/docs/instrumentation/java/automatic/
- Keycloak website - https://www.keycloak.org/
- Apache Kafka website - https://kafka.apache.org
- Docker compose file for Kafka - https://github.com/bitnami/containers/blob/main/bitnami/kafka/docker-compose.yml
- Local Kubernetes Cluster with Docker Desktop - https://docs.docker.com/desktop/kubernetes/
- Kubernetes Dashboard - https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/
- Helm website - https://helm.sh
- Chocolatey website - https://chocolatey.org/
- Bitnami Helm charts GitHub repo - https://github.com/bitnami/charts
- Spring Cloud Kubernetes website - https://spring.io/projects/spring-cloud-kubernetes
- Spring Cloud Kubernetes Blog - https://spring.io/blog/2021/10/26/new-features-for-spring-cloud-kubernetes-in-spring-cloud-2021-0-0-m3
- GCP website - https://cloud.google.com
- GCP SDK installation - https://cloud.google.com/sdk/docs/install
- Kubernetes Ingress - https://kubernetes.io/docs/concepts/services-networking/ingress/
- Ingress Controllers - https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/
- Istio (Service mesh) - https://istio.io


## Maven Commands used in the course

|     Maven Command       |     Description          |
| ------------- | ------------- |
| "mvn clean install -Dmaven.test.skip=true" | To generate a jar inside target folder |
| "mvn spring-boot:run" | To start a springboot maven project |
| "mvn spring-boot:build-image" | To generate a docker image using Buildpacks. No need of Dockerfile |
| "mvn compile jib:dockerBuild" | To generate a docker image using Google Jib. No need of Dockerfile |

## Docker Commands used in the course

|     Docker Command       |     Description          |
| ------------- | ------------- |
| "docker build . -t eazybytes/accounts:s4" | To generate a docker image based on a Dockerfile |
| "docker run  -p 8080:8080 eazybytes/accounts:s4" | To start a docker container based on a given image |
| "docker images" | To list all the docker images present in the Docker server |
| "docker image inspect image-id" | To display detailed image information for a given image id |
| "docker image rm image-id" | To remove one or more images for a given image ids |
| "docker image push docker.io/eazybytes/accounts:s4" | To push an image or a repository to a registry |
| "docker image pull docker.io/eazybytes/accounts:s4" | To pull an image or a repository from a registry |
| "docker ps" | To show all running containers |
| "docker ps -a" | To show all containers including running and stopped |
| "docker container start container-id" | To start one or more stopped containers |
| "docker container pause container-id" | To pause all processes within one or more containers |
| "docker container unpause container-id" | To unpause all processes within one or more containers |
| "docker container stop container-id" | To stop one or more running containers |
| "docker container kill container-id" | To kill one or more running containers instantly |
| "docker container restart container-id" | To restart one or more containers |
| "docker container inspect container-id" | To inspect all the details for a given container id |
| "docker container logs container-id" | To fetch the logs of a given container id |
| "docker container logs -f container-id" | To follow log output of a given container id |
| "docker container rm container-id" | To remove one or more containers based on container ids |
| "docker container prune" | To remove all stopped containers |
| "docker compose up" | Creates and starts containers based on the given Docker Compose file |
| "docker compose down" | Stops and removes containers, networks, volumes, and images created by up |
| "docker compose start" | Starts existing (previously created) containers without recreating them |
| "docker compose stop" | Stops running containers without removing them |
| "docker run -p 3306:3306 --name accountsdb -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=accountsdb -d mysql" | To create a MySQL DB container |
| "docker run -p 6379:6379 --name eazyredis -d redis" | To create a Redis Container |
| "docker run -p 8080:8080 -e KEYCLOAK_ADMIN=admin -e KEYCLOAK_ADMIN_PASSWORD=admin quay.io/keycloak/keycloak:22.0.3 start-dev" | To create Keycloak Container|


## Apache Benchmark command used in the course

|     Apache Benchmark command      |     Description          |
| ------------- | ------------- |
| "ab -n 10 -c 2 -v 3 http://localhost:8072/eazybank/cards/api/contact-info" | To perform load testing on API by sending 10 requests |

## Kubernetes Commands used in the course

|     Kubernetes Command       |     Description          |
| ------------- | ------------- |
| "kubectl config get-contexts" | To list the contexts (clusters that kubectl can talk to) |
| "kubectl config get-clusters" | To list the clusters that kubectl knows about |
| "kubectl config use-context [CONTEXT_NAME]" | To switch kubectl to a given context |
| "kubectl get nodes" | To list the nodes inside your cluster |
| "kubectl get nodes -o wide" | To list the nodes with extra details, including each node's internal IP |
| "kubectl get namespaces" | To list all the namespaces inside your cluster |
| "kubectl create namespace [NAMESPACE]" | To create a namespace imperatively |
| "kubectl describe namespace [NAMESPACE]" | To show detailed information about a given namespace |
| "kubectl get namespaces -l [LABEL_KEY]=[LABEL_VALUE]" | To find namespaces by label |
| "kubectl delete namespace [NAMESPACE]" | To delete a namespace along with everything inside it |
| "kubectl apply -f [FILE_NAME]" | To create or update the K8s objects defined in a given YAML file |
| "kubectl apply -f [FILE_NAME_1] -f [FILE_NAME_2]" | To create or update the K8s objects defined in multiple YAML files in one command |
| "kubectl get configmaps -n [NAMESPACE]" | To list the ConfigMaps inside a namespace |
| "kubectl describe configmap [CONFIGMAP_NAME] -n [NAMESPACE]" | To show the details of a given ConfigMap |
| "kubectl get secrets -n [NAMESPACE]" | To list the Secrets inside a namespace |
| "kubectl describe secret [SECRET_NAME] -n [NAMESPACE]" | To show the details of a given Secret (values stay hidden) |
| "kubectl get secret [SECRET_NAME] -n [NAMESPACE] -o yaml" | To show the full Secret object, including the Base64-encoded values |
| "kubectl get deployments -n [NAMESPACE]" | To list the Deployments inside a namespace |
| "kubectl get replicasets -n [NAMESPACE]" | To list the ReplicaSets inside a namespace |
| "kubectl get pods -n [NAMESPACE]" | To list the pods inside a namespace |
| "kubectl get pods -n [NAMESPACE] -o wide" | To list the pods with extra details, like the node and pod IP |
| "kubectl get pods -n [NAMESPACE] -w" | To watch pod status changes live (Ctrl+C to stop) |
| "kubectl describe pod [POD_NAME] -n [NAMESPACE]" | To show the details of a given pod, including the Events section |
| "kubectl delete pod [POD_NAME] -n [NAMESPACE]" | To delete a given pod (useful to watch self-healing) |
| "kubectl logs [POD_NAME] -n [NAMESPACE]" | To view the container logs of a given pod |
| "kubectl logs deploy/[DEPLOYMENT_NAME] -n [NAMESPACE]" | To view the container logs of a pod belonging to a given Deployment |
| "kubectl logs -f deploy/[DEPLOYMENT_NAME] -n [NAMESPACE]" | To follow the container logs of a pod belonging to a given Deployment |
| "kubectl exec -it deploy/[DEPLOYMENT_NAME] -n [NAMESPACE] -- [COMMAND]" | To run a command inside a container of a given Deployment |
| "kubectl get services -n [NAMESPACE]" | To list the Services inside a namespace, including their types and external IPs |
| "kubectl describe service [SERVICE_NAME] -n [NAMESPACE]" | To show the details of a given Service, including its endpoints |
| "kubectl port-forward service/[SERVICE_NAME] [LOCAL_PORT]:[SERVICE_PORT] -n [NAMESPACE]" | To forward a local port to a given Service |
| "kubectl get all -n [NAMESPACE] -l [LABEL_KEY]=[LABEL_VALUE]" | To list all the components inside a namespace matching a given label |
| "kubectl get events -n [NAMESPACE]" | To list the events that occurred inside a namespace |
| "kubectl get events -n [NAMESPACE] --sort-by=.metadata.creationTimestamp" | To list the events sorted by creation time, so the latest appear last |
| "kubectl rollout status deployment/[DEPLOYMENT_NAME] -n [NAMESPACE]" | To wait for the rollout of a given Deployment to complete |
| "kubectl rollout history deployment/[DEPLOYMENT_NAME] -n [NAMESPACE]" | To show the revision history of a given Deployment |
| "kubectl annotate deployment/[DEPLOYMENT_NAME] kubernetes.io/change-cause=\"[MESSAGE]\" -n [NAMESPACE]" | To record a note about a change (shown in the CHANGE-CAUSE column of the rollout history) |
| "kubectl rollout undo deployment/[DEPLOYMENT_NAME] -n [NAMESPACE]" | To roll back a given Deployment to its previous revision |
| "kubectl rollout undo deployment/[DEPLOYMENT_NAME] --to-revision=[REVISION] -n [NAMESPACE]" | To roll back a given Deployment to a specific revision |
| "kubectl run [POD_NAME] --rm -it --image=[IMAGE] -n [NAMESPACE] -- sh" | To start a temporary pod with a shell, deleted automatically on exit |

## Helm Commands used in the course

|     Helm Command       |     Description          |
| ------------- | ------------- |
| "helm create [NAME]" | Create a default chart with the given name |
| "helm dependencies build" | To recompile the given helm chart |
| "helm install [NAME] [CHART]" | Install the given helm chart into K8s cluster |
| "helm upgrade [NAME] [CHART]" | Upgrades a specified release to a new version of a chart |
| "helm history [NAME]" | Display historical revisions for a given release |
| "helm rollback [NAME] [REVISION]" | Roll back a release to a previous revision |
| "helm uninstall [NAME]" | Uninstall all of the resources associated with a given release |
| "helm template [NAME] [CHART]" | Render chart templates locally along with the values |
| "helm list" | Lists all of the helm releases inside a K8s cluster |
