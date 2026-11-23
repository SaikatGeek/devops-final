# পরের lab: কোথায় আছি, কী বদলাবে, কীভাবে এগোব

শেষ আপডেট: ২৩ নভেম্বর ২০২৬, প্রথম AWS lab session-এর পরে।

## ০. বাসায় বা নতুন কোনো session-এ Claude-কে এটা পাঠাও

```text
CLAUDE.md, PROGRESS.md, NEXT-LAB.md আর LAB-RUNBOOK.md পড়ো। আমি নতুন lab খুলব। NEXT-LAB.md-র section ৫ (OIDC) আর LAB-RUNBOOK.md ধরে আমাকে ধাপে ধাপে চালাও। ছোট করে বলবে, এক ধাপ এক বার।
```

- PC বদলালে আগে `OFFICE-PC-GUIDE.md`-এর section ৯ (git pull ইত্যাদি)।
- বাসার PC-তে repo আছে `E:\Personal\devops-final`-এ, অফিসে (PC-01) `E:\devops-final`-এ।

## ১. এখন কোথায় আছি

| প্রশ্ন | Code | Lab-এ চালানো | Screenshot |
|---|---|---|---|
| Q1, Q2 | শেষ | Q2-এর checkpoint Q3-এর session-এ (video V1) | — |
| Q3 | শেষ | বাকি (আলাদা ছোট session) | কোনোটা নেই |
| Q4 | শেষ (bastion সহ) | একবার পুরো চলেছে | 01–07, 09, 11–17, 19–21 আছে; বাকি 05 (আবার, node-এর `checkip` সহ), 08, 10, 18 |
| Q5 | শেষ | বাকি | শুধু `01-github-settings.png` |
| Q6, Q7, Q8 | শেষ | বাকি | নেই |

- AWS-এ এখন কিছু নেই। সব destroy হয়েছে (৬১টা resource আর state bucket), যাচাই করা।
- GitHub-এর secret `GITOPS_DEPLOY_KEY` আর `BUDGET_ALERT_EMAIL` দেওয়া আছে। এরা থেকে যায়, আবার দিতে হবে না।
- Slack webhook বানানো আছে (URL কোথাও লেখা নেই; Slack-এর app page থেকে আবার copy করতে হবে)।

## ২. আজ code-এ যা বদলেছে (সব GitHub-এ)

- **Bastion host** (`terraform/modules/compute/bastion.tf`): lab-এর policy SSM-এর session বন্ধ রাখে, তাই node-এ ঢোকা এখন bastion দিয়ে।
  - নতুন variable `admin_cidr` (`TF_VAR_admin_cidr`): lab terminal-এর public IP `/32`। শুধু এই IP থেকে bastion-এ SSH।
  - Output `ansible_inventory`, `kubectl_tunnel` আগের নামেই আছে, এখন bastion দিয়ে যায়। নতুন output `bastion_public_ip`, `ssh_via_bastion`।
  - PR plan workflow নতুন GitHub variable `ADMIN_CIDR` পড়ে।
- **web image**: nginx 1.30.7 (nginx.org-এর repo থেকে), কারণ 1.30.6-এ ৪টা নতুন CRITICAL CVE, Trivy gate আটকাচ্ছিল।
- Security group-এর description-এ apostrophe (`'`) দেওয়া যায় না। ঠিক করা হয়েছে, আর তার জন্য test আছে।
- Docs: Q4-এর procedure (bastion, env ফাইল, locale, 503 হলে আবার চালানো, screenshot-এর command), README-র deviation, Q5/Q7-এর variable।

## ৩. Poridhi lab সম্পর্কে যা জানা গেল (ভুলগুলো যেন আর না হয়)

