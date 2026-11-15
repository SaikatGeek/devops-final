# shoplite-gitops

Desired state of ShopLite for ArgoCD. GitHub Actions in `shoplite-app` commits image tags here (`scripts/update-gitops.sh`, through a deploy key that can write only to this repository): the main pipeline writes dev's after every build, and the promote workflow copies dev's image to prod. ArgoCD syncs the cluster from this repository. Nothing here is applied with `kubectl apply` from CI.

```text
shoplite-gitops/
├── bootstrap/
│   ├── argocd-values.yaml    ArgoCD's own settings (its Helm chart): /argocd behind Traefik, Git checked every 60 s, Application health for sync waves
│   └── root-app.yaml         the root Application ("app of apps")
├── apps/                     the ArgoCD Applications the root app manages
│   ├── traefik.yaml          the ingress controller behind the ALB (Q5): chart, version, values (sync wave 0)
│   ├── shoplite-dev.yaml     dev, namespace shoplite-dev: automated sync, prune, self-heal (wave 1)
│   └── shoplite-prod.yaml    prod, namespace shoplite: manual sync (wave 1)
└── envs/
    ├── dev/values.yaml       dev's image registry and tag, written by shoplite-app's CI
    └── prod/values.yaml      prod's promoted image, and the Q8 fault-injection flags
```

A new cluster is bootstrapped once with `shoplite-app`'s `scripts/bootstrap-cluster.sh` (from a machine with `kubectl` and `helm`, this repository cloned next to `shoplite-app`). It creates the namespaces and the database Secrets (random passwords, never in Git), installs ArgoCD with `bootstrap/argocd-values.yaml`, and applies `bootstrap/root-app.yaml`. ArgoCD then builds everything else from this repository.

Each ShopLite Application takes the chart from `shoplite-app` (`helm/shoplite`) and layers the values: the chart's `values.yaml`, then `values-<env>.yaml` from `shoplite-app`, then `envs/<env>/values.yaml` from here (ArgoCD multi-source, `ref: gitops`). The `envs` files start empty; until CI writes an image tag the chart stops with `image.tag is required`.
