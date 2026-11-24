# পরের lab: কোথায় আছি, কী বদলাবে, কীভাবে এগোব

শেষ আপডেট: ২৪ নভেম্বর ২০২৬, দ্বিতীয় AWS lab session-এর পরে (OIDC কাজ করেছে; Q4, Q5 শেষ)।

## ০. বাসায় বা নতুন কোনো session-এ Claude-কে এটা পাঠাও

```text
CLAUDE.md, PROGRESS.md, NEXT-LAB.md আর LAB-RUNBOOK.md পড়ো। আমি নতুন lab খুলব। NEXT-LAB.md-র section ৬ আর LAB-RUNBOOK.md ধরে আমাকে ধাপে ধাপে চালাও। প্রতিটা ধাপে ছোট করে "কেন" বলবে, এক ধাপ এক বার।
```

- PC বদলালে আগে `OFFICE-PC-GUIDE.md`-এর section ৯ (git pull ইত্যাদি)।
- বাসার PC-তে repo আছে `E:\Personal\devops-final`-এ, অফিসে (PC-01) `E:\devops-final`-এ।

## ১. এখন কোথায় আছি

| প্রশ্ন | Code | Lab-এ চালানো | Screenshot / video |
|---|---|---|---|
| Q1, Q2 | শেষ | Q2-এর checkpoint Q3-এর session-এ | V1 বাকি |
| Q3 | শেষ | বাকি (আলাদা ছোট session) | কোনোটা নেই |
| Q4 | শেষ | দুইবার পুরো চলেছে | **২১টাই আছে** (21 নতুন session-এর) |
| Q5 | শেষ | ২৪ নভেম্বর পুরো চলেছে | **১৯টাই আছে**; V2 record হয়েছে কি না নিশ্চিত না (না হলে আবার) |
| Q6 | শেষ | ২৪ নভেম্বর চলেছে | ১৭টার ১৬টা (15, 16 Slack থেকে, ২৪ নভেম্বর PC-01-এ); বাকি 17, video V3 |
| Q7 | শেষ | main আর promote চলেছে, OIDC সবুজ | ১১টার ৬টা (01–05, 08; 03–05 GitHub থেকে, ২৪ নভেম্বর PC-01-এ); বাকি 06, 07, 09, 10, 11, video V4, V5 |
| Q8 | শেষ | বাকি (peer বা instructor লাগবে) | নেই |

