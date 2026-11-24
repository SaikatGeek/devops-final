# Lab runbook: copy-paste, ক্রমে

একটা lab session-এর সব command, ক্রমে। প্রতিটা block-এর আগে লেখা আছে সেটা কেন চালাচ্ছি, আর কোথায় screenshot নিতে হবে। এখানে আজকের (২৩ নভেম্বর) সব ভুলের সমাধান বসানো আছে।

কোন অবস্থায় আছি আর কী বাকি: `NEXT-LAB.md`। Command-এর ইংরেজি ব্যাখ্যা: `shoplite-app/docs/evidence/qN/commands.md`।

## নিয়ম (পুরো session জুড়ে)

- **একটা block একবারে paste করো।** কোনো command `Enter a value:` বা `yes/no` চাইলে আলাদা করে উত্তর দাও। পুরো block একসাথে paste করলে পরের লাইনটাই উত্তর হিসেবে চলে যায়।
- **প্রতিটা নতুন terminal-এ প্রথমে এটা চালাও** (না চালালে variable থাকে না):
  ```bash
  source ~/shoplite.env && cd ~/shoplite-app
  ```
- **Terminal 1:** সব কাজ এখানে। **Terminal 2:** শুধু kubectl-এর tunnel, section ৫ থেকে সবসময় চালু থাকবে।
- **Screenshot:** Win+Shift+S চাপো → জায়গা বাছো → notification-এ click → Save। নামের আগে `clear;` দেওয়া command গুলো screen পরিষ্কার করে শুধু দরকারি অংশ দেখায়, তখন ছবি তোলো।
  - রাখবে `...\devops-final\shoplite-app\docs\evidence\qN\` folder-এ (অফিসে `E:\devops-final`, বাসায় `E:\Personal\devops-final`)।
- **Error এলে** থামো, পুরো error Claude-কে দেখাও। নিজে থেকে অন্য কিছু চালাবে না।
- **Video একটাই** (২৪ নভেম্বরের সিদ্ধান্ত): Q8-এর পরে, destroy-এর আগে, ১০ মিনিটের demo (NEXT-LAB-এর section ৯)। এর আগে কোনো recording না। Procedure-এ V1, V2, V3, V6 বা Q6-এর 17 দেখলে বাদ দাও।
- **ক্রম:** setup → Q7 (09, 10, 06, 07) → Q8 → demo video → destroy (NEXT-LAB-এর section ৭)। Q8 শুরু lab শুরুর ২ ঘণ্টা ৪৫ মিনিটের মধ্যে।

## ১. Lab শুরুর আগে (GitHub, ২ মিনিট)

- https://github.com/SaikatGeek/shoplite-app/settings/secrets/actions-এ `BUDGET_ALERT_EMAIL` আর `GITOPS_DEPLOY_KEY` আছে কি না দেখো।
- Variables tab-এ `LAB_ACTIVE` এখনো `false` থাকবে।
- Slack-এর webhook **নতুন বানাও** (আগের session-এরটা terminal আর chat-এ দেখা গিয়েছিল): https://api.slack.com/apps → ShopLite alerts → Incoming Webhooks → Add New Webhook (একই channel), পুরোনোটা Remove। নতুন URL কোথাও paste করবে না; শুধু bootstrap-এর prompt-এ দেবে।

## ২. Lab terminal: clone, tools, settings (~১০ মিনিট)

**২.১ Clone**, দুইটা repo পাশাপাশি `~`-এ (Q5 `../shoplite-gitops` খোঁজে):
```bash
cd ~
git clone https://github.com/SaikatGeek/shoplite-app.git
git clone https://github.com/SaikatGeek/shoplite-gitops.git
cd shoplite-app
```

**২.২ `sudo` password চায় কি না দেখো।** `SUDO-OK` না এলে থামো:
```bash
sudo -n true && echo SUDO-OK
```

**২.৩ Tools** (~৫ মিনিট): Terraform, AWS CLI, kubectl, Ansible। পুরোটা একবারে paste করো।
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
- শেষে ৬টা version আসবে: Terraform v1.17.2, aws-cli/2, plugin, kubectl v1.37.2, `ansible [core 2.21.6]`, দুইটা collection। কোনোটায় error এলে থামো।

**২.৪ Settings ফাইল।** আগে `aws sts get-caller-identity` একা চালাও। `Unable to locate credentials` এলে (২৪ নভেম্বর এসেছিল) `aws configure` চালাও: lab page-এর Access Key আর Secret Key, region `ap-southeast-1`, output `json`। Key কাউকে দেখাবে না।

Paste করার আগে `you@example.com`-এর জায়গায় নিজের email বসাও। এটা চালালে:
- SSH key বানাবে (একবারই);
- সব variable `~/shoplite.env`-এ রাখবে (Git-এর বাইরে);
- lab-এর IP নিজে বের করে `admin_cidr`-এ বসাবে।
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
- প্রথম লাইনে account আসবে। শেষে ৪টা `TF_VAR_` নাম আসতে হবে।
- Region `ap-southeast-1` না হলে ফাইলের দ্বিতীয় লাইন বদলাও, আর GitHub-এ variable `AWS_REGION` দাও।

## ৩. Terraform: AWS-এ সব বানানো (Q4, ~১০ মিনিট)

**৩.১ State-এর bucket:**
```bash
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap apply
```
- `Enter a value:` এলে `yes` লেখো।
- 📸 `q4/01-bootstrap-apply.png`: `Apply complete!` আর `state_bucket = ...`।

**৩.২ মূল configuration-এর init:**
```bash
BUCKET=$(terraform -chdir=terraform/bootstrap output -raw state_bucket)
terraform -chdir=terraform init \
  -backend-config="bucket=$BUCKET" \
  -backend-config="region=$(terraform -chdir=terraform/bootstrap output -raw region)"
