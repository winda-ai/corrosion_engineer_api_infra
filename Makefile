REGION ?= us-east-1
ENV ?= dev
BACKEND_CONFIG = ../workspace/$(ENV)/$(REGION)/backend.conf
VARS_FILE = ../workspace/$(ENV)/$(REGION)/terraform.tfvars

init:
	terraform -chdir=main init -backend-config=$(BACKEND_CONFIG)

plan:
	terraform -chdir=main plan -var-file=$(VARS_FILE)

apply:
	terraform -chdir=main apply -auto-approve -var-file=$(VARS_FILE)

destroy:
	terraform -chdir=main destroy -auto-approve -var-file=$(VARS_FILE)

outputs:
	terraform -chdir=main output

validate:
	terraform -chdir=main validate

clean:
	find main -name '*.tfstate*' -delete
	find main -name '.terraform' -type d -exec rm -rf {} +