- AWS-এ এখন কিছু নেই: ২৪ নভেম্বর destroy হয়েছে (৬১টা resource আর state bucket)।
- GitHub: `LAB_ACTIVE` = `false`। Secret `GITOPS_DEPLOY_KEY` আর `BUDGET_ALERT_EMAIL` আছে।
- **Slack webhook:** ২৪ নভেম্বর একটা URL ভুল করে terminal-এ আর chat-এ দেখা গিয়েছিল। সেটা না বদলে থাকলে Slack-এ পুরোনোটা Remove করে নতুন বানাও।
- **খোলা PR (merge করবে না):**
  - [PR 1 `trivy-red`](https://github.com/SaikatGeek/shoplite-app/pull/1): লাল, `CRITICAL: 5` (brotli আর nginx-এর CVE)। Q7-এর `04`।
  - [PR 2 `pr-check`](https://github.com/SaikatGeek/shoplite-app/pull/2): সবুজ। Q7-এর `05`।
  - দুটোর ছবি নেওয়া হয়ে গেছে (Q7 `04`, `05`)। এখন বন্ধ করে branch মোছা যায়।

## ২. ২৩–২৪ নভেম্বর code-এ যা বদলেছে (সব GitHub-এ)

- **OIDC-র fix** (`e26efcc`): GitHub নতুন repo-র token-এর `sub`-এ owner আর repo-র নম্বর দেয়। Trust এখন সেটাই চায়। ২৪ নভেম্বরের lab-এ main-এর OIDC ধাপ সবুজ, image ECR-এ গেছে।
- **Bastion host** (`terraform/modules/compute/bastion.tf`): lab-এর policy SSM-এর session বন্ধ রাখে, তাই node-এ ঢোকা bastion দিয়ে।
- **web image**: nginx 1.30.7 (nginx.org-এর repo থেকে), কারণ 1.30.6-এ ৪টা CRITICAL CVE।
- Q7-এর procedure: Trivy-র লাল PR-এ এখন web-এর পুরো patch-এর block মোছা হয় (`USER 0` থেকে `USER 101`)।

## ৩. Poridhi lab সম্পর্কে যা জানা গেল (ভুলগুলো যেন আর না হয়)

- **নতুন lab-এ AWS-এর key আগে থেকে না-ও থাকতে পারে** (২৪ নভেম্বর ছিল না: `Unable to locate credentials`)। তখন `aws configure`: lab page-এর Access Key আর Secret Key, region `ap-southeast-1`, output `json`। Key কাউকে দেখাবে না।
- Terminal-এর user `poridhian`, `sudo` password চায় না। `apt-get` সবসময় `sudo` দিয়ে।
- Clone সবসময় `~`-এ: `cd ~` তারপর দুইটা `git clone`, পাশাপাশি।
- `LANG=en_US.UTF-8`-এর locale নেই, তাই Ansible চলে না → `export LANG=C.UTF-8 LC_ALL=C.UTF-8`।
- Terminal নতুন হলে সব `export` হারায় → সব variable `~/shoplite.env`-এ রাখো; প্রতিটা terminal-এ `source ~/shoplite.env && cd ~/shoplite-app`। `ALB`-ও সেখানে রাখো (LAB-RUNBOOK, section ৮)।
- Terraform বা Ansible যখন `Enter a value:` চায়, সেখানে আলাদা করে উত্তর দাও। Block-এর পরের লাইন একসাথে paste হলে সেটাই উত্তর হয়ে যায়। একই block দুইবার paste করলে লাইন জোড়া লেগে যেতে পারে।
- **Slack-এর URL:** `read -rsp 'Slack webhook URL: ' SLACK_WEBHOOK_URL; echo` হুবহু চালাও, URL দাও **পরে** prompt-এ। Command-এর ভেতরে URL লিখলে সেটা screen-এ আর history-তে থেকে যায়।
- **Grafana-র Explore:** query লেখো **Code** mode-এ (Builder না)। Table চাইলে Options → Type **Instant**।
- Lab-এর organization policy (SCP) যা বন্ধ রাখে: SSM session (`ssmmessages`), Run Command, CloudTrail (`LookupEvents`), tagging API (`tag:GetResources`), CloudShell।
- ECR চলে (region `ap-southeast-1`)। IAM simulator region না দিলে ভুল করে deny দেখায়।
- Ubuntu-র mirror মাঝে মাঝে `503` দেয় → playbook আবার চালাও।
- Lab-এর timer ৫ ঘণ্টা। Terminal বন্ধ হওয়ার পরেও AWS console ~১ ঘণ্টা খোলা থাকে; তখন PC থেকে Docker দিয়ে destroy করা যায় (LAB-RUNBOOK, section ৯)।
- ২৪ নভেম্বরের সময়: Q4-এর setup ~৪৫ মিনিট, Q5 ~৪০, Q6-এর ১৪টা ছবি ~৪০, destroy ~১৫।

## ৪. নতুন lab = নতুন machine, হয়তো নতুন AWS account: প্রতিবার যা বদলায়

| কোথায় | কী | কেন বদলায় |
|---|---|---|
| Lab terminal | `aws configure` (দরকার হলে), tools, clone, `~/.ssh/shoplite` key, `~/shoplite.env` | machine নতুন |
| GitHub variable `SSH_PUBLIC_KEY` | নতুন key-এর `.pub` | key নতুন |
| GitHub variable `ADMIN_CIDR` | নতুন IP `/32` | lab-এর IP বদলায় (২৩ → ২৪ নভেম্বর `.14` → `.64`) |
| GitHub variable `AWS_ROLE_ARN`, `AWS_PLAN_ROLE_ARN` | Terraform-এর output | account বদলালে ARN বদলায় (২৪ নভেম্বর একই account `041793356414`) |
| GitHub variable `LAB_ACTIVE` | শুরুতে `true`, শেষে `false` | session-এর বাইরে CI যেন AWS না খোঁজে |
| GitHub variable `AWS_REGION` | শুধু region `ap-southeast-1` না হলে | — |
| shoplite-gitops `envs/dev/values.yaml` | CI নিজে লেখে (registry, tag) | ECR নতুন, তাই main আবার চালাতে হয় |
| shoplite-gitops `envs/prod/values.yaml` | promote workflow লেখে | dev-এর image prod-এ নিতে |

## ৫. GitHub → AWS (OIDC): মিটে গেছে

- ২৩ নভেম্বরের `Not authorized to perform sts:AssumeRoleWithWebIdentity`-এর কারণ ছিল trust-এর পুরোনো `sub`, lab-এর policy না।
- আসল `sub`: `repo:SaikatGeek@53232305/shoplite-app@1454879820:ref:refs/heads/main` (GitHub-এর "immutable subject", ১৫ জুলাই ২০২৬-এর পরে বানানো repo-তে)।
- Fix `e26efcc`; ২৪ নভেম্বর lab-এ main run #11 সবুজ: OIDC, ECR-এ push, gitops-এ `dev: images 6025631`।
- Repo কখনো মুছে আবার বানালে ID বদলায়: তখন `terraform/main.tf`-এর দুই ID বদলাতে হবে।

## ৬. বাকি কাজ, ক্রমে

**তোমার প্রস্তুতি (lab-এর আগে):**
1. Q8-এর peer বা instructor-এর সাথে সময় ঠিক করা (lab শুরুর ~২ ঘণ্টা পরে তার ১৫ মিনিট)। Link: https://github.com/SaikatGeek/shoplite-app/blob/main/docs/evidence/q8/commands.md#the-peers-part
2. Slack webhook (দরকার হলে নতুন) হাতের কাছে রাখা।
3. Screen recorder ঠিক রাখা: V3, V4, V5, V6 (আর V2, যদি ২৪ নভেম্বর record না হয়ে থাকে)।
4. ~~খোলা PR দুটোর ছবি~~ হয়ে গেছে (২৪ নভেম্বর): Q7 `03`, `04`, `05`, আর Q6 `15`, `16`।

**পরের lab session (৫ ঘণ্টা), LAB-RUNBOOK ধরে, Q4 আর Q5-এর ছবি ছাড়া:**
5. Setup (~১ ঘণ্টা): section ২–৬ (Q4), তারপর Q5-এর Helm, `ALB`, bootstrap, promote, prod sync। কোনো ছবি না।
6. Q6 (~২০ মিনিট): video V3 আর 17।
7. Q7 (~৪০ মিনিট): Terraform plan-এর PR (06, 07), ArgoCD-র 09, 10, self-heal V5, title V4 আর 11।
8. Q8 (~৮০ মিনিট), peer বা instructor সহ। অন্তত ১ ঘণ্টা ৪৫ মিনিট বাকি থাকতে হবে।
9. শেষে destroy, `LAB_ACTIVE=false`।

**আলাদা ছোট session:**
10. Q3 (~৪০ মিনিট): `linux/evidence/commands.md`, video V1।

**সব lab-এর পরে (Claude করবে):**
11. Screenshot commit আর publish (`bash publish-repos.sh push`), খোলা PR বন্ধ।
12. RCA লেখা, তারপর আলাদা commit-এ peer-এর পরিবর্তনের সাথে মিলিয়ে দেখা।
13. Video V1–V6 কাটা (তুমি)।
14. Architecture diagram-এর PNG আবার বানানো (bastion সহ; এখনো SSM দেখায়)।
15. README-র evidence index আর deviation শেষবার মিলিয়ে দেখা।
