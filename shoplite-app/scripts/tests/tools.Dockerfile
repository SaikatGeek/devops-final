# Test only: what the lab machine needs for scripts/bootstrap-cluster.sh: bash, kubectl
# (the cluster's version, from the k3s binary) and helm.
FROM rancher/k3s:v1.37.2-k3s1 AS k3s

FROM alpine/helm:4.3.1
RUN apk add --no-cache bash
COPY --from=k3s /bin/k3s /usr/local/bin/k3s
RUN ln -s k3s /usr/local/bin/kubectl
ENTRYPOINT []
