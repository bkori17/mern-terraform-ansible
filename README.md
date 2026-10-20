# TravelMemory MERN Deployment on AWS using Terraform and Ansible

**Assignment:** Deploying a MERN Application through Terraform and Ansible  
**Application source:** [UnpredictablePrashant/TravelMemory](https://github.com/UnpredictablePrashant/TravelMemory)  
**Cloud:** AWS, Asia Pacific (Mumbai), `ap-south-1`  
**Infrastructure as Code:** Terraform  
**Configuration management:** Ansible

## 1. Project overview

This project automates an AWS deployment of the TravelMemory MERN application. Terraform creates the network, EC2 servers, security groups and instance IAM roles. Ansible configures a private MongoDB database and a public web server running React, Express/Node.js and Nginx.

The browser connects to Nginx over HTTP port 80. Nginx serves the compiled React frontend and forwards `/trip` and `/hello` API requests to Express on the same EC2 instance. Express accesses MongoDB using an authenticated, least-privilege account on the private EC2 instance.

**Deployment status at documentation time (20 October 2026):** Terraform provisioning, Ansible deployment, MongoDB authentication/read-write checks, web-server setup and public HTTP endpoint tests all succeeded. The frontend returned HTTP 200, `/hello` returned `Hello World!`, and `/trip` returned `[]` (an empty database). A browser-based create-and-refresh persistence test should be documented separately if performed; HTTP GET checks alone do not establish that browser writes have succeeded.

> **Important:** The observed public IP was `13.234.78.43` on 20 October 2026. The web instance does **not** have a persistent Elastic IP, so the public address may change after stopping and starting the instance. Always retrieve the current address from AWS/Terraform and update the Ansible inventory before redeploying. The production React bundle embeds the API base URL at build time, so rebuild the frontend when the public IP changes.

## 2. Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the Mermaid architecture diagram, detailed networking, security and data flows. See [IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md) for execution evidence and troubleshooting.

| Resource | Deployment configuration |
|---|---|
| VPC | `10.20.0.0/16` |
| Public subnet | `10.20.1.0/24` |
| Private subnet | `10.20.2.0/24` |
| Web EC2 private IP | `10.20.1.32` |
| MongoDB EC2 private IP | `10.20.2.140` |
| Web server | Ubuntu 24.04, Node.js 24, Nginx, React static build, Express |
| DB server | Ubuntu 24.04, AWS 6.8 LTS kernel, MongoDB 8.0 |
| Instance type | `t3.small` for both EC2 instances |
| Internet access | Internet Gateway for public subnet; NAT Gateway for private-subnet egress |
| Public inbound | HTTP `80`; SSH `22` restricted to an authorized source IP |
| Database inbound | SSH `22` and MongoDB `27017` only from the web security group |
| IAM | EC2 IAM instance roles/profiles, including SSM access |

## 3. Repository layout

```text
mern-terraform-ansible/
├── README.md
├── ARCHITECTURE.md
├── IMPLEMENTATION_REPORT.md
├── .gitignore
├── terraform/
│   ├── versions.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── vpc.tf
│   ├── networking.tf
│   ├── security_groups.tf
│   ├── iam.tf
│   ├── ec2.tf
│   ├── outputs.tf
│   └── .terraform.lock.hcl
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/hosts.ini
│   ├── playbooks/
│   │   ├── install-mongodb.yml
│   │   ├── configure-mongodb-users.yml
│   │   ├── secure-mongodb.yml
│   │   ├── test-mongodb-auth.yml
│   │   ├── install-web.yml
│   │   ├── deploy-backend.yml
│   │   └── deploy-frontend.yml
│   └── templates/
│       ├── backend.env.j2
│       ├── travelmemory-backend.service.j2
│       └── travelmemory-nginx.conf.j2
└── screenshots/
       |____01-terraform
       |____02-aws
       |____03-ansible
       |____04-application 
```

Some files or directories may vary in a local checkout. The original TravelMemory application is fetched by Ansible from its upstream GitHub repository and is not vendored into this submission. `application/TravelMemory/` is a local working copy and is intentionally excluded from this repository.

## 4. Prerequisites

- AWS account and permissions to provision VPC, EC2, networking, security groups, IAM and related resources.
- AWS CLI configured with a permitted profile in region `ap-south-1`.
- Terraform and Ansible on the operator's Linux/WSL machine.
- SSH key pair with its **private key kept outside Git**.
- Ansible `community.mongodb` collection.
- A secure Ansible Vault password and encrypted Vault variables stored **locally, not committed**.

Example local setup:

```bash
export AWS_PROFILE=herovired-iam
export AWS_DEFAULT_REGION=ap-south-1
aws sts get-caller-identity
terraform version
ansible --version
ansible-galaxy collection install community.mongodb
```

Replace the AWS profile with your own. **Do not place access keys in README files, playbooks or GitHub.**

## 5. Provision infrastructure with Terraform

From the repository root:

```bash
cd terraform
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
terraform output
```

Supply values for variables defined in `variables.tf` using local environment variables, command-line input, or a **private, untracked** `terraform.tfvars` file. The public IP, web/database private IPs, VPC ID and security group IDs are exposed as Terraform outputs.

Terraform provisions a public and private subnet, Internet Gateway, NAT Gateway, route tables, EC2 instances, security groups and IAM roles/profiles. **NAT Gateways, public IPv4 addresses and running EC2 instances may incur charges.**

Do not publish `terraform.tfstate`, `*.tfplan`, `terraform.tfvars`, credentials or SSH private keys. Keep the generated `.terraform.lock.hcl` tracked for reproducible provider selection.

## 6. Configure Ansible SSH access

The inventory contains the web server's **current** public address and the database's private address. Database SSH is forwarded through the public web EC2 using OpenSSH `ProxyCommand`; MongoDB is not publicly exposed.

An example (replace all placeholders to match your setup):

```ini
[web]
mern-web ansible_host=YOUR_CURRENT_WEB_PUBLIC_IP

[database]
mern-db ansible_host=10.20.2.140

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=/home/YOUR_WSL_USER/.ssh/mern-assignment.pem

[database:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -i /home/YOUR_WSL_USER/.ssh/mern-assignment.pem -W %h:%p ubuntu@YOUR_CURRENT_WEB_PUBLIC_IP"'
```

The actual inventory may also select the Python virtual environment used by MongoDB Ansible modules. When the public IP changes, update the web host **and** the database ProxyCommand target, verify SSH host identity, and run:

```bash
cd ../ansible
ansible all -m ping --ask-vault-pass
```

Host keys must be verified; do not disable host-key checking just to bypass an SSH error.

## 7. Secure MongoDB with Ansible

The MongoDB server is deployed in the private subnet. Its listener is configured for `127.0.0.1` and `10.20.2.140`, with authorization enabled.

Create a local encrypted secrets file at `ansible/group_vars/all/vault.yml` (excluded by `.gitignore`):

```bash
cd ansible
mkdir -p group_vars/all
EDITOR=nano ansible-vault create group_vars/all/vault.yml
```

Expected **variable names** (examples only; use independently generated strong passwords):

```yaml
vault_mongo_admin_password: "REPLACE_WITH_A_STRONG_PRIVATE_ADMIN_PASSWORD"
vault_mongo_app_password: "REPLACE_WITH_A_DIFFERENT_STRONG_PRIVATE_APP_PASSWORD"
```

The configuration uses MongoDB users `mernadmin` (administrator) and `travelmemory_app` (read/write access limited to `travelmemory`). Do not use the admin account in the application connection string.

Execute the playbooks in this order on a **fresh, compatible** database host:

```bash
ansible-playbook playbooks/install-mongodb.yml --ask-vault-pass
ansible-playbook playbooks/configure-mongodb-users.yml --ask-vault-pass
ansible-playbook playbooks/secure-mongodb.yml --ask-vault-pass
ansible-playbook playbooks/test-mongodb-auth.yml --ask-vault-pass
```

**Kernel compatibility prerequisite:** The original Ubuntu 24.04 AWS image booted a `7.0.0-1014-aws` kernel that prevented MongoDB 8.0.34 from starting. The database instance was switched to the AWS 6.8 LTS kernel (`6.8.0-1067-aws`) and MongoDB then started successfully. Verify or automate this prerequisite **before** replaying the MongoDB installation on a fresh EC2 instance. The included runbook documents the fix; merely applying the original installation playbook to the incompatible kernel is insufficient.

For `community.mongodb.mongodb_user`, the database host required PyMongo 4+. A local Python virtual environment at `/opt/mern-mongo-venv` was used and selected with `ansible_python_interpreter` in the inventory.

## 8. Deploy Node.js, Express, React and Nginx

From `ansible/`:

```bash
ansible-playbook playbooks/install-web.yml --ask-vault-pass
ansible-playbook playbooks/deploy-backend.yml --ask-vault-pass
ansible-playbook playbooks/deploy-frontend.yml --ask-vault-pass
```

- `install-web.yml`: installs Nginx, Git, Node.js, NPM and build dependencies.
- `deploy-backend.yml`: obtains upstream TravelMemory backend, installs dependencies, creates an environment file using Vault-managed credentials, and runs Express through systemd (`travelmemory-backend`).
- `deploy-frontend.yml`: installs React dependencies, sets `REACT_APP_BACKEND_URL=http://<current-web-public-IP>` at build time, generates a React production build, copies it under `/var/www/travelmemory`, configures Nginx, validates configuration and restarts Nginx.

The backend's connection string is stored in `/etc/travelmemory/backend.env` on EC2, not in this repository. Never display or commit the generated file.

## 9. Verify the deployment

Retrieve the **current** web public IP, then run:

```bash
curl -I http://YOUR_WEB_PUBLIC_IP/
curl http://YOUR_WEB_PUBLIC_IP/hello
curl http://YOUR_WEB_PUBLIC_IP/trip
```

Expected for a fresh/empty database: HTTP `200`, `Hello World!`, and `[]`. The last result verifies the API read path; confirm actual write/persistence by adding a travel experience in the browser and refreshing the page.

Check services through Ansible:

```bash
ansible web -b -m command -a 'systemctl is-active travelmemory-backend' --ask-vault-pass
ansible web -b -m command -a 'systemctl is-active nginx' --ask-vault-pass
ansible database -b -m command -a 'systemctl is-active mongod' --ask-vault-pass
```

Screenshots and implementation evidence are summarized in [IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md). Do not include visible credentials or other sensitive information in screenshots.

## 10. Troubleshooting

| Symptom | Cause in this deployment | Resolution |
|---|---|---|
| MongoDB would not start | MongoDB 8.0.34 rejected AWS kernel 7.x | Boot compatible AWS 6.8 LTS kernel on database EC2; recheck `uname -r` |
| MongoDB user module required PyMongo 4+ | System `python3-pymongo` too old | Install PyMongo 4 in `/opt/mern-mongo-venv` and select that interpreter |
| `Attempting to decrypt but no vault secrets found` | Ansible auto-loads encrypted `group_vars/all/vault.yml` | Add `--ask-vault-pass` |
| Ansible SSH connection refused | Web EC2 stopped; no public IP assigned | Start instances; retrieve new public IP |
| SSH host key verification failed | Previously unknown public IP after restart | Verify host-key fingerprint, connect manually to record key, then retry |
| Database unreachable through Ansible | Bastion ProxyCommand targeted stale public IP | Update both inventory `ansible_host` and ProxyCommand |
| React calls `localhost:3001` | Missing/empty `REACT_APP_BACKEND_URL` falls back to localhost | Set full web origin **at build time** and rebuild React |

## 11. Security and limitations

- Private MongoDB instance has no public IPv4 address.
- MongoDB access is restricted through the database EC2 security group and database authentication.
- SSH to the public instance should be permitted only from the operator's source `/32` address; SSH to the private instance is routed through the web instance.
- MongoDB admin/application credentials are kept in an encrypted Vault locally; passwords must not be printed in playbook logs or committed.
- SSH host-key verification remains enabled.
- The tested endpoint is **HTTP**, not HTTPS; production use requires a DNS name, TLS certificate and hardened application configuration.
- The current frontend build embeds a public IP; a stable Elastic IP or domain and relative API URLs would improve portability.
- Fresh-deployment repeatability depends on automating/pinning the MongoDB-compatible kernel prerequisite.

## 12. Submission and teardown

Submission includes Terraform files, Ansible playbooks/templates, README, architecture, implementation report and sanitized screenshots. Push to your own GitHub repository, then submit its URL through Vlearn as required by the assignment. Review tracked files for secrets before pushing.

Once the submission and required evidence are complete and **the live environment is no longer needed**, remove AWS resources to avoid continuing charges:

```bash
cd terraform
terraform plan -destroy
terraform destroy
```

Run `destroy` **only after confirming** it targets the correct Terraform state and resources. Stopping instances alone does not eliminate NAT Gateway, storage or allocated public-IP charges.
