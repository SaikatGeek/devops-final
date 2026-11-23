# Question 7: commands and evidence

GitHub Actions builds and publishes; ArgoCD deploys from Git. No workflow runs `kubectl` or
holds a cluster credential. The workflows are in `.github/workflows/`:

- `main.yml` (7a) runs on every push to main:
  - lint (Hadolint, `helm lint`), unit tests, the build tagged with the short SHA, and the
    Trivy scan (`scripts/ci.sh`);
  - then the push to ECR through OIDC, and the new tag committed to shoplite-gitops.
- `pr.yml` (7b) runs the same checks on every pull request, with no AWS access.
- `terraform-plan.yml` (7b) runs for a pull request that changes `terraform/`. It posts the
  Terraform plan as a comment, using a read-only role.
- `promote.yml` puts dev's image into prod's values in shoplite-gitops.

ArgoCD's Applications are in `shoplite-gitops/apps/`. Dev syncs automatically, with self-heal;
prod syncs by hand.

Most evidence is taken in GitHub and ArgoCD, in the browser. The terminal steps run in the
**lab terminal**, from `shoplite-app`, unless a step says otherwise. Screenshots are listed at
the end of each part; the files go in this folder.

> **Cost:** this builds on questions 4 and 5, in the same session. End it with
> [After the session](#after-the-session).

**Before you start:** question 5's procedure ([`../q5/commands.md`](../q5/commands.md)) up to
its section 4, in this session. By then:

- main's run has pushed the images;
- the cluster is bootstrapped;
- prod is promoted and synced.

## 0. Settings for the pull-request plan

In **shoplite-app** → Settings → Secrets and variables → Actions:

- **Once:** the secret `BUDGET_ALERT_EMAIL`, the same address as `TF_VAR_budget_alert_email`
  in question 4.
- **Every session**, because the lab machine and its key are new:
  - the variable `SSH_PUBLIC_KEY`, the line that `cat ~/.ssh/shoplite.pub` prints;
  - the variable `ADMIN_CIDR`, the value of `echo $TF_VAR_admin_cidr` (the bastion's
    allowed source, so the plan shows no change there);
  - the variable `AWS_PLAN_ROLE_ARN`, from:

    ```bash
    terraform -chdir=terraform output -raw ci_plan_role_arn; echo
    ```

The plan role can only read: AWS's ReadOnlyAccess. Only pull-request runs of shoplite-app
can take it. The CI role that pushes images trusts only main.

## 1. 7a: the main pipeline

1. Open the run from question 5's section 2 (**shoplite-app** → Actions → main). Every step
   is green, in this order:
   1. lint;
   2. unit tests;
   3. build;
   4. Trivy scan;
   5. AWS credentials through OIDC;
   6. ECR login;
   7. push;
   8. the tag committed to shoplite-gitops.

   The pipeline has no AWS key; the OIDC step shows the role it took.
2. The images in ECR carry main's short SHA:

   ```bash
   git ls-remote https://github.com/SaikatGeek/shoplite-app.git refs/heads/main | cut -c1-7
   aws ecr describe-images --repository-name shoplite/web --query 'imageDetails[].imageTags' --output text
   ```

3. **shoplite-gitops** → Commits: `dev: images <sha>` by `github-actions[bot]`. Its message
   links the run and the source commit.

Screenshots:
- `01-main-run.png`: the run with its steps.
- `02-ecr-sha-tags.png`: the terminal, the SHA and the tags.
- `03-gitops-ci-commit.png`: CI's commit in shoplite-gitops.

## 2. 7a: the Trivy gate stops a vulnerable image

Make the scan meet a CRITICAL vulnerability. Web's base image ships brotli-libs with
CVE-2026-111497, and web's Dockerfile installs the fixed version. A pull request without the
fix runs the same `scripts/ci.sh scan` as main:

1. **shoplite-app** → `services/web/Dockerfile` → Edit. Delete the two lines under the
   brotli comment (`USER 0` and `RUN apk add --no-cache brotli-libs=...`).
2. Commit to a new branch `trivy-red` and create the pull request.
3. The `pr` check fails at "Scan the images with Trivy": `CRITICAL vulnerabilities in: web`.
   The scan lists CVE-2026-111497. In main the same stage runs before any push, so such an
   image never reaches ECR.
4. Close the pull request without merging, and delete the branch.

If the base image has been rebuilt with the fix by then, use an older base image instead:
change `NGINX_IMAGE` at the top of the Dockerfile to one from 2024.

Screenshot `04-trivy-red.png`: the failed step with the CVE.

## 3. 7b: the pull-request pipeline and the Terraform plan

1. **A plain pull request.** Change any line in shoplite-app, for example add a word to this
   file, on a new branch `pr-check`, and create the pull request. The check
   `pr / lint, test, build, scan` runs and turns green. Close the pull request without
   merging.
2. **A Terraform change.** In `terraform/main.tf`, change the budget's `limit_amount = "20"`
   to `"25"`, on a new branch `terraform-plan-check`, and create the pull request.
   - Two checks run: `pr` and `terraform-plan`.
   - A comment appears: **Plan: 0 to add, 1 to change, 0 to destroy.** The plan in it shows
     `aws_budgets_budget.monthly` with `limit_amount` going from 20 to 25.

   Nothing changes in AWS: the plan role can only read, and the pull request is never
   merged. Close it and delete the branch.

The pull requests are never merged: shoplite-app's main only moves when devops-final is split
again (question 5's section 0.1). The branches never affect it.

Screenshots:
- `05-pr-checks.png`: the plain pull request's green check.
- `06-terraform-plan-comment.png`: the plan comment.
- `07-terraform-pr-checks.png`: the Terraform pull request's checks.

## 4. 7c: one Application per environment

```bash
kubectl -n argocd get applications shoplite-dev shoplite-prod \
  -o custom-columns='NAME:.metadata.name,NAMESPACE:.spec.destination.namespace,AUTOMATED:.spec.syncPolicy.automated,SYNC:.status.sync.status,HEALTH:.status.health.status'
```

Dev is automated, with `prune` and `selfHeal`; prod has no automated sync (`<none>`). In ArgoCD
(`$ALB/argocd/`), open each Application's **Details**, **Sync Policy**:

- `shoplite-dev`: automated, prune, self heal;
- `shoplite-prod`: manual.

Their definitions are `apps/shoplite-dev.yaml` and `apps/shoplite-prod.yaml` in
shoplite-gitops.

Screenshots:
- `08-argocd-apps.png`: the terminal, and ArgoCD's list of Applications.
- `09-dev-sync-policy.png`: dev's sync policy.
- `10-prod-sync-policy.png`: prod's sync policy.

## 5. 7d: self-healing, video V5

Record the terminal and ArgoCD side by side. Edit dev's web Deployment by hand: change
`replicas: 2` to `replicas: 5` and save.

```bash
kubectl -n shoplite-dev get deployment web
KUBE_EDITOR=nano kubectl -n shoplite-dev edit deployment web
kubectl -n shoplite-dev get deployment web -w
```

Within a minute, ArgoCD sees the difference from Git and syncs dev back to 2 replicas. Its
Application shows the self-heal sync. Ctrl+C ends `-w`.

Video `V5-self-heal.mp4`.

## 6. Checkpoint: a title change reaches the browser, video V4

On your own PC, in the `devops-final` clone that can push (as in question 5's section 0.1),
record from the commit to the browser.

1. Change the page title in `shoplite-app/services/web/public/index.html`, for example from
   `<title>ShopLite</title>` to `<title>ShopLite - Q7 checkpoint</title>`. Commit it on main,
   and push devops-final.
2. Publish it to shoplite-app, from devops-final's root. The split is deterministic, so this
   push is a fast-forward:

   ```bash
   bash publish-repos.sh push
   ```

3. Watch it go, with no deployment command:
   - the main pipeline runs (about 5 minutes);
   - CI commits the new tag to shoplite-gitops;
   - ArgoCD syncs dev, and web's pods roll.

   Reload `$ALB:8080`: the tab shows the new title. The page is served with
   `Cache-Control: no-cache`.
4. For prod: promote's "Run workflow", then SYNC `shoplite-prod` in ArgoCD (question 5's
   section 4); then reload `$ALB`.

Video `V4-title-change.mp4`, and screenshot `11-new-title.png`: the browser with the new title.

## After the session

Close any pull request still open, and delete its branch. Then end the session as question 5's
procedure does: `LAB_ACTIVE=false`, then question 4's destroy.
