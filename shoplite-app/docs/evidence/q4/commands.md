# Question 4: commands and evidence

Everything runs in the **lab terminal** (Ubuntu, with the lab's AWS credentials), from the
`shoplite-app` folder of the clone, unless a step says otherwise. The screenshot for each part is
listed at its end; the files go in this folder.

> **Cost:** the NAT Gateway, the ALB and three EC2 instances are billed by the hour. Take the
> evidence in the same session and run [After grading](#after-grading) before the lab ends.

Roughly: tools 5 minutes, `terraform apply` 5–8 minutes, nodes online in SSM 2–3 minutes later,
the first Ansible run 5–10 minutes.

## 0.1 Clone

```bash
git clone https://github.com/SaikatGeek/devops-final.git   # until the repositories are split
cd devops-final/shoplite-app
```

## 0.2 Tools

Terraform 1.17.2, the AWS CLI v2 with the Session Manager plugin (Ansible's SSH and kubectl both
go through SSM), kubectl 1.37.2 (the cluster's version) and the pinned Ansible. Downloads are
checked against their published SHA-256 sums.

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

# Ansible, the pinned versions, in its own virtualenv
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

A new terminal needs `export PATH="$HOME/ansible-venv/bin:$PATH"` again.

## 0.3 Settings and the SSH key

The region is the lab's region; everything ShopLite creates goes there. The budget e-mail and
the SSH key never go into Git, only into these variables.

```bash
aws sts get-caller-identity
export TF_VAR_region=ap-southeast-1          # the lab's region
export AWS_REGION=$TF_VAR_region AWS_DEFAULT_REGION=$TF_VAR_region
export TF_VAR_budget_alert_email=you@example.com
test -f ~/.ssh/shoplite || ssh-keygen -t ed25519 -f ~/.ssh/shoplite -N ''
export TF_VAR_ssh_public_key="$(cat ~/.ssh/shoplite.pub)"
```

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
| IAM roles or instance profiles | a bastion host instead of SSM (allowed by the question) |

## 1. Create the infrastructure (4a–4f)

`terraform/bootstrap` creates the S3 bucket for the state, once per account. The main
configuration keeps its state there, with S3's own lock file.

```bash
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap apply
BUCKET=$(terraform -chdir=terraform/bootstrap output -raw state_bucket)
terraform -chdir=terraform init \
  -backend-config="bucket=$BUCKET" \
  -backend-config="region=$(terraform -chdir=terraform/bootstrap output -raw region)"
terraform -chdir=terraform apply
terraform -chdir=terraform output
VPC=$(terraform -chdir=terraform output -raw vpc_id)
```

Screenshots: `01-bootstrap-apply.png` (the state bucket created), `02-terraform-apply.png`
(`Apply complete!` and the outputs).

## 2. Configure the nodes (4g)

The inventory comes from Terraform: the nodes by instance id, and SSH through SSM. Instance ids
change with every apply, so write it again after each one.

```bash
terraform -chdir=terraform output -raw ansible_inventory > ansible/lab.ini
cat ansible/lab.ini
```

Wait until SSM reports all three nodes `Online` (2–3 minutes after the apply):

```bash
aws ssm describe-instance-information --filters Key=tag:project,Values=shoplite \
  --query 'InstanceInformationList[].[InstanceId,PingStatus,PlatformName]' --output table
```

Run the playbook twice. The first run hardens the nodes (question 3's rules), installs the
container runtime and k3s, joins the workers and fetches the kubeconfig. The second run must
change nothing.

```bash
cd ansible
ansible -i lab.ini k3s_cluster -m ping
ansible-playbook -i lab.ini site.yml
ansible-playbook -i lab.ini site.yml
cd ..
```

Screenshots: `15-ansible-first-run.png` (the `PLAY RECAP` of the first run, and the
`Show the container runtime and its version` lines with containerd's version),
`16-ansible-second-run.png` (the `PLAY RECAP` of the second run: `changed=0` on every node).

## 3. kubectl through SSM

The API has no public address. **Second terminal**, from `shoplite-app`, keep it running:

```bash
eval "$(terraform -chdir=terraform output -raw kubectl_tunnel)"
```

**First terminal**: the kubeconfig the playbook fetched points at `https://127.0.0.1:6443`, the
local end of that tunnel.

```bash
export KUBECONFIG=$PWD/ansible/kubeconfig
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

The nodes reach the internet only through the NAT Gateway: from a node (see 4c for the session),
the address the internet sees is the NAT Gateway's public IP from the last command.

```bash
curl -s https://checkip.amazonaws.com
```

Screenshots: `03-state-list.png`, `04-subnets-routes.png` (subnets and route tables),
`05-igw-nat.png` (Internet Gateway, NAT Gateway, and the `checkip` answer from a node).

### 4b Security groups

No rule lets anything in from the internet to the nodes, not even SSH; the cluster ports are
open only between the nodes, the API port only on the control plane, and the ingress NodePorts
only from the ALB. The VPC's default group is unused.

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
only on `shoplite-alb`, ports 80 and 8080), `07-nodes-no-public-ip.png` (`PublicIpAddress` is
`None` on every node).

### 4c Kubernetes nodes and SSM

One control plane and two workers, in the private subnets (previous screenshot). Admin access is
SSM Session Manager; there is no bastion and no open SSH port.

```bash
aws ssm start-session --target "$(terraform -chdir=terraform output -raw control_plane_instance_id)"
```

In the session:

```bash
hostname; ip -4 -brief address
sudo k3s kubectl get nodes
exit
```

Screenshot `08-ssm-session.png`: the session opening, the node's private address and the nodes.

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

State locking: S3 keeps a lock file beside the state while Terraform works.

1. **First terminal:** `terraform -chdir=terraform apply` and leave it waiting at
   `Enter a value:` (do not answer yet); it holds the lock while it waits.
2. **Second terminal** (same folder; the `export` lines of 0.3 again):

   ```bash
   BUCKET=$(terraform -chdir=terraform/bootstrap output -raw state_bucket)
   aws s3 ls "s3://$BUCKET/shoplite/"
   terraform -chdir=terraform plan
   ```

   The listing shows `terraform.tfstate.tflock`, and `plan` stops with `Error acquiring the
   state lock`.
3. **First terminal:** answer `no`. The lock file is gone afterwards.

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

Screenshots 15–17 from steps 2 and 3. Question 3's hardening on a node, in an SSM session to a
worker (`aws ssm start-session --target <worker id from terraform output worker_instance_ids>`):

```bash
sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication) '
id deploy
ls -ld /var/log/shoplite && getfacl -p /var/log/shoplite
sudo ufw status verbose
exit
```

Screenshot `18-node-hardening.png`.

### Cost guard

Every resource is tagged `project=shoplite`; the monthly budget alarms at USD 20.

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=project,Values=shoplite \
  --query 'ResourceTagMappingList[].ResourceARN' --output text | tr '\t' '\n' | sort
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

Screenshot `21-destroy.png`: `Destroy complete!` of the main configuration.
