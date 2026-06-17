SHELL        := /bin/bash

# Répertoire absolu du Makefile — fonctionne quelle que soit l'origine de l'appel
ROOT_DIR     := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

TFVARS       ?= $(ROOT_DIR)terraform.tfvars
KEY_FILE     ?= $(ROOT_DIR)td2-99-key.pem
ANSIBLE_DIR  := $(ROOT_DIR)ansible
INVENTORY    := $(ANSIBLE_DIR)/inventory/hosts.ini

.PHONY: all init fmt validate plan apply inventory provision verify destroy clean

# ─── Cycle complet ──────────────────────────────────────────────────────────

all: init apply inventory provision

# ─── Terraform ──────────────────────────────────────────────────────────────

TF           := terraform -chdir=$(ROOT_DIR)

init:
	$(TF) init

fmt:
	$(TF) fmt -recursive

validate: init
	$(TF) validate

plan: init
	$(TF) plan -var-file=$(TFVARS)

apply: init
	$(TF) apply -var-file=$(TFVARS) -auto-approve

destroy:
	$(TF) destroy -var-file=$(TFVARS) -auto-approve

# ─── Inventaire Ansible ─────────────────────────────────────────────────────

inventory:
	@echo "==> Generation de l'inventaire Ansible..."
	@mkdir -p $(ANSIBLE_DIR)/inventory
	@cd $(ROOT_DIR) && KEY_FILE=$(KEY_FILE) bash scripts/gen_inventory.sh > $(INVENTORY)
	@echo "==> Inventaire genere :"
	@cat $(INVENTORY)

# ─── Ansible ────────────────────────────────────────────────────────────────

provision: inventory
	@echo "==> Installation de Suricata via Ansible..."
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/hosts.ini playbooks/site.yml

verify: inventory
	@echo "==> Verification des alertes Suricata..."
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory/hosts.ini playbooks/verify.yml

# ─── Nettoyage ──────────────────────────────────────────────────────────────

clean:
	rm -rf .terraform .terraform.lock.hcl terraform.tfstate.backup
	rm -f $(INVENTORY)

# ─── Aide ───────────────────────────────────────────────────────────────────

help:
	@echo ""
	@echo "Usage : make [cible] [KEY_FILE=~/.ssh/ma_cle.pem] [TFVARS=terraform.tfvars]"
	@echo ""
	@echo "Cibles disponibles :"
	@echo "  all        init + apply + inventory + provision  (cycle complet)"
	@echo "  init       terraform init"
	@echo "  fmt        terraform fmt"
	@echo "  validate   terraform validate"
	@echo "  plan       terraform plan"
	@echo "  apply      terraform apply"
	@echo "  inventory  genere ansible/inventory/hosts.ini depuis les outputs Terraform"
	@echo "  provision  installe Suricata sur la sonde via Ansible"
	@echo "  verify     genere du trafic ICMP et verifie les alertes Suricata"
	@echo "  destroy    terraform destroy (detruit toutes les ressources)"
	@echo "  clean      supprime .terraform et l'inventaire genere"
	@echo ""
