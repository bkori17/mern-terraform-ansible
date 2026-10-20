# Implementation Report — TravelMemory MERN on AWS

**Assignment:** Deploying a MERN Application through Terraform and Ansible  
**Implementation date:** 20 October 2026  
**Application:** https://github.com/UnpredictablePrashant/TravelMemory  
**AWS region:** `ap-south-1` (Mumbai)

## 1. Objective and scope

Provision a two-tier AWS environment using Terraform and deploy TravelMemory with Ansible. The solution must use a VPC with one public and one private subnet, Internet Gateway, NAT Gateway, EC2 instances, security groups and IAM instance roles. The public instance runs the React/Express/Node.js web application; the private instance runs an authenticated MongoDB server.

## 2. Infrastructure provisioned with Terraform

The Terraform project initialized and validated successfully using the AWS provider. The deployment reported **`Apply complete! Resources: 19 added, 0 changed, 0 destroyed`** at final apply; other resources may have already existed in Terraform state. Final configuration included:

- VPC: `10.20.0.0/16`, ID `vpc-0860fd7a1a9e9e0b8`.
- Public subnet: `10.20.1.0/24` (web EC2 `10.20.1.32`).
- Private subnet: `10.20.2.0/24` (DB EC2 `10.20.2.140`).
- Internet Gateway, NAT Gateway with Elastic IP, and corresponding public/private route tables.
- Two `t3.small` Ubuntu EC2 instances, encrypted gp3 EBS volumes.
- Web security group allowing public HTTP and restricted administrative SSH.
- Database security group allowing SSH and MongoDB only from the web security group.
- EC2 IAM instance profiles/roles including SSM-related access.
- Outputs for current public/private addresses, VPC and security group IDs.

The public EC2 originally used public IP `13.232.127.188`. After an instance stop/start, it was assigned `13.234.78.43`. Public IP values are time-specific and not stable unless an Elastic IP is associated.

**Evidence to attach:** Terraform validation, plan/apply recap, AWS VPC, subnets, routes, EC2 and security groups screenshots.

## 3. Ansible connectivity

Ansible was executed from Ubuntu 24.04 under WSL. The inventory used key-based SSH to the public EC2 and an SSH ProxyCommand through that web EC2 to access the private MongoDB instance. Both hosts passed `ansible all -m ping` checks after provisioning and again following the public IP change.

**Evidence to attach:** Ansible ping results and inventory sanitized of local private information where applicable.

## 4. MongoDB deployment and security

MongoDB 8.0.34 was installed on the private EC2 instance. The first attempt failed because MongoDB reported a known incompatibility with the instance's AWS kernel `7.0.0-1014-aws` (Linux kernels 6.19+). The database host was switched to compatible AWS kernel `6.8.0-1067-aws`. MongoDB then started successfully.

A second issue occurred while creating the application database user: the Ansible `community.mongodb.mongodb_user` module required PyMongo 4+, but the initial system dependency was older. A Python virtual environment (`/opt/mern-mongo-venv`) with PyMongo 4 was installed and selected for database Ansible tasks.

The database users were then created:

| Database | User | Permissions |
|---|---|---|
| `admin` | `mernadmin` | Administrative `root` role |
| `travelmemory` | `travelmemory_app` | `readWrite` only on `travelmemory` |

Credentials were encrypted with Ansible Vault. MongoDB authorization was enabled and the database bound to localhost plus `10.20.2.140`. An unauthenticated `getUsers()` attempt correctly failed with `MongoServerError: Command usersInfo requires authentication`.

An authenticated Ansible/PyMongo test then successfully inserted, read and deleted a test document. Output included **`MongoDB application user authentication and read/write test PASSED`**, with `failed=0`.

**Evidence to attach:** MongoDB 6.8 kernel and active service, both usernames (not passwords), authentication rejection, read/write playbook recap.

## 5. Web server and backend deployment

Ansible installed Node.js `v24.22.0`, NPM `11.19.1`, Nginx and build tools on the public EC2. The web server successfully opened a TCP connection to MongoDB at `10.20.2.140:27017`.

The TravelMemory backend was deployed to `/opt/travelmemory/backend` and managed with `travelmemory-backend.service` under systemd. Ansible installed application dependencies and rendered `/etc/travelmemory/backend.env` from encrypted Vault variables. The MongoDB URI authenticates as `travelmemory_app` against the `travelmemory` database.

Backend tests on the web EC2 showed:

```text
systemctl is-active travelmemory-backend
active

curl -fsS http://127.0.0.1:3001/hello
Hello World!

curl -fsS http://127.0.0.1:3001/trip
[]
```

**Evidence to attach:** Successful backend deployment recap and these local endpoint tests.

