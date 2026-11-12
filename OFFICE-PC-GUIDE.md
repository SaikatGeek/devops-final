# অন্য PC-তে (অফিসের PC) কাজ চালিয়ে যাওয়ার গাইড

এই গাইড মেনে নতুন PC-তে repo নামাবে, Claude Code খুলবে, আর Claude-কে দিয়ে যেখানে কাজ থেমেছে সেখান থেকে শুরু করাবে।

Claude কী নিয়মে কাজ করবে, সেটা লেখা আছে [CLAUDE.md](CLAUDE.md)-তে। Repo-র root-এ Claude Code খুললে এটা নিজে থেকেই পড়া হয়। কোথায় আছি আর পরের কাজ কী, সেটা আছে [PROGRESS.md](PROGRESS.md)-তে।

## ১. একবারই করতে হবে: যা install লাগবে

| Tool | কেন | যাচাই |
|---|---|---|
| Git | code নামানো আর push | `git --version` |
| Docker Desktop (Windows-এ WSL 2 backend) | সব service আর test Docker-এ চলে | `docker compose version` |
| Claude Code (desktop app বা terminal-এর CLI) | কাজ করানো | https://claude.com/claude-code থেকে install করে নিজের account দিয়ে login |

- Python বা `make` লাগবে না, সব কিছু Docker-এর ভেতরে চলে।
- Docker Desktop চালু আছে কিনা আগে দেখে নিও। না থাকলে `docker` command error দেবে।

## ২. একবারই করতে হবে: GitHub-এ access আর repo নামানো

অফিসের network-এ SSH (port 22) অনেক সময় বন্ধ থাকে, তাই HTTPS আর `gh` দিয়ে login করাই নিরাপদ পথ:

```bash
gh auth login
```

Git for Windows-এর Credential Manager দিয়ে আগে থেকেই login করা থাকলে `gh` লাগবে না। দেখার উপায়: repo-র ভেতরে `git push --dry-run` চালাও; `Everything up-to-date` দেখালে push-এর অনুমতি আছে।

তারপর repo নামাও:

```bash
git clone https://github.com/SaikatGeek/devops-final.git
```

Commit-এ তোমার নাম যাতে আসে:

```bash
git config --global user.name "SaikatGeek"
```

```bash
git config --global user.email "<GitHub-এ যে email দেওয়া>"
```

> **সতর্কতা:** অফিসের PC অন্য কেউ ব্যবহার করলে কাজ শেষে `gh auth logout` চালিয়ে GitHub থেকে logout করো। কোনো password বা token কোনো ফাইলে লিখে রেখো না।

## ৩. একবারই করতে হবে: stack চালিয়ে দেখা

```bash
cd devops-final/shoplite-app
```

```bash
cp .env.example .env
```

এই PC-তে port 80 অন্য কোনো program (যেমন Apache) ধরে থাকলে `.env`-এ `WEB_PORT=80`-এর জায়গায় লেখো `WEB_PORT=127.0.0.1:8088`। তাহলে page শুধু এই PC থেকে, port 8088-এ খোলা যাবে।

```bash
docker compose up -d --build --wait
```

তারপর browser-এ page খোলো: http://localhost (WEB_PORT 80 হলে) অথবা http://127.0.0.1:8088। Product-এর তালিকা দেখা গেলে সব ঠিক আছে। পুরো পথটা (page → API → database → queue → worker) একবারে যাচাই করতে চাইলে:

```bash
sh scripts/smoke-test.sh
```

শেষে `[smoke] PASS` দেখা গেলে সব ঠিক।

`.env` Git-এ থাকে না, তাই প্রতিটা নতুন PC-তে এটা আবার বানাতে হয়। Database-এর data-ও PC থেকে PC-তে যায় না; নতুন PC-তে Postgres প্রথমবার চালু হলে ১২টা product নিজে থেকেই বসে যায়।

## ৪. প্রতিবার কাজ শুরুর আগে

```bash
cd devops-final
```

```bash
git pull
```

