FRONTEND_IMAGE=ghcr.io/kwkoo/llava-frontend
PROJ=demo

BASE:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

.PHONY: deploy ensure-logged-in deploy-nfd deploy-nvidia deploy-ollama deploy-frontend frontend-image

deploy: deploy-nvidia deploy-ollama
	@echo "installation completed"

ensure-logged-in:
	oc whoami
	@echo 'user is logged in'

deploy-nfd: ensure-logged-in
	@echo "deploying NodeFeatureDiscovery operator..."
	oc apply -f $(BASE)/yaml/nfd-operator.yaml
	@/bin/echo -n 'waiting for NodeFeatureDiscovery CRD...'
	@until oc get crd nodefeaturediscoveries.nfd.openshift.io >/dev/null 2>/dev/null; do \
	  /bin/echo -n '.'; \
	  sleep 5; \
	done
	@echo 'done'
	oc apply -f $(BASE)/yaml/nfd-cr.yaml
	@/bin/echo -n 'waiting for nodes to be labelled...'
	@while [ `oc get nodes --no-headers -l 'feature.node.kubernetes.io/pci-10de.present=true' 2>/dev/null | wc -l` -lt 2 ]; do \
	  /bin/echo -n '.'; \
	  sleep 5; \
	done
	@echo 'done'
	@echo 'NFD operator installed successfully'

deploy-nvidia: deploy-nfd
	@echo "deploying nvidia GPU operator..."
	oc apply -f $(BASE)/yaml/nvidia-operator.yaml
	@/bin/echo -n 'waiting for ClusterPolicy CRD...'
	@until oc get crd clusterpolicies.nvidia.com >/dev/null 2>/dev/null; do \
	  /bin/echo -n '.'; \
	  sleep 5; \
	done
	@echo 'done'
	oc apply -f $(BASE)/yaml/cluster-policy.yaml
	@/bin/echo -n 'waiting for nvidia-device-plugin-daemonset...'
	@until oc get -n nvidia-gpu-operator ds/nvidia-device-plugin-daemonset >/dev/null 2>/dev/null; do \
	  /bin/echo -n '.'; \
	  sleep 5; \
	done
	@echo "done"
	@DESIRED="`oc get -n nvidia-gpu-operator ds/nvidia-device-plugin-daemonset -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null`"; \
	if [ "$$DESIRED" -lt 1 ]; then \
	  echo "could not get desired replicas"; \
	  exit 1; \
	fi; \
	echo "desired replicas = $$DESIRED"; \
	/bin/echo -n "waiting for $$DESIRED replicas to be ready..."; \
	while [ "`oc get -n nvidia-gpu-operator ds/nvidia-device-plugin-daemonset -o jsonpath='{.status.numberReady}' 2>/dev/null`" -lt "$$DESIRED" ]; do \
	  /bin/echo -n '.'; \
	  sleep 5; \
	done
	@echo "done"
	@echo "checking that worker nodes have access to GPUs..."
	@for po in `oc get po -n nvidia-gpu-operator -o name -l app=nvidia-device-plugin-daemonset`; do \
	  echo "checking $$po"; \
	  oc rsh -n nvidia-gpu-operator $$po nvidia-smi; \
	done

deploy-ollama:
	@echo "deploying ollama..."
	-oc new-project $(PROJ)
	@/bin/echo -n "waiting for limitrange to appear..."
	@until oc get -n $(PROJ) limitrange >/dev/null 2>/dev/null;do \
	  /bin/echo -n "."; \
	  sleep 5; \
	done
	@echo "done"
	oc get limitrange -n $(PROJ) -o name | xargs oc delete -n $(PROJ)
	oc apply -n $(PROJ) -f $(BASE)/yaml/ollama.yaml
	oc rollout status sts/ollama -n $(PROJ) -w --timeout=600s

deploy-frontend:
	oc apply -n $(PROJ) -f $(BASE)/yaml/llava-frontend.yaml
	@/bin/echo -n "waiting for route..."
	@until oc get -n $(PROJ) route/llava-frontend >/dev/null 2>/dev/null; do \
	  /bin/echo -n "."; \
	  sleep 5; \
	done
	@echo "done"
	@echo "access the frontend at http://`oc get -n $(PROJ) route/llava-frontend -o jsonpath='{.spec.host}'`"

frontend-image:
	docker build -t $(FRONTEND_IMAGE) $(BASE)/frontend
	docker push $(FRONTEND_IMAGE)