```

**৩.৩ Apply, শুধু এই লাইনটা:**
```bash
terraform -chdir=terraform apply
```
- Plan-এর শেষে `Enter a value:` আসবে। **এখনই উত্তর দেবে না।** Apply এই অবস্থায় state-এর lock ধরে রাখে, সেটার প্রমাণ নিচে Terminal 2-এ নেবে।

**৩.৪ Lock-এর প্রমাণ (নতুন Terminal 2):**
```bash
source ~/shoplite.env && cd ~/shoplite-app
BUCKET=$(terraform -chdir=terraform/bootstrap output -raw state_bucket)
aws s3 ls "s3://$BUCKET/shoplite/"
terraform -chdir=terraform plan
```
- 📸 `q4/13-state-lock.png`: `terraform.tfstate.tflock` আর `Error acquiring the state lock`।

**৩.৫ Terminal 1-এ `yes` লেখো** (~৫–৮ মিনিট)।
- 📸 `q4/02-terraform-apply.png`: `Apply complete!` আর `Outputs:`। Scroll হয়ে গেলে আবার `terraform -chdir=terraform apply` চালাও; `No changes` আর outputs দেখাবে।

## ৪. Ansible: node সাজানো (Q4, ~১৫ মিনিট), Terminal 1

**৪.১ Inventory, তারপর ping** (bastion চালু হতে ~১ মিনিট লাগে; fail করলে ১ মিনিট পরে আবার):
```bash
terraform -chdir=terraform output -raw ansible_inventory > ansible/lab.ini
cd ansible && ansible -i lab.ini k3s_cluster -m ping
```
- তিন node-এই `"ping": "pong"` আসতে হবে।

**৪.২ প্রথম run (~৫–১০ মিনিট):** output `~/ansible-run1.log`-এ জমা থাকে।
```bash
ANSIBLE_FORCE_COLOR=1 ansible-playbook -i lab.ini site.yml | tee ~/ansible-run1.log
```
- `503 Service Unavailable` আসলে Ubuntu-র server ব্যস্ত ছিল। এই একই command আবার চালাও।
- শেষে `PLAY RECAP`-এ তিনটাতেই `failed=0` আসতে হবে। তারপর:
```bash
clear; grep -A4 'Show the container runtime' ~/ansible-run1.log; tail -n 6 ~/ansible-run1.log
```
- 📸 `q4/15-ansible-first-run.png`: এই command-এর পরে screen-এ যা আসে, শুধু সেটা (containerd version আর `PLAY RECAP`)।

**৪.৩ দ্বিতীয় run:** কিছুই বদলাবে না, এটাই প্রমাণ।
```bash
clear; ANSIBLE_FORCE_COLOR=1 ansible-playbook -i lab.ini site.yml | tail -n 6
cd ..
```
- 📸 `q4/16-ansible-second-run.png`: তিনটাতেই `changed=0`।

## ৫. kubectl

**Terminal 2:** এখানে tunnel চলতেই থাকবে। আটকে আছে মনে হলেও ঠিক আছে, বন্ধ করবে না:
```bash
source ~/shoplite.env && cd ~/shoplite-app
eval "$(terraform -chdir=terraform output -raw kubectl_tunnel)"
```
**Terminal 1:**
```bash
kubectl get nodes -o wide
```
- 📸 `q4/17-kubectl-get-nodes.png`: তিনটা `Ready`, শুধু private IP, `containerd://...-k3s1`।