## 6. React production deployment and Nginx

The TravelMemory frontend reads the API origin from `process.env.REACT_APP_BACKEND_URL`, falling back to `http://localhost:3001`. The Ansible frontend deployment set `REACT_APP_BACKEND_URL` to the current public web origin at **React build time**, ensuring browsers did not attempt to access their own localhost.

Ansible installed frontend dependencies, executed `npm run build`, published React build files to `/var/www/travelmemory`, created/enabled an Nginx site, disabled the default site, validated configuration (`nginx -t`), and restarted Nginx. Nginx serves the frontend on port 80 and proxies `/hello` and `/trip` to the local Express backend on port 3001.

The frontend playbook finished:

```text
PLAY RECAP
mern-web : ok=10 changed=8 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

## 7. Public endpoint validation

The application was tested externally at `http://13.234.78.43` on 20 October 2026.

| Command | Observed result | Meaning |
|---|---|---|
| `curl -I http://13.234.78.43/` | `HTTP/1.1 200 OK` | Nginx publicly serves the frontend entry point |
| `curl http://13.234.78.43/hello` | `Hello World!` | Nginx → Express reverse proxy works |
| `curl http://13.234.78.43/trip` | `[]` | MongoDB-backed API read path returned successfully (empty collection) |

The browser-based experience creation/refresh test is **not independently confirmed in the provided terminal transcript**. Attach those screenshots and record the result here if performed. Do not claim validated browser persistence solely from an empty `GET /trip` response.

**Evidence to attach:** Curl responses, application homepage, experience creation and saved experience screenshots if available.

## 8. Problems encountered and resolutions

| Issue | Observed symptom | Resolution |
|---|---|---|
| MongoDB kernel incompatibility | MongoDB service failed on Linux 7.0 AWS kernel | Installed/booted supported AWS 6.8 LTS kernel on DB EC2 |
| Outdated PyMongo | `You must use pymongo 4+` | Installed PyMongo 4 in isolated virtual environment and configured Ansible interpreter |
| Ansible Vault ad-hoc failures | `Attempting to decrypt but no vault secrets found` | Supplied `--ask-vault-pass` to commands requiring the encrypted group-vars file |
| Instance interruption | SSH connection refused; public EC2 was stopped | Started both EC2 instances; obtained new public IP |
| SSH trust after public IP change | `Host key verification failed` | Verified SSH host identity, accepted the key, confirmed Ansible connectivity |
| Database SSH through bastion | ProxyCommand still used old web public IP | Updated inventory ProxyCommand and web host |

## 9. Security controls and limitations

The database is private and protected by restrictive security groups and MongoDB authorization. The application uses a least-privilege database account. SSH access is key-based, and application credentials are supplied from locally encrypted Ansible Vault data. Backend credentials are not included in the Git repository.

Limitations and improvements: add HTTPS with a DNS name and TLS certificate; associate a stable web Elastic IP or use relative API URLs; automate MongoDB-compatible kernel setup for fresh instances; improve secret lifecycle, health monitoring, backups and deployments pinned to specific upstream commits. This is a learning assignment, not a production-grade high-availability system.

## 10. Deliverables and submission

The GitHub repository should include:

- Terraform `.tf` source files and `.terraform.lock.hcl`.
- Ansible inventory/playbooks/templates, with **no real passwords or SSH private keys**.
- `README.md`, `ARCHITECTURE.md` with Mermaid diagrams, and this report.
- Sanitized screenshots proving infrastructure creation, configuration and HTTP/application behavior.

Provide your own GitHub repository link in the text/Word/PDF submission uploaded through Vlearn. Keep Terraform state, credentials, Vault contents, SSH keys and build/generated caches out of Git.

## 11. Evidence index (adjust to actual filenames)

| Screenshot | Recommended evidence |
|---|---|
| `screenshots/01-terraform/` | Terraform init, validate, apply/outputs |
| `screenshots/02-aws/` | VPC/subnets/routes/NAT/IGW, instances, security groups, IAM |
| `screenshots/04-ansible/03-mongodb-running.png` | Compatible DB kernel and MongoDB service |
| `screenshots/04-ansible/04-mongodb-users.png` | DB account names |
| `screenshots/04-ansible/06-mongodb-authentication.png` | Authenticated read/write test |
| `screenshots/04-ansible/07-web-server-installation.png` | Node/NPM/Nginx and connectivity |
| `screenshots/04-ansible/08-backend-verification.png` | Express and DB-backed endpoints |
| `screenshots/04-ansible/09-frontend-deployment.png` | Frontend Ansible play recap |
| `screenshots/05-application/` | Public curl, homepage and browser persistence (if captured) |

Keep filenames in this index synchronized with the actual screenshot files before committing.
