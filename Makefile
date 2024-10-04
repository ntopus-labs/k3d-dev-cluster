include .env
##
## usage: make <command> 
##

# source: https://gist.github.com/prwhite/8168133
# Add the following 'help' target to your Makefile
# And add help text after each target name starting with '##'
################################################################################
# Help target
################################################################################
##
## General Commands 
##
help:: ## show this help text
	@gawk -vG=$$(tput setaf 2) -vR=$$(tput sgr0) ' \
	  match($$0, "^(([^#:]*[^ :]) *:)?([^#]*)##([^#].+|)$$",a) { \
	    if (a[2] != "") { printf "    make %s%-18s%s %s\n", G, a[2], R, a[4]; next }\
	    if (a[3] == "") { print a[4]; next }\
	    printf "\n%-36s %s\n","",a[4]\
	  }' $(MAKEFILE_LIST)
	@echo "" # blank line at the end
.DEFAULT_GOAL := help

##
## Setup commands 
##

create-k8s-cluster: ## Create cluster using k3d
	k3d cluster create ntopus-lab -p 8080:80 --k3s-arg "--disable=traefik@server:*"
	
rm-k8s-cluster: ## Remove cluster using k3d
	k3d cluster rm ntopus-lab

setup-k8s-cluster: setup-k8s-gw-api load-application-in-k8s ## Setup cluster to initialize GW and defualt services

setup-k8s-gw-api: add-datawire-helm install-emissary-ingress apply-emmisary-ingress-routes

add-datawire-helm:
	# Add the Repo:
	helm repo add datawire https://app.getambassador.io
	helm repo update

install-emissary-ingress:
	# Create Namespace and Install:
	kubectl create namespace emissary && \
	kubectl apply -f https://app.getambassador.io/yaml/emissary/${EMISSARY_INGRESS_IMAGE_VER}/emissary-crds.yaml
	
	kubectl wait --timeout=90s --for=condition=available deployment emissary-apiext -n emissary-system
	
	helm install emissary-ingress --namespace emissary datawire/emissary-ingress --version=${EMISSARY_INGRESS_HELM_VER} --set image.tag=${EMISSARY_INGRESS_IMAGE_VER} --values helm-emissary-ingress-values.yaml && \
	kubectl -n emissary wait --for condition=available --timeout=90s deploy -lapp.kubernetes.io/instance=emissary-ingress

apply-emmisary-ingress-routes:
	kubectl apply -f ./emissary-ingress/

load-application-in-k8s:
	kubectl apply -f https://app.getambassador.io/yaml/v2-docs/${EMISSARY_INGRESS_IMAGE_VER}/quickstart/qotm.yaml