## ৬. GitHub variable, তারপর image বানানো (OIDC-র পরীক্ষা)

**৬.১ মানগুলো দেখো (Terminal 1):**
```bash
terraform -chdir=terraform output -raw ci_role_arn; echo
terraform -chdir=terraform output -raw ci_plan_role_arn; echo
cat ~/.ssh/shoplite.pub
echo $TF_VAR_admin_cidr
```

**৬.২** https://github.com/SaikatGeek/shoplite-app/settings/variables/actions-এ variable গুলো দাও। আগে থাকলে **Edit** করে নতুন মান বসাও।

| Name | Value |
|---|---|
| `AWS_ROLE_ARN` | প্রথম লাইন (`...role/shoplite-github-ci`) |
| `AWS_PLAN_ROLE_ARN` | দ্বিতীয় লাইন (`...role/shoplite-github-plan`) |
| `SSH_PUBLIC_KEY` | তৃতীয় লাইন (`ssh-ed25519 ...`) |
| `ADMIN_CIDR` | চতুর্থ লাইন (`x.x.x.x/32`) |
| `LAB_ACTIVE` | `true` |

**৬.৩ Image বানাও:** https://github.com/SaikatGeek/shoplite-app/actions/workflows/main.yml → **Run workflow** → `main` → **Run workflow**।
- ~৫ মিনিট লাগবে। এর মধ্যে section ৭-এর screenshot গুলো নাও।
- **সবুজ হলে** OIDC কাজ করছে। Q5-এর `02-main-run.png` আর `03-ecr-images.png` নাও (Q5 procedure, section 2)।
- **"AWS credentials through OIDC"-এ লাল হলে** থামো। Error-এর screenshot নাও, পুরো error Claude-কে দেখাও (`NEXT-LAB.md`, section ৫)। ২৩ নভেম্বরের fix-এর পরে এটা হওয়ার কথা না।

## ৭. Q4-এর বাকি প্রমাণ (Terminal 1, `~/shoplite-app` থেকে)

প্রতিটা block-এর পরে ওই নামে screenshot নাও। লম্বা হলে `Ctrl` + `-` চেপে লেখা ছোট করো।

```bash
VPC=$(terraform -chdir=terraform output -raw vpc_id); echo $VPC
```

📸 `q4/03-state-list.png`:
```bash
clear; terraform -chdir=terraform state list
```

📸 `q4/04-subnets-routes.png`:
```bash
clear; aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC --query 'Subnets[].[Tags[?Key==`Name`]|[0].Value,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]' --output table; aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC Name=tag:project,Values=shoplite --query 'RouteTables[].[Tags[?Key==`Name`]|[0].Value,Routes[?DestinationCidrBlock==`0.0.0.0/0`]|[0].GatewayId,Routes[?DestinationCidrBlock==`0.0.0.0/0`]|[0].NatGatewayId,length(Associations[?SubnetId])]' --output table
```

📸 `q4/05-igw-nat.png`: শেষে node থেকে দেখা IP-টা NAT-এর IP-র সমান হতে হবে।
```bash
clear; aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$VPC --query 'InternetGateways[].[InternetGatewayId,Attachments[0].State]' --output table; aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=$VPC --query 'NatGateways[].[NatGatewayId,State,SubnetId,NatGatewayAddresses[0].PublicIp]' --output table; (cd ansible && ansible -i lab.ini control-plane -a 'curl -s https://checkip.amazonaws.com')
```

📸 `q4/06-security-groups.png`:
```bash
clear; aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC --query 'SecurityGroups[].[GroupName,GroupId]' --output table; aws ec2 describe-security-group-rules --filters Name=group-id,Values=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC --query 'SecurityGroups[].GroupId' --output text | tr '\t' ',') --query 'SecurityGroupRules[?IsEgress==`false`].[GroupId,IpProtocol,FromPort,ToPort,CidrIpv4,ReferencedGroupInfo.GroupId]' --output table
```

📸 `q4/07-nodes-no-public-ip.png`: শুধু bastion-এর public IP থাকবে।
```bash
clear; aws ec2 describe-instances --filters Name=vpc-id,Values=$VPC Name=instance-state-name,Values=running --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,InstanceId,PrivateIpAddress,PublicIpAddress,SubnetId]' --output table
```