- Terminal-এর user `poridhian`, `sudo` password চায় না। `apt-get` সবসময় `sudo` দিয়ে।
- Clone সবসময় `~`-এ: `cd ~` তারপর দুইটা `git clone`, পাশাপাশি।
- `LANG=en_US.UTF-8`-এর locale নেই, তাই Ansible চলে না → `export LANG=C.UTF-8 LC_ALL=C.UTF-8`।
- Terminal নতুন হলে সব `export` হারায় → সব variable `~/shoplite.env`-এ রাখো; প্রতিটা terminal-এ `source ~/shoplite.env && cd ~/shoplite-app`।
- Terraform বা Ansible যখন `Enter a value:` চায়, সেখানে আলাদা করে উত্তর দাও। Block-এর পরের লাইন একসাথে paste হলে সেটাই উত্তর হয়ে যায়।
- Lab-এর organization policy (SCP) যা বন্ধ রাখে: SSM session (`ssmmessages`), Run Command, CloudTrail (`LookupEvents`), tagging API (`tag:GetResources`), CloudShell।
- ECR চলে (region `ap-southeast-1`)। IAM simulator region না দিলে ভুল করে deny দেখায়।
- Ubuntu-র mirror মাঝে মাঝে `503` দেয় → playbook আবার চালাও।
- Lab-এর timer ৫ ঘণ্টা। Terminal বন্ধ হওয়ার পরেও AWS console ~১ ঘণ্টা খোলা থাকে।
  - Poridhi-র page-এ Access Key আর Secret Key দেখা যায়।
  - তাই terminal হারালেও PC-01 থেকে Docker দিয়ে destroy করা যায় (LAB-RUNBOOK, section ৯)।

## ৪. নতুন lab = নতুন machine, হয়তো নতুন AWS account: প্রতিবার যা বদলায়

| কোথায় | কী | কেন বদলায় |
|---|---|---|
| Lab terminal | tools, clone, `~/.ssh/shoplite` key, `~/shoplite.env` | machine নতুন |
| GitHub variable `SSH_PUBLIC_KEY` | নতুন key-এর `.pub` | key নতুন |
| GitHub variable `ADMIN_CIDR` | নতুন IP `/32` | lab-এর IP বদলাতে পারে |
| GitHub variable `AWS_ROLE_ARN`, `AWS_PLAN_ROLE_ARN` | Terraform-এর output | account বদলালে ARN বদলায় |
| GitHub variable `LAB_ACTIVE` | শুরুতে `true`, শেষে `false` | session-এর বাইরে CI যেন AWS না খোঁজে |
| GitHub variable `AWS_REGION` | শুধু region `ap-southeast-1` না হলে | — |
| shoplite-gitops `envs/dev/values.yaml` | CI নিজে লেখে (registry, tag) | ECR নতুন, তাই main আবার চালাতে হয় |
| shoplite-gitops `envs/prod/values.yaml` | promote workflow লেখে | dev-এর image prod-এ নিতে |

- Code-এ কিছু বদলাতে হয় না।
- Secret দুইটা (`GITOPS_DEPLOY_KEY`, `BUDGET_ALERT_EMAIL`) থেকে যায়।

## ৫. সবচেয়ে বড় খোলা সমস্যা: GitHub → AWS (OIDC)

- কী হয়েছে: main workflow-এর lint, test, build আর Trivy scan pass করে। কিন্তু "AWS credentials through OIDC" ধাপে ১২ বার চেষ্টার পরেও `Not authorized to perform sts:AssumeRoleWithWebIdentity` আসে।
- যা ঠিক আছে বলে যাচাই করা হয়েছে:
  - OIDC provider (`sts.amazonaws.com`);
  - role-এর trust (`repo:SaikatGeek/shoplite-app:ref:refs/heads/main`);
  - Action `sts:AssumeRoleWithWebIdentity`।
- সম্ভাব্য কারণ: lab-এর organization policy GitHub-এর OIDC আটকায়। CloudTrail বন্ধ, তাই প্রমাণ দেখা যায়নি।
- প্রশ্নে OIDC চাওয়া আছে ("Push images to ECR using OpenID Connect"), আর grading-এ এর নম্বর আছে। তাই এটা নিজে নিজে বাদ দেওয়া যাবে না।

