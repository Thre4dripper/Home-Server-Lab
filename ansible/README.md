# Ansible Playbooks

Ansible roles for provisioning the Raspberry Pi from scratch after a reflash.

## Structure

```
ansible/
├── inventory/      # Host definitions
├── group_vars/     # Shared variables
└── roles/          # Playbook roles
    ├── base/           # Packages, locale, timezone, SSH hardening
    ├── docker/         # Docker CE install + compose plugin
    ├── k3s/            # k3s install with custom config
    ├── ufw/            # Firewall rules
    └── storage/        # Mount points, Longhorn prereqs
```
