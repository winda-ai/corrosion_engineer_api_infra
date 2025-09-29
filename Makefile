REGION ?= us-east-1
ENV ?= dev

tf-init:
	terraform -chdir=main init -backend-config=../stages/$(ENV)/$(REGION)/backend.conf -force-copy

tf-plan:
	terraform -chdir=main plan \
	-out tf.plan \
	-var-file=../stages/$(ENV)/tier.tfvars \
	-var-file=../stages/$(ENV)/$(REGION)/inputs.tfvars

tf-apply-from-plan:
	terraform -chdir=main apply tf.plan

tf-plan-destroy:
	terraform -chdir=main plan -destroy \
	-var-file=../stages/$(ENV)/tier.tfvars \
	-var-file=../stages/$(ENV)/$(REGION)/inputs.tfvars

tf-destroy:
	terraform -chdir=main destroy -auto-approve \
	-var-file=../stages/$(ENV)/tier.tfvars \
	-var-file=../stages/$(ENV)/$(REGION)/inputs.tfvars

clean:
	rm -f main/tf.plan
	rm -rf main/.terraform
	rm -f main/.terraform.lock.hcl