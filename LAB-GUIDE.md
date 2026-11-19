# Lab-এর গাইড: GitHub-এর setting আর lab session, বাসার PC থেকে

এই ফাইলে আছে কাজের ক্রম আর checklist। প্রতিটা command-এর আসল উৎস English পদ্ধতিগুলো:

- Q4: `shoplite-app/docs/evidence/q4/commands.md`
- Q5: `shoplite-app/docs/evidence/q5/commands.md`
- Q6: `shoplite-app/docs/evidence/q6/commands.md`
- Q7: `shoplite-app/docs/evidence/q7/commands.md`
- Q8: `shoplite-app/docs/evidence/q8/commands.md`
- Q3: `shoplite-app/linux/evidence/commands.md`

GitHub-এও খোলা যায়: https://github.com/SaikatGeek/shoplite-app/tree/main/docs/evidence

## ১. বাসায় পৌঁছে (lab-এর আগে)

1. Docker Desktop চালু করো। Lab-এর কাজে এটা লাগে না, তবে Claude-এর local কাজে লাগে।
2. `E:\Personal\devops-final`-এ Git Bash খুলে নতুন কাজ নামাও:

   ```bash
   git pull
   ```

3. ওই folder-এ Claude Code খোলো আর বলো:

   ```text
   CLAUDE.md, PROGRESS.md আর LAB-GUIDE.md পড়ো। আজ lab-এর দিন, local stack বা smoke test লাগবে না। LAB-GUIDE-এর section ২ (GitHub-এর setting) থেকে ধাপে ধাপে করাও; lab-এ কোনো ধাপে আটকালে সাহায্য করবে।
   ```

   Lab চলার সময় কোনো error এলে পুরো error-টা এই Claude-কে paste করো।
4. Screen recorder ঠিক করো: OBS Studio, অথবা Windows-এর Xbox Game Bar (Win+Alt+R)। পুরো session record হবে, ভিডিওগুলো (V1–V6) পরে কাটা হবে।
5. Screenshot সরাসরি ঠিক folder-এ, পদ্ধতিতে দেওয়া নামে রাখো। তাহলে পরে শুধু commit করলেই হয়:
   - `E:\Personal\devops-final\shoplite-app\docs\evidence\q4\` থেকে `q8\`;
   - Q3-এর গুলো `E:\Personal\devops-final\shoplite-app\linux\evidence\`-এ।

   Win+Shift+S দিয়ে অংশ বাছো, Snipping Tool-এ save করো।

## ২. GitHub-এর setting (একবারই)

### ২.১ Deploy key: CI যেন shoplite-gitops-এ লিখতে পারে

Git Bash-এ, repo-র বাইরে (home folder-এ), যাতে key-এর ফাইল কখনো commit না হয়:

```bash
cd ~
ssh-keygen -t ed25519 -N '' -C shoplite-app-ci -f shoplite-gitops-deploy
```

1. Public key clipboard-এ নাও:

   ```bash
   clip < ~/shoplite-gitops-deploy.pub
   ```

   https://github.com/SaikatGeek/shoplite-gitops/settings/keys → **Add deploy key**:
   - Title: `shoplite-app CI`
   - Key: paste করো
   - ✅ **Allow write access**
   - **Add key**
2. Private key clipboard-এ নাও:

   ```bash
   clip < ~/shoplite-gitops-deploy
   ```

   https://github.com/SaikatGeek/shoplite-app/settings/secrets/actions → **New repository secret**:
   - Name: `GITOPS_DEPLOY_KEY`
   - Secret: paste করো। পুরোটা, `-----BEGIN OPENSSH PRIVATE KEY-----` থেকে `-----END OPENSSH PRIVATE KEY-----` পর্যন্ত।
   - **Add secret**
3. দুইটা ফাইল মুছে দাও। Private key এখন শুধু GitHub-এর secret-এ থাকে:

   ```bash
   rm ~/shoplite-gitops-deploy ~/shoplite-gitops-deploy.pub
   ```

### ২.২ Budget-এর e-mail

একই page-এ আবার **New repository secret**:

- Name: `BUDGET_ALERT_EMAIL`
- Secret: তোমার e-mail। Lab-এ `TF_VAR_budget_alert_email`-এও এটাই দেবে।

### ২.৩ Slack-এর incoming webhook (Q6-এর alert)

1. https://api.slack.com/apps → **Create New App** → **From scratch**।
2. নাম দাও `ShopLite alerts`, workspace বাছো → **Create App**।
3. **Incoming Webhooks** → On → **Add New Webhook** (বা "to Workspace") → একটা channel বাছো, যেমন `#shoplite-alerts` → **Allow**।
4. URL-টা (`https://hooks.slack.com/services/...`) copy করে password-এর মতো রাখো। Git-এ বা কোনো ফাইলে নয়। Q5-এর bootstrap এটা চাইবে।