📸 `q4/08-bastion-session.png`: bastion দিয়ে control plane-এ ঢোকা। প্রথম block ঢোকায়:
```bash
CP=$(awk -F= '/^control-plane /{print $2}' ansible/lab.ini)
eval "$(terraform -chdir=terraform output -raw ssh_via_bastion) ubuntu@$CP"
```
ভেতরে ঢুকে (prompt বদলে `ubuntu@ip-10-0-...` হবে) এটা চালাও, ছবি তোলো, তারপর `exit`:
```bash
hostname; ip -4 -brief address; sudo k3s kubectl get nodes
```

📸 `q4/09-alb-listeners.png`:
```bash
clear; terraform -chdir=terraform output app_urls; aws elbv2 describe-listeners --load-balancer-arn "$(aws elbv2 describe-load-balancers --names shoplite --query 'LoadBalancers[0].LoadBalancerArn' --output text)" --query 'Listeners[].[Port,Protocol,DefaultActions[0].TargetGroupArn]' --output table
```

📸 `q4/11-ecr-repositories.png`:
```bash
clear; aws ecr describe-repositories --query 'repositories[].[repositoryName,repositoryUri]' --output table
```

📸 `q4/12-state-in-s3.png`:
```bash
clear; aws s3 ls "s3://$(terraform -chdir=terraform/bootstrap output -raw state_bucket)" --recursive
```

📸 `q4/14-modules.png`:
```bash
clear; find terraform/modules -name '*.tf' -not -path '*/.terraform/*' | sort; terraform -chdir=terraform state list | grep '^module\.' | cut -d. -f1-2 | sort -u
```

📸 `q4/18-node-hardening.png`: bastion দিয়ে worker-1-এ ঢোকা।
```bash
W1=$(awk -F= '/^worker-1 /{print $2}' ansible/lab.ini)
eval "$(terraform -chdir=terraform output -raw ssh_via_bastion) ubuntu@$W1"
```
ভেতরে চালাও, ছবি তোলো, তারপর `exit`:
```bash
sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication) '; id deploy; ls -ld /var/log/shoplite && getfacl -p /var/log/shoplite; sudo ufw status verbose
```

📸 `q4/19-tagged-resources.png`: lab tagging API বন্ধ রাখে, তাই EC2-র নিজের API দিয়ে:
```bash
clear; aws ec2 describe-tags --filters Name=key,Values=project Name=value,Values=shoplite --query 'Tags[].[ResourceType,ResourceId]' --output table
```

📸 `q4/20-budget.png` (`AccessDenied` এলে সেটারই ছবি):
```bash
clear; aws budgets describe-budgets --account-id "$(aws sts get-caller-identity --query Account --output text)" --query 'Budgets[].[BudgetName,BudgetLimit.Amount,BudgetLimit.Unit,TimeUnit]' --output table
```

📸 `q4/10-target-health.png`: **Q5-এর ArgoCD sync-এর পরে** নেবে (Traefik চালু হলে target `healthy` হয়)।
```bash
clear; for tg in shoplite-prod shoplite-dev; do aws elbv2 describe-target-health --target-group-arn "$(aws elbv2 describe-target-groups --names $tg --query 'TargetGroups[0].TargetGroupArn' --output text)" --query 'TargetHealthDescriptions[].[Target.Id,Target.Port,TargetHealth.State]' --output table; done
```

## ৮. Q5 থেকে Q8

প্রতিটা প্রশ্নের procedure GitHub-এ খুলে section ধরে ক্রমে চালাও। প্রতিটা code block-এর ডান কোণে copy button আছে। নতুন terminal হলে আগে `source ~/shoplite.env && cd ~/shoplite-app`।

**Q5** (~৪০ মিনিট): https://github.com/SaikatGeek/shoplite-app/blob/main/docs/evidence/q5/commands.md
- Section 1-এর Helm install। `ALB` রাখো `~/shoplite.env`-এ, যাতে নতুন terminal-এও থাকে (block দুইবার paste করবে না):
  ```bash
  echo 'export ALB=http://$(aws elbv2 describe-load-balancers --names shoplite --query "LoadBalancers[0].DNSName" --output text)' >> ~/shoplite.env
  source ~/shoplite.env && echo "$ALB"
  ```
