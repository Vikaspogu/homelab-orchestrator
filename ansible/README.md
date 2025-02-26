# Ansible Automation

## Pre-reqs

1. Get offline [token](https://access.redhat.com/management/api)
2. Update the token in `extra_vars.json` file
3. Get Automation Hub [token](https://console.redhat.com/ansible/automation-hub/token)
4. Update the `token` key in `ansible.cfg` under `[galaxy_server.automation_hub_certified]` section

## Installation of Ansible Automation Platform

```bash
ansible-galaxy install -r ansible/requirements.yaml --force -c
ansible-playbook -i ansible/inventory/hosts.yaml ansible/playbooks/awx/create.yaml -e @extra_vars.json
ansible-playbook -i ansible/inventory/hosts.yaml ansible/playbooks/awx/config.yaml -e @extra_vars.json
```