### ২.৪ Region (শুধু দরকার হলে)

Lab-এর region `ap-southeast-1` না হলে: https://github.com/SaikatGeek/shoplite-app/settings/variables/actions → **New repository variable**, `AWS_REGION` = lab-এর region।

### ২.৫ যাচাই আর screenshot

https://github.com/SaikatGeek/shoplite-app/settings/secrets/actions-এ দুইটা secret দেখা যাবে: `BUDGET_ALERT_EMAIL` আর `GITOPS_DEPLOY_KEY`। GitHub কখনো মান দেখায় না।

Screenshot `01-github-settings.png` → `shoplite-app\docs\evidence\q5\`। তাতে থাকবে write access-সহ deploy key, আর secret-এর তালিকা।

## ৩. Q8-এর peer (আগেই ঠিক করো)

- একজন, যার GitHub account আছে, আর session শুরুর প্রায় ৩ ঘণ্টা পরে ১৫ মিনিট সময় দিতে পারবে।
- তার GitHub username জেনে রাখো।
- তাকে আগেই এই link পাঠাও: https://github.com/SaikatGeek/shoplite-app/blob/main/docs/evidence/q8/commands.md#the-peers-part

## ৪. Lab session: ক্রম আর সময়

Lab-এর timer ৪ ঘণ্টা ৫৯ মিনিট। Q4 থেকে Q8 এক session-এ প্রায় ৪–৪.৫ ঘণ্টা। Q3 আরেকটা ছোট session-এ।

| ক্রম | কাজ | কোথায় | সময় |
|---|---|---|---|
| ০ | Recording চালু, lab চালু, AWS credential, lab terminal | নিচের "lab terminal" | ৫ মিনিট |
| ১ | Q4: clone, tool, Terraform, Ansible, kubectl, প্রমাণ | Q4-এর পদ্ধতি 0.1 → 4 | ~৪৫ মিনিট |
| ২ | এই session-এর GitHub variable | এই ফাইলের section ৫ | ৩ মিনিট |
| ৩ | Q5: main-এর Run workflow, bootstrap, promote, prod sync, প্রমাণ | Q5-এর পদ্ধতি 1 → 6 | ~৪০ মিনিট |
| ৪ | Q6: k6, Grafana, প্রমাণ, ভিডিও V3 | Q6-এর পদ্ধতি 0 → 8 | ~৫০ মিনিট |
| ৫ | Q7: pipeline, Trivy-র লাল PR, PR, ArgoCD, self-heal (V5), title (V4) | Q7-এর পদ্ধতি 0 → 6 | ~৩৫ মিনিট |
| ৬ | Q8: peer-এর সাথে chaos, তদন্ত, revert, recovery, RCA-র সংখ্যা | Q8-এর পদ্ধতি 1 → 8 | ~৮০ মিনিট |
| ৭ | শেষ: `LAB_ACTIVE=false`, তারপর destroy | এই ফাইলের section ৭ | ১০ মিনিট |

Q8 শুরুর সময় অন্তত ১ ঘণ্টা ৪৫ মিনিট হাতে রাখো। কম থাকলে Q8 পরের session-এ করো।

**Lab terminal:** Poridhi lab-এর Ubuntu terminal, যেখানে AWS-এর credential আছে। পদ্ধতিগুলো এটাই ধরে লেখা।

যদি lab শুধু credential দেয় (access key, secret, session token), terminal না দেয়, তাহলে বাসার PC-র WSL Ubuntu-কে lab terminal বানাও:

- না থাকলে PowerShell (Administrator)-এ `wsl --install -d Ubuntu-24.04`;
- তারপর তার ভেতরে credential export করো:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_SESSION_TOKEN`, যদি দেয়

## ৫. প্রতি session-এর GitHub variable (Q4-এর apply-এর পরে)

Lab terminal-এ, `shoplite-app` থেকে:

```bash
terraform -chdir=terraform output -raw ci_role_arn; echo
terraform -chdir=terraform output -raw ci_plan_role_arn; echo
cat ~/.ssh/shoplite.pub
```

https://github.com/SaikatGeek/shoplite-app/settings/variables/actions → **New repository variable**। আগে থেকে থাকলে তার পাশের ✏️ দিয়ে বদলাও।

| Variable | মান |
|---|---|
| `AWS_ROLE_ARN` | প্রথম লাইন |
| `AWS_PLAN_ROLE_ARN` | দ্বিতীয় লাইন |
| `SSH_PUBLIC_KEY` | তৃতীয় লাইন, পুরোটা |
| `LAB_ACTIVE` | `true` |

এরপর Q5-এর পদ্ধতির section 2 থেকে চালাও: Actions → main → **Run workflow**।

## ৬. Lab-এর মধ্যে বাসার PC-তে যা করবে

- **Browser:**
  - GitHub: variable, Run workflow, PR (web editor-এ), Q8-এর collaborator;
  - ArgoCD `$ALB/argocd/`, Grafana `$ALB/grafana/`;
  - app: prod `$ALB`, dev `$ALB:8080`;
  - Slack।
- **Q7-এর title checkpoint (V4)**, Git Bash-এ `E:\Personal\devops-final` থেকে:
  1. `shoplite-app/services/web/public/index.html`-এ `<title>` বদলাও;
  2. commit করো, তারপর `git push`;
  3. `bash publish-repos.sh push` চালাও (Q7-এর পদ্ধতির section 6)।

  চাইলে Claude-কে বলো এটা করে দিতে।
- **Q8-এর revert**, Git Bash-এ, devops-final-এর বাইরে (যেমন `cd ~`): Q8-এর পদ্ধতির section 6-এর command (`git clone ... q8-gitops`, `git revert`, `git push`)।
- **Q8 চলার সময়** (section 3 থেকে 7) shoplite-app-এ কিছু push করবে না, কোনো workflow চালাবে না।

## ৭. Session শেষের আগে: destroy-এর আগে না নিলে হারাবে

1. Q8-এর section 8: ৭টা query-র screenshot, আর `cat ~/q8-timeline.txt`-এর লেখা copy করে বাসার PC-তে কোনো ফাইলে রাখো।
2. সব screenshot ঠিক folder-এ আছে কিনা মিলিয়ে নাও; recording থামিয়ে save করো।
3. `LAB_ACTIVE` = `false` (section ৫-এর page)।
4. Lab terminal-এ, `shoplite-app` থেকে (Q4-এর পদ্ধতির "After grading"):

   ```bash
   terraform -chdir=terraform destroy
   terraform -chdir=terraform/bootstrap destroy
   ```

   Screenshot `21-destroy.png` → `docs\evidence\q4\`।

এই session-এ Q3 করলে, এর আগে তার server destroy করো: `terraform -chdir=terraform/q3-server destroy`।

## ৮. Q3: আলাদা ছোট session (প্রায় ৪০ মিনিট)

Q3-এর পদ্ধতি (`shoplite-app/linux/evidence/commands.md`) ধরে চলো:

1. 0.1: bootstrap আর `terraform/q3-server` দিয়ে server বানানো;
2. 0.2: server-এ `make up && make smoke`। এটা Q2-এর পরিষ্কার machine-এর checkpoint; ভিডিও V1;
3. 3.1 থেকে 3.4;
4. শেষে "After grading"।

Lab terminal আর Q4-এর মতোই; শুধু tool-গুলোর মধ্যে Terraform লাগে।

## ৯. Lab-এর পরে (বাসার PC, Claude-এর সাথে)

1. Claude-কে বলো screenshot-গুলো মিলিয়ে commit আর publish করতে।
2. RCA (`shoplite-app/docs/RCA.md`):
   1. timeline, screenshot আর সংখ্যা দিয়ে লেখা হবে, তারপর commit;
   2. তারপরই শুধু peer-এর commit-এর diff দেখা হবে, আর মেলানোর ফল যাবে আলাদা commit-এ।
3. Recording থেকে ভিডিও কাটা: V1 (Q2/Q3), V2 (Q5-এর checkpoint), V3 (Q6), V4 (Q7-এর title), V5 (self-heal), V6 (Q8)।