- তারপর section 2 (main run), 3 (bootstrap), 4 (promote আর prod sync), 5, 6।
- Section 3: `read -rsp 'Slack webhook URL: ' SLACK_WEBHOOK_URL; echo` **হুবহু** চালাও, URL দাও **পরে** prompt-এ, Enter। Command-এর ভেতরে URL লিখবে না (২৪ নভেম্বর এভাবে URL ফাঁস হয়েছিল)।
- ArgoCD-র password: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo`।
- **Q5-এর ১৯টা ছবি ২৪ নভেম্বর নেওয়া হয়ে গেছে।** পরের session-এ শুধু setup (Helm, `ALB`, main run, bootstrap, promote, prod sync), ছবি ছাড়া।
- Prod-এর sync ArgoCD-র UI-তে হাতে করতে হয়: REFRESH → SYNC।
- 📸 `q5/02`–`19`: `02-main-run`, `03-ecr-images`, `04-bootstrap`, `05-argocd-applications`, `06-promote-run`, `07-argocd-prod-synced`, `08-applications-synced`, `09-workloads`, `10-probes-pdb-hpa`, `11-postgres-seed`, `12-resources-non-root`, `13-secret-configmap`, `14-no-secret-in-git`, `15-networkpolicy`, `16-traefik`, `17-helm-chart`, `18-checkpoint-browser`, `19-checkpoint-database`।
- V2 লাগবে না: checkpoint-এর ছবি 18, 19 আছে।
- Q4-এর `10-target-health.png`-ও আছে (২৪ নভেম্বর)।

**Q6** (~৫ মিনিট): https://github.com/SaikatGeek/shoplite-app/blob/main/docs/evidence/q6/commands.md
- **পরের session-এ শুধু section 0 (k6 install)**, setup-এর শেষে: Q8 আর demo-তে k6 লাগে। ছবি সব আছে (01–16); section 8 (V3, 17) বাদ।
- নিচের তালিকা আগের session-এর, রেফারেন্সের জন্য। ২৪ নভেম্বর 01–14 lab-এ, 15, 16 Slack থেকে।
- Grafana-র password: `kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo`।
- Explore-এ query লেখো **Code** mode-এ (Builder না); table-এর জন্য Options → Type **Instant**।
- 📸 `q6/01`–`16` (সব আছে): `01-monitoring-pods`, `02-datasources`, `03-targets-up`, `04-servicemonitors`, `05-six-metrics`, `06-dashboard-load`, `07-dashboard-configmap`, `08-log-to-trace`, `09-order-trace`, `10-trace-to-logs`, `11-exemplar`, `12-exemplar-trace`, `13-alert-rules`, `14-alert-labels`, `15-slack-alert`, `16-slack-resolved`। `17-dev-recovered` বাদ।
- Lab machine push করতে পারে না। shoplite-gitops-এ বদলানো GitHub-এর web editor-এ।

**Q7** (~৩৫ মিনিট): https://github.com/SaikatGeek/shoplite-app/blob/main/docs/evidence/q7/commands.md
- Section 0 (variable, উপরে হয়ে গেছে) থেকে 6।
- PR গুলো GitHub-এর web editor-এ খুলবে, **কখনো merge করবে না**।
- আছে: 01–05, 08 (03–05 GitHub থেকে; PR 1 আর 2 merge ছাড়া বন্ধ)।
- **পরের session-এ, setup-এর পরে, Q8-এর আগে:** section 4-এর 09, 10 (ArgoCD-র Details → Sync Policy), তারপর section 3-এর ধাপ 2: Terraform-এর PR (06, 07; `LAB_ACTIVE=true` থাকতে হবে)। PR merge করবে না; ছবির পরে বন্ধ করে branch মুছবে।
- Section 5 (self-heal) আর 6 (title) শেষের demo video-র ভেতরে, সাথে 11 (NEXT-LAB-এর section ৯)।
- 📸 `q7/01`–`11`: `01-main-run`, `02-ecr-sha-tags`, `03-gitops-ci-commit`, `04-trivy-red`, `05-pr-checks`, `06-terraform-plan-comment`, `07-terraform-pr-checks`, `08-argocd-apps`, `09-dev-sync-policy`, `10-prod-sync-policy`, `11-new-title`।
- Title-এর commit তোমার PC থেকে: `shoplite-app/services/web/public/index.html`-এর `<title>` বদলাও, commit করো, `git push`, তারপর `bash publish-repos.sh push`। এর জন্য OIDC কাজ করতে হবে (main-কে ECR-এ push করতে হয়)।

**Q8** (~৮০ মিনিট; অন্তত ১ ঘণ্টা ৪৫ মিনিট বাকি থাকতে হবে): https://github.com/SaikatGeek/shoplite-app/blob/main/docs/evidence/q8/commands.md
- Section 1 থেকে 8, ক্রমে। **Peer লাগবে না** (instructor নিজে করতে বলেছেন, ২৪ নভেম্বর)।
- Fault চালু করবে তোমার PC থেকে, section 4-এ। Script random একটা বেছে push করে, কোনটা বেছেছে দেখায় না:
  - অফিসে (PC-01), Git Bash-এ:
    ```bash
    cd ~ && bash /e/devops-final/shoplite-app/scripts/chaos-pick.sh
    ```
  - বাসায়, Git Bash-এ:
    ```bash
    cd ~ && bash /e/Personal/devops-final/shoplite-app/scripts/chaos-pick.sh
    ```
  - Output-এ শুধু commit-এর hash আসবে, সেটা `mark`-এ লেখো।
  - RCA লেখা শেষ না হওয়া পর্যন্ত ওই commit খুলবে না: GitHub-এ না, `git show`-এ না, ArgoCD-র APP DIFF-এ না।
- Section 3 থেকে 7 পর্যন্ত shoplite-app-এ কোনো push বা workflow না।
- Revert তোমার PC থেকে, script যে `~/q8-gitops` clone বানিয়েছে সেখান থেকে (section 6)।
- Destroy-এর আগে section 8-এর সংখ্যা আর `cat ~/q8-timeline.txt` রেখে দেবে।
- 📸 `q8/01`–`16` (procedure-এ প্রতিটার নাম; `02-fault-pushed` হলো তোমার PC-র terminal-এ script-এর output)।
- **Recording না:** procedure-এর section 3-এর ধাপ 2 ("Start the screen recording") আর section 7-এর recording বন্ধ করা বাদ দাও।

**শেষের demo video** (~২০ মিনিট, Q8-এর পরে, destroy-এর আগে): NEXT-LAB-এর section ৯-এর ক্রমে। Recording চালু করে শুরু, `q7/11` সহ।

## ৯. শেষে: destroy (destroy শেষ করতে ১০ মিনিট লাগে, তাই এর আগেই শুরু করবে)

Q3-এর server থাকলে আগে `terraform -chdir=terraform/q3-server destroy`। তারপর:
```bash
terraform -chdir=terraform destroy
```
- `yes` লেখো।
- 📸 `q4/21-destroy.png`: `Destroy complete!`।
```bash
terraform -chdir=terraform/bootstrap destroy
```
- GitHub-এ `LAB_ACTIVE` = `false` করো।

**Lab terminal বন্ধ হয়ে গেলে, কিন্তু AWS console খোলা থাকলে** (আজ এটাই হয়েছিল): PC-01 থেকে Docker দিয়ে।
- Claude-কে বলো "PC থেকে destroy"। ও `C:\Users\PC-01\aws-lab.env` ফাইলের কাঠামো বানিয়ে Notepad-এ খুলে দেবে।
- তুমি Poridhi-র page থেকে Access Key আর Secret Key বসিয়ে save করবে। বাকিটা Claude চালাবে।
- কীভাবে কাজ করে তার বিবরণ: Q4 procedure-এর "After grading" অংশ।

## ১০. শুধু দরকার হলে: OIDC ছাড়া image পাঠানো (তোমার আর instructor-এর সিদ্ধান্তের পরে)

২৩ নভেম্বরের OIDC-র fail-এর কারণ পাওয়া গেছে আর ঠিক করা হয়েছে (`NEXT-LAB.md`, section ৫), তাই এটা লাগার কথা না। Main-এর OIDC lab-এ তবু আটকে গেলে Q5–Q8 থামিয়ে না রাখার উপায় এটা। PC-01-এ Git Bash-এ চলবে, key-এর ফাইল লাগবে (section ৯-এর মতো)।
1. Claude দিয়ে image বানিয়ে ECR-এ push করাও (`scripts/ci.sh build`, `docker push`)।
2. shoplite-gitops-এর `envs/dev/values.yaml` GitHub-এর web editor-এ বদলাও:
   ```yaml
   image:
     registry: "<account>.dkr.ecr.ap-southeast-1.amazonaws.com"
     tag: "<7 অক্ষরের tag>"
   ```
3. README-র deviation-এ লেখো যে lab OIDC আটকায়।

এর আগে Claude-কে `NEXT-LAB.md`-এর section ৫ দেখাও।