অন্য PC-তে যা push করা হয়েছে, এতে এখানে চলে আসে। তারপর `devops-final` folder-এ Claude Code খোলো, ভেতরের কোনো sub-folder-এ না। নইলে `CLAUDE.md` পড়া হবে না।

## ৫. Claude-কে কী বলবে

**নতুন PC-তে প্রথমবার:**

```text
CLAUDE.md আর PROGRESS.md পড়ো। তারপর বলো এখন কোথায় আছি আর পরের step কী। আমি হ্যাঁ বললে সেই step শুরু করবে।
```

**পরের step শুরু করাতে:**

```text
Q4 শুরু করো
```

**এক step শেষ হলে Claude নিজেই যা করবে (CLAUDE.md-তে লেখা আছে):**

1. Test চালাবে।
2. আসল stack চালিয়ে যাচাই করবে।
3. `PROGRESS.md` আপডেট করবে।
4. Commit করে `main`-এ push করবে।
5. নতুন কী বানাল, বুঝিয়ে বলবে।

কোনোটা বাদ পড়লে বলো: `PROGRESS.md আপডেট করে commit আর push করো`।

**কোনো কিছু না বুঝলে:**

```text
Step 6-এ trace কীভাবে API থেকে worker-এ যায়, সহজ করে বুঝিয়ে বলো
```

## ৬. প্রতিবার কাজ শেষের আগে

Claude-কে দিয়ে push করিয়েছ কিনা নিশ্চিত হও:

```bash
git status
```

`nothing to commit, working tree clean` দেখালে সব push হয়েছে। না দেখালে Claude-কে বলো commit আর push করতে। Push না করা কাজ অন্য PC-তে যাবে না।

Docker-এর container বন্ধ করতে চাইলে (data থেকে যায়), `shoplite-app` folder থেকে:

```bash
docker compose down
```

## ৭. বাকি কাজের ক্রম (বিস্তারিত PROGRESS.md-তে)

মূল নিয়ম: প্রশ্নে (`project.md`) যা চাওয়া, শুধু সেটুকুই বানানো হবে।

| ক্রম | কাজ | কোথায় |
|---|---|---|
| ✅ | Q1: application, ৯টা step | হয়ে গেছে |
| ✅ | Q2: Dockerfile, compose, smoke test, Makefile (`6c68826`) | হয়ে গেছে |
| ✅ | Q3-এর code: `linux/` folder (`3019a9a`), local-এ রিহার্সাল করা | হয়ে গেছে |
| 🟡 | Q4: step 4.1 (state bucket, backend lock, tag, budget, `d690cb5`), 4.2 (network, `6733b56`) আর 4.3 (compute, `bd07fcf`) শেষ; পরের step 4.4 `alb` module | যেকোনো PC, Docker |
| 1 | Q4-এর বাকি step, তারপর Q5 থেকে Q7-এর code (Helm, monitoring, workflow) | যেকোনো PC |
| 2 | Q3 থেকে Q8 চালানো আর প্রমাণ (Q3: `linux/evidence/commands.md` ধরে) | Poridhi AWS lab (PLAN.md section 4, 5, 6) |

## ৮. সমস্যা হলে

| লক্ষণ | কী করবে |
|---|---|
| `docker` command কাজ করে না | Docker Desktop চালু করো, পুরো চালু হওয়া পর্যন্ত অপেক্ষা করো |
| `set POSTGRES_PASSWORD in .env` error | `shoplite-app`-এ `cp .env.example .env` চালাও |
| Port 80 আগে থেকেই ব্যবহৃত (`ports are not available`) | `.env`-এ `WEB_PORT=127.0.0.1:8088` লেখো, তারপর আবার `docker compose up -d --wait` |
| `git push` প্রত্যাখ্যাত | আগে `git pull`, তারপর আবার push |
| অফিসের network-এ Docker image নামে না | Proxy-র ব্যাপার; IT-কে জিজ্ঞেস করো, অথবা বাসার PC-তে কাজ করো |
