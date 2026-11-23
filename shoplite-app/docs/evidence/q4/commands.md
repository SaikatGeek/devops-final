# Question 4: commands and evidence

Everything runs in the **lab terminal** (Ubuntu, with the lab's AWS credentials), from the
`shoplite-app` folder of the clone, unless a step says otherwise. The screenshot for each part is
listed at its end; the files go in this folder.

> **Cost:** the NAT Gateway, the ALB and three EC2 instances are billed by the hour. Take the
> evidence in the same session and run [After grading](#after-grading) before the lab ends.

Roughly: tools 5 minutes, `terraform apply` 5–8 minutes, the bastion reachable a minute later,
the first Ansible run 5–10 minutes.

## 0.1 Clone

Both clones side by side in the home folder (question 5 reads `../shoplite-gitops`):

```bash
cd ~
git clone https://github.com/SaikatGeek/shoplite-app.git
git clone https://github.com/SaikatGeek/shoplite-gitops.git   # next to it; question 5 needs it
cd shoplite-app
```

## 0.2 Tools

Terraform 1.17.2, the AWS CLI v2 with the Session Manager plugin (for accounts that allow SSM;
in the lab, Ansible's SSH and kubectl go through the bastion host), kubectl 1.37.2 (the
cluster's version) and the pinned Ansible. Downloads are checked against their published
SHA-256 sums.

The lab terminal's user (`poridhian`) has password-less `sudo`; check it first, because a
`sudo` that asks for a password would read the next pasted lines as the password:

```bash
sudo -n true && echo SUDO-OK
```

Then, from `shoplite-app`:

```bash
sudo apt-get update
sudo apt-get install -y unzip curl git python3-venv
mkdir -p ~/tools

# Terraform 1.17.2, checksum checked
curl -fsSL --retry 5 --retry-all-errors -o ~/tools/terraform.zip https://releases.hashicorp.com/terraform/1.17.2/terraform_1.17.2_linux_amd64.zip
curl -fsSL --retry 5 --retry-all-errors -o ~/tools/terraform.sums https://releases.hashicorp.com/terraform/1.17.2/terraform_1.17.2_SHA256SUMS
echo "$(grep '_linux_amd64.zip$' ~/tools/terraform.sums | cut -d' ' -f1)  $HOME/tools/terraform.zip" | sha256sum --check
unzip -oq ~/tools/terraform.zip terraform -d ~/tools && sudo install ~/tools/terraform /usr/local/bin/

# AWS CLI v2 (skipped when it is already there) and the Session Manager plugin
if ! aws --version 2>/dev/null | grep -q '^aws-cli/2'; then
  curl -fsSL --retry 5 --retry-all-errors -o ~/tools/awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
  unzip -oq ~/tools/awscliv2.zip -d ~/tools && sudo ~/tools/aws/install --update
fi
curl -fsSL --retry 5 --retry-all-errors -o ~/tools/session-manager-plugin.deb https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb
sudo dpkg -i ~/tools/session-manager-plugin.deb

# kubectl, the cluster's version, checksum checked
curl -fsSL --retry 5 --retry-all-errors -o ~/tools/kubectl https://dl.k8s.io/release/v1.37.2/bin/linux/amd64/kubectl
echo "$(curl -fsSL --retry 5 https://dl.k8s.io/release/v1.37.2/bin/linux/amd64/kubectl.sha256)  $HOME/tools/kubectl" | sha256sum --check
sudo install ~/tools/kubectl /usr/local/bin/

# Ansible, the pinned versions, in its own virtualenv. The lab terminal's LANG
# (en_US.UTF-8) has no locale behind it, and Ansible refuses to start without one.
export LANG=C.UTF-8 LC_ALL=C.UTF-8
python3 -m venv ~/ansible-venv
~/ansible-venv/bin/pip install --quiet -r ansible/requirements.txt
~/ansible-venv/bin/ansible-galaxy collection install -r ansible/requirements.yml
export PATH="$HOME/ansible-venv/bin:$PATH"

# Check
terraform version | head -n 1
aws --version
session-manager-plugin --version
kubectl version --client
ansible --version | head -n 1
ansible-galaxy collection list 2>/dev/null | grep -E 'ansible.posix|community.general'
```

The last six lines must print the versions; any error there stops here.

## 0.3 Settings and the SSH key

The region is the lab's region; everything ShopLite creates goes there. The budget e-mail and
the SSH key never go into Git, only into these variables. `admin_cidr` is the lab terminal's
public address: the only source the bastion host admits.

Every new terminal loses its `export`s, so they live in `~/shoplite.env` (outside the clone,
never in Git). Change the e-mail before pressing Enter:

```bash
aws sts get-caller-identity
test -f ~/.ssh/shoplite || ssh-keygen -t ed25519 -f ~/.ssh/shoplite -N ''
cat > ~/shoplite.env <<'EOF'
export PATH="$HOME/ansible-venv/bin:$PATH" LANG=C.UTF-8 LC_ALL=C.UTF-8
export TF_VAR_region=ap-southeast-1 AWS_REGION=ap-southeast-1 AWS_DEFAULT_REGION=ap-southeast-1
export TF_VAR_budget_alert_email=you@example.com
export TF_VAR_admin_cidr="$(curl -s https://checkip.amazonaws.com)/32"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/shoplite.pub)"
export KUBECONFIG="$HOME/shoplite-app/ansible/kubeconfig"
EOF
source ~/shoplite.env && cd ~/shoplite-app
env | grep -o '^TF_VAR_[a-z_]*'
```

The last command lists four `TF_VAR_` names. In every new terminal:
`source ~/shoplite.env && cd ~/shoplite-app`.

## 0.4 What the lab allows

The nodes need `t3.medium` (control plane) and `t3.large` (workers) in two availability zones:

```bash
aws ec2 describe-instance-type-offerings --location-type availability-zone \
  --filters Name=instance-type,Values=t3.medium,t3.large \
  --query 'InstanceTypeOfferings[].[InstanceType,Location]' --output table
```

If `apply` stops with `AccessDenied` or an unavailable type, these are the fallbacks
(PLAN.md, phase 3); write down what happened for the README's deviation log:

| Not allowed | Instead |
|---|---|
| `t3.large` | `worker_instance_type = "t3.medium"` in `module "compute"` of `terraform/main.tf` |
| Budgets | keep the code, take a screenshot of the `AccessDenied` error |
| NAT Gateway | a NAT instance (allowed by the question) |
| IAM roles or instance profiles | admin access needs none (it goes through the bastion host), but the nodes pull images from ECR with their role: tell the instructor |
| SSM sessions (`ssmmessages` denied, as in the Poridhi lab: `TargetNotConnected`) | nothing to change: admin access goes through the bastion host (allowed by the question) |
| `t3.micro` (the bastion) | `bastion_instance_type = "t3.medium"` in `module "compute"` of `terraform/main.tf` |
| An IAM OIDC identity provider (for question 7) | tell the instructor: question 7's push to ECR needs it. To go on with question 4 meanwhile, comment out `module "github_oidc"` in `terraform/main.tf` and `output "ci_role_arn"` in `terraform/outputs.tf`, then apply again |
| The account has GitHub's OIDC provider already (`EntityAlreadyExists`) | use it: `terraform -chdir=terraform import module.github_oidc.aws_iam_openid_connect_provider.github arn:aws:iam::<account>:oidc-provider/token.actions.githubusercontent.com`, then apply again. Before the final destroy, `terraform -chdir=terraform state rm module.github_oidc.aws_iam_openid_connect_provider.github`, so the provider stays |

## 1. Create the infrastructure (4a–4f)

`terraform/bootstrap` creates the S3 bucket for the state, once per account. The main
configuration keeps its state there, with S3's own lock file. The same apply also creates
the role GitHub Actions takes through OIDC to push the images (question 7, output
`ci_role_arn`).

```bash
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap apply
BUCKET=$(terraform -chdir=terraform/bootstrap output -raw state_bucket)
terraform -chdir=terraform init \
  -backend-config="bucket=$BUCKET" \
  -backend-config="region=$(terraform -chdir=terraform/bootstrap output -raw region)"
```

Paste the apply on its own: it stops at `Enter a value:`, and a pasted next line would become
the answer. While it waits, it holds the state lock: take 4e's lock screenshot then (4e, step
2, in a second terminal), and answer `yes` afterwards.

```bash
terraform -chdir=terraform apply
```

```bash
VPC=$(terraform -chdir=terraform output -raw vpc_id)
```

Screenshots: `01-bootstrap-apply.png` (the state bucket created), `02-terraform-apply.png`
(`Apply complete!` and the outputs; a second `terraform apply` prints `No changes` and the
outputs again, if the first scrolled away).

## 2. Configure the nodes (4g)

The inventory comes from Terraform: the nodes by private IP, and SSH through the bastion host
with the same key. Addresses change with every apply, so write it again after each one.

```bash
terraform -chdir=terraform output -raw ansible_inventory > ansible/lab.ini
cat ansible/lab.ini
```

The bastion accepts SSH about a minute after the apply; until then the ping fails with
`Connection closed by UNKNOWN port 65535`, so try again. All three nodes must answer `pong`:

```bash
cd ansible
ansible -i lab.ini k3s_cluster -m ping
```

Run the playbook twice. The first run hardens the nodes (question 3's rules), installs the
container runtime and k3s, joins the workers and fetches the kubeconfig. Its output is kept in
`~/ansible-run1.log` for the screenshot. If a task fails with `503 Service Unavailable` from
`*.ec2.archive.ubuntu.com` (Ubuntu's mirror was busy), run it again.

```bash
ANSIBLE_FORCE_COLOR=1 ansible-playbook -i lab.ini site.yml | tee ~/ansible-run1.log
```

Screenshot 15 needs two parts that are far apart in that output; this shows them together:

```bash
clear; grep -A4 'Show the container runtime' ~/ansible-run1.log; tail -n 6 ~/ansible-run1.log
```

The second run must change nothing:

```bash
clear; ANSIBLE_FORCE_COLOR=1 ansible-playbook -i lab.ini site.yml | tail -n 6
cd ..
```

Screenshots: `15-ansible-first-run.png` (the `Show the container runtime and its version`
lines with containerd's version, and the first run's `PLAY RECAP` with `failed=0`),
`16-ansible-second-run.png` (the second run's `PLAY RECAP`: `changed=0` on every node).

## 3. kubectl through the bastion

The API has no public address. **Second terminal** (`source ~/shoplite.env && cd ~/shoplite-app`
first), keep it running; it looks idle, which is right:

```bash
eval "$(terraform -chdir=terraform output -raw kubectl_tunnel)"
```

It logs in to the control plane through the bastion and forwards local port 6443 to the API.
**First terminal**: the kubeconfig the playbook fetched (`KUBECONFIG`, from `~/shoplite.env`)
points at `https://127.0.0.1:6443`, the local end of that tunnel.

```bash
kubectl get nodes -o wide
```

Screenshot `17-kubectl-get-nodes.png`: three nodes `Ready` (one `control-plane`), private IPs
only, container runtime `containerd://...-k3s1`.

## 4. Evidence for each part

### 4a VPC and networking

Two public and two private subnets in two AZs; the public route table goes to the Internet
Gateway, the private one to the NAT Gateway.

```bash
terraform -chdir=terraform state list
aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC \
  --query 'Subnets[].[Tags[?Key==`Name`]|[0].Value,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]' --output table
aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC Name=tag:project,Values=shoplite \
  --query 'RouteTables[].[Tags[?Key==`Name`]|[0].Value,Routes[?DestinationCidrBlock==`0.0.0.0/0`]|[0].GatewayId,Routes[?DestinationCidrBlock==`0.0.0.0/0`]|[0].NatGatewayId,length(Associations[?SubnetId])]' --output table
aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$VPC \
  --query 'InternetGateways[].[InternetGatewayId,Attachments[0].State]' --output table
aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=$VPC \
  --query 'NatGateways[].[NatGatewayId,State,SubnetId,NatGatewayAddresses[0].PublicIp]' --output table
```

The nodes reach the internet only through the NAT Gateway: the address the internet sees from a
node is the NAT Gateway's public IP from the last command.

```bash
(cd ansible && ansible -i lab.ini control-plane -a 'curl -s https://checkip.amazonaws.com')
```

Screenshots: `03-state-list.png`, `04-subnets-routes.png` (subnets and route tables),
`05-igw-nat.png` (Internet Gateway, NAT Gateway, and the `checkip` answer from a node).

### 4b Security groups

No rule lets anything in from the internet to the nodes. SSH reaches the nodes only from the
bastion's group, and the bastion only from `admin_cidr`; the cluster ports are open only
between the nodes, the API port only on the control plane, and the ingress NodePorts only from
the ALB. The VPC's default group is unused.

```bash
aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC \
  --query 'SecurityGroups[].[GroupName,GroupId]' --output table
aws ec2 describe-security-group-rules \
  --filters Name=group-id,Values=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC --query 'SecurityGroups[].GroupId' --output text | tr '\t' ',') \
  --query 'SecurityGroupRules[?IsEgress==`false`].[GroupId,IpProtocol,FromPort,ToPort,CidrIpv4,ReferencedGroupInfo.GroupId]' --output table
aws ec2 describe-instances --filters Name=vpc-id,Values=$VPC Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,InstanceId,PrivateIpAddress,PublicIpAddress,SubnetId]' --output table
```

Screenshots: `06-security-groups.png` (the groups and their inbound rules: `0.0.0.0/0` appears
only on `shoplite-alb`, ports 80 and 8080; port 22 only from `admin_cidr` on `shoplite-bastion`
and from the bastion's group on `shoplite-nodes`), `07-nodes-no-public-ip.png`
(`PublicIpAddress` is `None` on every node; only `shoplite-bastion` has one).

### 4c Kubernetes nodes and admin access

One control plane and two workers, in the private subnets (previous screenshot). Admin access is
SSH through the bastion host: the lab account denies SSM's session channel (see the README's
deviations).

```bash
CP=$(awk -F= '/^control-plane /{print $2}' ansible/lab.ini)
eval "$(terraform -chdir=terraform output -raw ssh_via_bastion) ubuntu@$CP"
```

In the session:

```bash
hostname; ip -4 -brief address
sudo k3s kubectl get nodes
exit
```

Screenshot `08-bastion-session.png`: the session through the bastion, the node's private address
and the nodes.

### 4d Application Load Balancer

The ALB is in the public subnets; port 80 forwards to the prod ingress (Traefik's NodePort
30080), port 8080 to dev (30081), on the workers.

```bash
terraform -chdir=terraform output app_urls
aws elbv2 describe-load-balancers --names shoplite \
  --query 'LoadBalancers[].[LoadBalancerName,Scheme,DNSName,join(`", "`,AvailabilityZones[].SubnetId)]' --output table
aws elbv2 describe-listeners \
  --load-balancer-arn "$(aws elbv2 describe-load-balancers --names shoplite --query 'LoadBalancers[0].LoadBalancerArn' --output text)" \
  --query 'Listeners[].[Port,Protocol,DefaultActions[0].TargetGroupArn]' --output table
```

Screenshot `09-alb-listeners.png`.

The targets turn `healthy` only once Traefik answers `/ping` on the NodePorts, which comes with
question 5. Take this one after question 5, together with the page opening at the ALB's URL:

```bash
for tg in shoplite-prod shoplite-dev; do
  aws elbv2 describe-target-health \
    --target-group-arn "$(aws elbv2 describe-target-groups --names $tg --query 'TargetGroups[0].TargetGroupArn' --output text)" \
    --query 'TargetHealthDescriptions[].[Target.Id,Target.Port,TargetHealth.State]' --output table
done
```

Screenshot `10-target-health.png` (after question 5).

### 4e ECR and remote state

```bash
aws ecr describe-repositories --query 'repositories[].[repositoryName,repositoryUri]' --output table
aws s3 ls "s3://$BUCKET" --recursive
```

State locking: S3 keeps a lock file beside the state while Terraform works. It needs an apply
with something to do, so it waits at `Enter a value:`; the first apply of section 1 is one.

1. **First terminal:** `terraform -chdir=terraform apply`, left waiting at `Enter a value:`
   (do not answer yet); it holds the lock while it waits.
2. **Second terminal:**

   ```bash
   source ~/shoplite.env && cd ~/shoplite-app
   BUCKET=$(terraform -chdir=terraform/bootstrap output -raw state_bucket)
   aws s3 ls "s3://$BUCKET/shoplite/"
   terraform -chdir=terraform plan
   ```

   The listing shows `terraform.tfstate.tflock`, and `plan` stops with `Error acquiring the
   state lock`.
3. **First terminal:** answer `yes` in section 1 (`no` in an apply that only shows the lock).
   The lock file is gone afterwards.

Screenshots: `11-ecr-repositories.png`, `12-state-in-s3.png` (`shoplite/terraform.tfstate` in
the bucket), `13-state-lock.png` (the lock file and the `Error acquiring the state lock` message).

### 4f Terraform modules

```bash
find terraform/modules -name '*.tf' -not -path '*/.terraform/*' | sort
terraform -chdir=terraform state list | grep '^module\.' | cut -d. -f1-2 | sort -u
```

Screenshot `14-modules.png`: the four modules `network`, `compute`, `alb` and `ecr`, and all
four in use.

### 4g Ansible

Screenshots 15–17 from steps 2 and 3. Question 3's hardening on a node, in an SSH session to a
worker through the bastion:

```bash
W1=$(awk -F= '/^worker-1 /{print $2}' ansible/lab.ini)
eval "$(terraform -chdir=terraform output -raw ssh_via_bastion) ubuntu@$W1"
```

In the session:

```bash
sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication) '
id deploy
ls -ld /var/log/shoplite && getfacl -p /var/log/shoplite
sudo ufw status verbose
exit
```

Screenshot `18-node-hardening.png`.

### Cost guard

Every resource is tagged `project=shoplite`; the monthly budget alarms at USD 20. The lab
account denies the tagging API (`tag:GetResources`), so the tagged resources come from EC2's
own list:

```bash
aws ec2 describe-tags --filters Name=key,Values=project Name=value,Values=shoplite \
  --query 'Tags[].[ResourceType,ResourceId]' --output table
aws budgets describe-budgets --account-id "$(aws sts get-caller-identity --query Account --output text)" \
  --query 'Budgets[].[BudgetName,BudgetLimit.Amount,BudgetLimit.Unit,TimeUnit]' --output table
```

Screenshots: `19-tagged-resources.png`, `20-budget.png`.

## After grading

At the end of every lab session, and for good after grading (cost guard). The Q3 server keeps
its state in the same bucket, so destroy it first if it exists
(`terraform -chdir=terraform/q3-server destroy`, see `linux/evidence/commands.md`), then:

```bash
terraform -chdir=terraform destroy
terraform -chdir=terraform/bootstrap destroy
rm -f ansible/lab.ini ansible/kubeconfig
```

Screenshot `21-destroy.png`: `Destroy complete!` of the main configuration. Then set the
GitHub variable `LAB_ACTIVE` to `false`.

If the lab terminal is gone but the account still answers (its keys in the environment of any
machine with Terraform), the main configuration destroys the same way after
`terraform -chdir=terraform init -backend-config=...` and the 0.3 variables (any valid values
do for a destroy). The bootstrap's state was local to the lost terminal, so import the bucket
first; the apply only records `force_destroy` in the new state:

```bash
BUCKET=shoplite-tfstate-<account>-<region>
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap import aws_s3_bucket.state "$BUCKET"
terraform -chdir=terraform/bootstrap import aws_s3_bucket_versioning.state "$BUCKET"
terraform -chdir=terraform/bootstrap apply
terraform -chdir=terraform/bootstrap destroy
```