**পরের session-এর পরিকল্পনা:**
1. Q4 apply শেষ হলেই GitHub variable দিয়ে main-এর "Run workflow" চালাও (LAB-RUNBOOK, section ৬)।
2. OIDC pass করলে: সমস্যা মিটে গেছে, স্বাভাবিকভাবে Q5-এ যাও।
3. আবার fail করলে:
   - error-এর screenshot রাখো (`docs/evidence/q7/` বা `q5/`);
   - instructor-কে জানাও (নিচের বার্তা);
   - Q5–Q8 আটকে না রেখে, instructor রাজি হলে, PC-01 থেকে image ECR-এ পাঠাও (LAB-RUNBOOK, section ১০)। README-র deviation-এ লিখতে হবে।
   - এই বিকল্পটা এখনো তোমার সিদ্ধান্তের অপেক্ষায়। Claude-কে জিজ্ঞেস করো।

Instructor-কে বার্তা (ইংরেজিতে, দরকার হলে বদলে নাও):

```text
In the Poridhi AWS lab, GitHub Actions cannot assume an IAM role through OIDC: the role's
trust policy is correct (aud sts.amazonaws.com, sub repo:SaikatGeek/shoplite-app:ref:refs/heads/main),
but sts:AssumeRoleWithWebIdentity is denied. The lab's service control policy also denies
CloudTrail, so I cannot see the reason. Question 7 asks for OIDC. May I push the images with
the lab user's keys instead, or can OIDC be allowed in my lab account?
```

## ৬. বাকি কাজ, ক্রমে

**Lab-এর আগে (Claude করবে, তোমার "হ্যাঁ" নিয়ে):**
1. OIDC fail করলে কী বিকল্প নেব, সেটা ঠিক করা (উপরের section ৫)।
2. Architecture diagram-এর PNG আবার বানানো (`shoplite-app/docs/architecture-diagram.png`; লেখায় bastion যোগ হয়েছে, ছবিতে এখনো SSM)।

**তোমার প্রস্তুতি:**
3. Q8-এর peer ঠিক করা (lab শুরুর ~৩ ঘণ্টা পরে তার ১৫ মিনিট লাগবে)। Link: https://github.com/SaikatGeek/shoplite-app/blob/main/docs/evidence/q8/commands.md#the-peers-part
4. Slack webhook URL হাতের কাছে রাখা।
5. Screen recorder ঠিক রাখা (Q5-এর checkpoint থেকে লাগবে: V2, V3, V4, V5, V6)।

**পরের lab session (৫ ঘণ্টা), LAB-RUNBOOK ধরে:**
6. Q4 (~৩০–৪০ মিনিট) আর বাকি screenshot 05, 08, 18। 10 নেওয়া হবে Q5-এর পরে।
7. GitHub variable, main-এর run (OIDC পরীক্ষা)।
8. Q5 (~৪০ মিনিট), Q6 (~৫০), Q7 (~৩৫), Q8 (~৮০)। Q8-এর জন্য অন্তত ১ ঘণ্টা ৪৫ মিনিট বাকি থাকতে হবে, না থাকলে Q8 আরেক session-এ।
9. শেষে destroy, `21-destroy.png` আবার (নতুন session-এর), `LAB_ACTIVE=false`।

**আলাদা ছোট session:**
10. Q3 (~৪০ মিনিট): `linux/evidence/commands.md`, video V1।

**সব lab-এর পরে:**
11. Screenshot commit আর publish (`bash publish-repos.sh push`)।
12. RCA লেখা, তারপর আলাদা commit-এ peer-এর পরিবর্তনের সাথে মিলিয়ে দেখা।
13. Video V1–V6 কাটা।
14. README-র evidence index আর deviation শেষবার মিলিয়ে দেখা।
