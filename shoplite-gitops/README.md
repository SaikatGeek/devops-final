# shoplite-gitops

Desired state of ShopLite for ArgoCD. GitHub Actions in `shoplite-app` commits new image tags here; ArgoCD syncs the cluster from this repository. Nothing here is applied with `kubectl apply` from CI.

```text
shoplite-gitops/
├── bootstrap/root-app.yaml   the root Application ("app of apps"); applied once when the cluster is built
├── apps/                     the ArgoCD Applications the root app manages
│   ├── traefik.yaml          the ingress controller behind the ALB (Q5): chart, version, values (sync wave 0)
│   ├── shoplite-dev.yaml     dev, namespace shoplite-dev: automated sync, prune, self-heal (wave 1)
│   └── shoplite-prod.yaml    prod, namespace shoplite: manual sync (wave 1)
└── envs/
    ├── dev/values.yaml       dev's image registry and tag, written by shoplite-app's CI
    └── prod/values.yaml      prod's promoted image, and the Q8 fault-injection flags
```

Each ShopLite Application takes the chart from `shoplite-app` (`helm/shoplite`) and layers the values: the chart's `values.yaml`, then `values-<env>.yaml` from `shoplite-app`, then `envs/<env>/values.yaml` from here (ArgoCD multi-source, `ref: gitops`). The `envs` files start empty; until CI writes an image tag the chart stops with `image.tag is required`.
