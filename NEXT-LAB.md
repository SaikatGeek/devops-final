# পরের lab: কোথায় আছি, কী বদলাবে, কীভাবে এগোব

শেষ আপডেট: ২৪ নভেম্বর ২০২৬, PC-01: Q8 peer ছাড়া (chaos-pick.sh), আজকের lab-এর সময়সূচি, credential, video আর RCA-র গাইড (section ৭–১০)।

## ০. বাসায় বা নতুন কোনো session-এ Claude-কে এটা পাঠাও

```text
CLAUDE.md, PROGRESS.md, NEXT-LAB.md আর LAB-RUNBOOK.md পড়ো। আমি নতুন lab খুলব। NEXT-LAB.md-র section ৬–৯ আর LAB-RUNBOOK.md ধরে আমাকে ধাপে ধাপে চালাও। প্রতিটা ধাপে ছোট করে "কেন" বলবে, এক ধাপ এক বার।
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
| Q8 | শেষ (peer ছাড়া চালানোর script সহ) | বাকি | নেই (মোট ১৬টা) |

- AWS-এ এখন কিছু নেই: ২৪ নভেম্বর destroy হয়েছে (৬১টা resource আর state bucket)।
- GitHub: `LAB_ACTIVE` = `false`। Secret `GITOPS_DEPLOY_KEY` আর `BUDGET_ALERT_EMAIL` আছে।
- **Slack webhook:** ২৪ নভেম্বর একটা URL ভুল করে terminal-এ আর chat-এ দেখা গিয়েছিল। সেটা না বদলে থাকলে Slack-এ পুরোনোটা Remove করে নতুন বানাও।
- **খোলা PR (merge করবে না):**
  - [PR 1 `trivy-red`](https://github.com/SaikatGeek/shoplite-app/pull/1): লাল, `CRITICAL: 5` (brotli আর nginx-এর CVE)। Q7-এর `04`।
  - [PR 2 `pr-check`](https://github.com/SaikatGeek/shoplite-app/pull/2): সবুজ। Q7-এর `05`।
  - দুটোর ছবি নেওয়া হয়ে গেছে (Q7 `04`, `05`)। ২৪ নভেম্বর দুটোই merge ছাড়া বন্ধ, branch মোছা (যাচাই: main `d95c25f`-এ, `trivy-red` আর `pr-check` নেই)।

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
1. ~~Q8-এর peer~~ লাগবে না: instructor নিজে করতে বলেছেন (২৪ নভেম্বর)। Fault চালু করবে `shoplite-app/scripts/chaos-pick.sh`, তোমার PC থেকে। ওটা random একটা বেছে push করে, কোনটা দেখায় না (LAB-RUNBOOK-এর Q8)।
2. Slack webhook (দরকার হলে নতুন) হাতের কাছে রাখা।
3. Screen recorder ঠিক রাখা: V3, V4, V5, V6 (আর V2, যদি ২৪ নভেম্বর record না হয়ে থাকে)।
4. ~~খোলা PR দুটোর ছবি~~ হয়ে গেছে (২৪ নভেম্বর): Q7 `03`, `04`, `05`, আর Q6 `15`, `16`।

**পরের lab session (৫ ঘণ্টা), LAB-RUNBOOK ধরে, Q4 আর Q5-এর ছবি ছাড়া:**
5. Setup (~১ ঘণ্টা): section ২–৬ (Q4), তারপর Q5-এর Helm, `ALB`, bootstrap, promote, prod sync। কোনো ছবি না।
6. Q6 (~২০ মিনিট): video V3 আর 17।
7. Q7 (~৪০ মিনিট): Terraform plan-এর PR (06, 07), ArgoCD-র 09, 10, self-heal V5, title V4 আর 11।
8. Q8 (~৮০ মিনিট), peer ছাড়া, `chaos-pick.sh` দিয়ে। অন্তত ১ ঘণ্টা ৪৫ মিনিট বাকি থাকতে হবে।
9. শেষে destroy, `LAB_ACTIVE=false`।

**আলাদা ছোট session:**
10. Q3 (~৪০ মিনিট): `linux/evidence/commands.md`, video V1।

**সব lab-এর পরে (Claude করবে):**
11. Screenshot commit আর publish (`bash publish-repos.sh push`), খোলা PR বন্ধ।
12. RCA লেখা, তারপর আলাদা commit-এ fault-এর commit-এর সাথে মিলিয়ে দেখা।
13. Video V1–V6 কাটা (তুমি)।
14. Architecture diagram-এর PNG আবার বানানো (bastion সহ; এখনো SSM দেখায়)।
15. README-র evidence index আর deviation শেষবার মিলিয়ে দেখা।

## ৭. আজকের lab (২৪ নভেম্বর, ৩টার পরে): ক্রম আর সময়

সব command আছে `LAB-RUNBOOK.md`-এ, আর script গুলো `shoplite-app/scripts/`-এ। নতুন কিছু বানাতে হবে না: দুইবার চলেছে, পরীক্ষা করা।

| সময় (শুরু থেকে) | কাজ | কোথায় | ছবি বা video |
|---|---|---|---|
| ০:০০–০:১০ | Lab চালু, `aws sts get-caller-identity` (না চললে `aws configure`), clone, tools | Runbook ২ | না |
| ০:১০–০:৪৫ | Terraform, Ansible, kubectl | Runbook ৩–৫ | না |
| ০:৪৫–০:৫৫ | GitHub-এর ৫টা variable, main-এর "Run workflow" (~৫ মিনিট) | Runbook ৬ | না |
| ০:৫৫–১:১৫ | Helm, bootstrap (Slack URL চাইবে), promote, prod sync | Q5 procedure ১–৪ | না |
| ১:১৫–১:৪৫ | Q6: dev-এ fault, alert থেকে log থেকে trace | Q6 procedure ৮ | `q6/17`, 🎥 V3 |
| ১:৪৫–২:১০ | Q7: Terraform plan-এর PR, ArgoCD-র sync policy | Q7 procedure ৩, ৪ | `q7/06`, `07`, `09`, `10` |
| ২:১০–৩:৪০ | Q8: load, `chaos-pick.sh`, তদন্ত, revert, recovery, সংখ্যা | Q8 procedure ১–৮ | `q8/01`–`16`, 🎥 V6 |
| ৩:৪০–৪:০০ | শেষের demo recording (section ৯) | — | 🎥 V2, V4, V5, `q7/11` |
| ৪:০০–৪:১৫ | Destroy, `LAB_ACTIVE=false` | Runbook ৯ | `q4/21` লাগবে না (আছে) |

- মোট ~৪ ঘণ্টা ১৫ মিনিট, ৫ ঘণ্টার মধ্যে।
- কোনো ধাপ আটকে গেলে Q8 আর demo recording-কে আগে রাখো। Q6-এর 17 আর Q7-এর 06/07 পরের session-এও নেওয়া যায়।
- Q8 শুরুর সময় অন্তত ১ ঘণ্টা ৪৫ মিনিট বাকি থাকতে হবে।

## ৮. Credential আর setting: নতুন lab-এ কোথায় কী বদলাবে

| কী | কোথায় | কী করবে |
|---|---|---|
| AWS-এর key | Poridhi-র lab page | `aws sts get-caller-identity` না চললে `aws configure`-এ বসাও (region `ap-southeast-1`, output `json`)। কাউকে দেখাবে না, কোনো ফাইলে লিখবে না |
| SSH key | lab terminal | Runbook ২.৪ নিজে বানায় (`~/.ssh/shoplite`) |
| `~/shoplite.env` | lab terminal | Runbook ২.৪: email বসাও; IP (`admin_cidr`) নিজে বের করে |
| `SSH_PUBLIC_KEY`, `ADMIN_CIDR` | GitHub variable | প্রতিবার নতুন মান (Runbook ৬) |
| `AWS_ROLE_ARN`, `AWS_PLAN_ROLE_ARN` | GitHub variable | Account একই (`041793356414`) থাকলে একই মান; তবু Runbook ৬-এর output-এর সাথে মিলিয়ে নাও |
| `LAB_ACTIVE` | GitHub variable | শুরুতে `true`, destroy-এর আগে `false` |
| `GITOPS_DEPLOY_KEY`, `BUDGET_ALERT_EMAIL` | GitHub secret | কিছু না, থেকে যায় |
| Slack webhook URL | Slack-এর app page | Bootstrap চাইলে prompt-এ দাও (`read -rsp`)। ২৪ নভেম্বরেরটা বেরিয়ে গিয়েছিল, তাই আগে নতুন বানাও |
| ArgoCD আর Grafana-র password | cluster-এর ভেতরে | প্রতিবার নতুন। Bootstrap-এর শেষে যে দুই command দেখায়, সেগুলো দিয়ে পড়ো |
| Code | — | কিছু না |

## ৯. Video আর live demo-র পরিকল্পনা

প্রশ্নে video বাধ্যতামূলক না। চাওয়া আছে checkpoint-এর প্রমাণ, আর ১০ মিনিটের **live demo**। Demo-তে দেখাতে হবে:

1. নিজের diagram দিয়ে architecture (`shoplite-app/docs/architecture-diagram.png`);
2. Git push থেকে browser পর্যন্ত একটা code change;
3. Load চলা অবস্থায় Golden Signals dashboard;
4. একটা order-এর পুরো trace, আর trace থেকে তার log;
5. `kubectl edit`-এর পরে ArgoCD-র self-heal।

তাই video হবে মোট চারটা recording-এ:

- **V3** (Q6) আর **V6** (Q8): ঘটনা যখন ঘটে তখনই, ওগুলো আবার ঘটানো কঠিন।
- **শেষের demo recording** (Q8-এর পরে, destroy-এর আগে, ~১৫ মিনিট)। এটাই live demo-র মহড়া আর backup:
  1. Diagram দেখিয়ে architecture বোঝাও (১ মিনিট)।
  2. PC থেকে `<title>` বদলাও, commit করো, `bash publish-repos.sh push`। Actions-এ main চালু হলো দেখাও; ওটা ~৫ মিনিট চলবে, এর মধ্যে বাকিগুলো দেখাও।
  3. k6 চালু রেখে Golden Signals dashboard (২ মিনিট)।
  4. Tempo-তে একটা order-এর trace, তারপর trace থেকে log (২ মিনিট)।
  5. Self-heal: dev-এ `kubectl edit` বা `scale`, তারপর ArgoCD ফিরিয়ে আনে (২ মিনিট)। এটাই V5।
  6. Browser-এ ALB-এর URL-এ নতুন title। এটাই V4, সাথে `q7/11-new-title.png`।
  7. Browser থেকে একটা order দাও, `COMPLETED` পর্যন্ত। এটাই Q5-এর checkpoint, V2।
- **V1** (Q2-এর checkpoint): Q3-এর আলাদা session-এ।
- Instructor-কে জিজ্ঞেস করো: live demo কি চালু lab-এ দেখাতে হবে, নাকি video চলবে? Lab চালু করতে ~১ ঘণ্টা লাগে।

## ১০. RCA (`shoplite-app/docs/RCA.md`): কী লিখতে হবে

খসড়া তৈরি আছে; প্রতিটা `TODO` পূরণ করতে হবে। প্রশ্ন চায় ১–২ পৃষ্ঠা, আর নম্বর দেয় যুক্তি আর প্রমাণের মানের ওপর, কত দ্রুত পেয়েছ তার ওপর না।

| অংশ | কী লিখবে | তথ্য কোথা থেকে |
|---|---|---|
| Summary | ২–৩ বাক্য: customer কী দেখেছে, কতক্ষণ, কারণ, কীভাবে ঠিক হলো | পুরো RCA শেষে লেখো |
| Timeline | প্রতিটা ঘটনার সময় আর তার screenshot | `~/q8-timeline.txt` (`mark`-এর লাইন), Q8-এর ছবি |
| Detection | প্রথম alert কোনটা, কখন; rule-এর expression, threshold আর `for`; কোন মান সীমা পার হলো; কেন দেরিতে এল | Slack-এর ছবি, `monitoring/alert-rules/shoplite-alerts.yaml` |
| Investigation | dashboard → logs → trace: প্রতিটায় কী দেখলে, কী বাদ গেল | Q8-এর 06, 07, 08-এর ছবি |
| Root cause | কোন component, কী আচরণ, কখন থেকে; সব লক্ষণ কেন এতে মেলে | তোমার তদন্ত (diff দেখার আগে) |
| Recovery | revert-এর commit; detect, identify, recover-এর মিনিট | timeline |
| Impact | কত 5xx, সবচেয়ে খারাপ p95, order, queue, restart | Q8 procedure section 8-এর query (`15-impact.png`) |
| Preventive measure | একটা বাস্তব উপায়, আর সেটা কীভাবে এই ঘটনা থামাত বা ছোট করত | নিজের ভাবনা |
| Check against the change | RCA commit করার **পরে**: fault-এর commit পড়ো, root cause মিলেছে কি না লেখো | দ্বিতীয় commit-এ |

- ক্রম: আগে RCA লিখে commit করবে, তারপর diff পড়বে, তারপর শেষের অংশ আলাদা commit-এ। Commit-এর সময়ই প্রমাণ যে আগে লেখা হয়েছে।
- Lab শেষ হলে Claude-কে timeline, ছবি আর section 8-এর সংখ্যা দিলে Claude খসড়া পূরণ করবে, তুমি মিলিয়ে দেখবে।
