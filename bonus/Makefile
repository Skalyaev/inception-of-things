CLUSTER_NAME=iot

K8S_DIR=k8s
ARGOCD_DIR=$(K8S_DIR)/argocd

ARGOCD_MANIFEST=$(ARGOCD_DIR)/application.yaml

SCRIPT_DIR=script
GITLAB_DIR=$(SCRIPT_DIR)/gitlab

SETUP_SCRIPT=$(SCRIPT_DIR)/setup.sh
GITLAB_UP_SCRIPT=$(GITLAB_DIR)/up.sh
GITLAB_DOWN_SCRIPT=$(GITLAB_DIR)/down.sh
SWITCH_SCRIPT=$(GITLAB_DIR)/switch.sh

GITLAB_NAMESPACE=gitlab
GITLAB_LOCAL_URL=gitlab.local:8080
GITLAB_INTERN_URL=gitlab-webservice-default.gitlab.svc.cluster.local:8181
GITLAB_PROJECT_URI=anguinau/inception-of-things

APPLICATION_NAMESPACE=argocd
APPLICATION_NAME=application

ETC_HOSTS_SED_IP=/^[[:space:]]*127\.0\.0\.1[[:space:]]
ETC_HOSTS_SED_DOMAIN=\+gitlab\.local[[:space:]]*$$/d

all: up

up:
	@sed -i "s|\$$(GITLAB_URL)|$(GITLAB_INTERN_URL)|g" "$(ARGOCD_MANIFEST)"
	@sed -i "s|\$$(GITLAB_URI)|$(GITLAB_PROJECT_URI)|g" "$(ARGOCD_MANIFEST)"

	@bash "$(SETUP_SCRIPT)" "$(CLUSTER_NAME)"

	@bash "$(GITLAB_UP_SCRIPT)" \
		"$(GITLAB_NAMESPACE)" \
		"$(GITLAB_LOCAL_URL)" \
		"$(GITLAB_PROJECT_URI)"

stop:
	@k3d cluster stop "$(CLUSTER_NAME)"

start:
	@k3d cluster start "$(CLUSTER_NAME)"

clean:
	@-bash "$(GITLAB_DOWN_SCRIPT)" \
		"$(GITLAB_NAMESPACE)" \
		"$(GITLAB_LOCAL_URL)" \
		"$(GITLAB_PROJECT_URI)"

	@-k3d cluster delete "$(CLUSTER_NAME)"

	@-kubectl config delete-context "k3d-$(CLUSTER_NAME)" 2>'/dev/null'
	@-kubectl config delete-cluster "k3d-$(CLUSTER_NAME)" 2>'/dev/null'
	@-kubectl config unset "users.k3d-$(CLUSTER_NAME)" 2>'/dev/null'

	@-sudo sed -i \
		"$(ETC_HOSTS_SED_IP)$(ETC_HOSTS_SED_DOMAIN)" '/etc/hosts'

	@-sed -i "s|$(GITLAB_INTERN_URL)|\$$(GITLAB_URL)|g" "$(ARGOCD_MANIFEST)"
	@-sed -i "s|$(GITLAB_PROJECT_URI)|\$$(GITLAB_URI)|g" "$(ARGOCD_MANIFEST)"

re: clean up

argocd-password:
	@kubectl -n argocd get secret 'argocd-initial-admin-secret' \
		-o jsonpath='{.data.password}' | base64 -d; echo

argocd-webapp:
	@kubectl -n 'argocd' port-forward 'deploy/argocd-server' '9090:8080'

switch-version:
	@bash "$(SWITCH_SCRIPT)" \
		"$(GITLAB_NAMESPACE)" \
		"$(GITLAB_LOCAL_URL)" \
		"$(GITLAB_PROJECT_URI)" \
		"$(APPLICATION_NAMESPACE)" \
		"$(APPLICATION_NAME)"

.PHONY: all up stop start clean re \
	argocd-password argocd-webapp switch-version
