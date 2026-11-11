# shoplite-gitops

Desired state of ShopLite for ArgoCD. GitHub Actions in `shoplite-app` commits new image tags here; ArgoCD syncs the cluster from this repository. Nothing here is applied with `kubectl apply` from CI.

Planned layout (filled in during Q5 and Q7):

```text
shoplite-gitops/
├── bootstrap/root-app.yaml   app of apps
├── apps/                     ArgoCD Applications (dev auto-sync, prod manual sync)
└── envs/
    ├── dev/values.yaml       image registry and tag, written by CI
    └── prod/values.yaml      image tag and chaos flags (Q8)
```
