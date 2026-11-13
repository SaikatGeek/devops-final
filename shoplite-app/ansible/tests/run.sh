#!/usr/bin/env bash
# Rehearses ansible/site.yml on three local containers that stand in for the EC2 nodes:
#   1. build a node image and the Ansible controller image
#   2. start the "nodes" (cp1, worker1, worker2) on a test network that plays the VPC
#   3. run site.yml twice; the second run must change nothing (idempotency)
#   4. check the result with tests/verify.yml, with real connections through UFW, and in
#      the k3s cluster the playbook built (nodes, system pods, the fetched kubeconfig)
#   5. remove everything again
# Needs only Docker and internet access (k3s binary, system images). About 5 minutes.
# Run it from shoplite-app/: bash ansible/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

export MSYS_NO_PATHCONV=1 # Git Bash on Windows: leave container paths alone
HOST_DIR=$(pwd -W 2>/dev/null || pwd)
NET=shoplite-ansible-test
SUBNET=10.99.0.0/24 # stands in for the VPC
NODES="cp1 worker1 worker2"
KEYS=shoplite-ansible-test-keys # docker volume with the test SSH key
LOGS=$(mktemp -d)

remove_containers() {
  for n in $NODES; do docker rm -f -v "shoplite-test-$n" >/dev/null 2>&1 || true; done
  docker network rm "$NET" >/dev/null 2>&1 || true
  docker volume rm "$KEYS" >/dev/null 2>&1 || true
}
trap 'remove_containers; rm -rf "$LOGS"' EXIT
remove_containers # leftovers of an interrupted earlier run

step() { echo "==> $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

step "building the node and controller images"
docker build -q -t shoplite/ansible-test-node -f ansible/tests/node.Dockerfile ansible/tests >/dev/null
docker build -q -t shoplite/ansible-controller -f ansible/tests/controller.Dockerfile ansible >/dev/null

controller() {
  docker run --rm --network "$NET" -v "$HOST_DIR:/work" -v "$KEYS:/keys" -w /work/ansible \
    -e ANSIBLE_CONFIG=/work/ansible/ansible.cfg -e ANSIBLE_FORCE_COLOR=0 \
    shoplite/ansible-controller "$@"
}

step "starting the nodes on $SUBNET"
docker network create --subnet "$SUBNET" "$NET" >/dev/null
docker volume create "$KEYS" >/dev/null
# containerd's overlayfs snapshotter cannot sit on the container's own overlay filesystem,
# so k3s's data folders are (anonymous) volumes, like in k3s's own container image.
# A private cgroup namespace makes systemd and the kubelet inside see the same cgroup paths
# (Docker's default on cgroup v2 hosts; on cgroup v1 the kubelet fails without it).
for n in $NODES; do
  docker run -d --name "shoplite-test-$n" --hostname "$n" --privileged --cgroupns=private \
    --network "$NET" -v /var/lib/rancher/k3s -v /var/lib/kubelet \
    shoplite/ansible-test-node >/dev/null
done
CP_IP=$(docker inspect -f "{{(index .NetworkSettings.Networks \"$NET\").IPAddress}}" shoplite-test-cp1)
controller ssh-keygen -q -t ed25519 -N '' -f /keys/id_ed25519
PUBKEY=$(controller cat /keys/id_ed25519.pub)
for n in $NODES; do
  for _ in $(seq 30); do
    docker exec "shoplite-test-$n" systemctl is-active --quiet ssh && break
    sleep 1
  done
  echo "$PUBKEY" | docker exec -i "shoplite-test-$n" sh -c \
    'install -d -m 700 -o ubuntu -g ubuntu /home/ubuntu/.ssh &&
     cat > /home/ubuntu/.ssh/authorized_keys &&
     chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys && chmod 600 /home/ubuntu/.ssh/authorized_keys'
done

# The test network plays the VPC; deploy gets the same test key. The kubeconfig goes to the
# keys volume (it must survive between the two runs for the idempotency check) and points
# at cp1 directly, because the test has no SSM port forward.
# Docker Desktop on WSL2's default kernel runs cgroup v1, which Kubernetes 1.35+ refuses
# unless told otherwise; the EC2 nodes run cgroup v2 and need nothing (group_vars).
KUBELET_ARGS='[]'
if [ "$(docker info --format '{{.CgroupVersion}}')" = "1" ]; then
  KUBELET_ARGS='["fail-cgroupv1=false"]'
  echo "note: this Docker host runs cgroup v1; the test nodes' kubelets get fail-cgroupv1=false"
fi
EXTRA=$(printf '{"vpc_cidr": "%s", "hardening_deploy_public_key": "%s", "kubeconfig_dest": "/keys/kubeconfig", "kubeconfig_server": "https://%s:6443", "k3s_kubelet_args": %s}' \
  "$SUBNET" "$PUBKEY" "$CP_IP" "$KUBELET_ARGS")

step "first run of site.yml"
controller ansible-playbook -i tests/inventory.ini site.yml -e "$EXTRA" >"$LOGS/run1.log" 2>&1 ||
  { tail -n 40 "$LOGS/run1.log"; fail "the first run failed"; }
sed -n '/PLAY RECAP/,$p' "$LOGS/run1.log"

step "second run of site.yml (must change nothing)"
controller ansible-playbook -i tests/inventory.ini site.yml -e "$EXTRA" >"$LOGS/run2.log" 2>&1 ||
  { tail -n 40 "$LOGS/run2.log"; fail "the second run failed"; }
sed -n '/PLAY RECAP/,$p' "$LOGS/run2.log"
if grep -E '^(cp1|worker1|worker2) +:' "$LOGS/run2.log" | grep -vq 'changed=0'; then
  grep -B2 -E '^changed:' "$LOGS/run2.log" | head -n 20
  fail "the second run changed something: the playbook is not idempotent"
fi

step "verify.yml"
controller ansible-playbook -i tests/inventory.ini tests/verify.yml -e "$EXTRA" >"$LOGS/verify.log" 2>&1 ||
  { grep -E 'FAILED|Assertion|msg' "$LOGS/verify.log" | head -n 20; fail "verify.yml found a problem"; }
grep -E '^(cp1|worker1|worker2) +:' "$LOGS/verify.log"

step "real connections through UFW (worker1 -> cp1)"
docker exec -d shoplite-test-cp1 nc -lk 7777
sleep 1
# cp1's kubelet listens on 10250.
docker exec shoplite-test-worker1 nc -z -w 3 shoplite-test-cp1 10250 ||
  fail "10250 from inside the VPC should be open"
echo "ok    10250/tcp (kubelet) from inside the VPC reaches cp1"
if docker exec shoplite-test-worker1 nc -z -w 3 shoplite-test-cp1 7777; then
  fail "7777 is not allowed and should be blocked"
fi
echo "ok    7777/tcp (not allowed) is blocked, although cp1 listens on it"

step "deploy logs in with its key; root and passwords are refused"
controller ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i /keys/id_ed25519 deploy@shoplite-test-cp1 id |
  grep -q '(ops)' || fail "deploy could not log in with its key"
echo "ok    deploy logs in with its key and is in ops"
if controller ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i /keys/id_ed25519 root@shoplite-test-cp1 true 2>/dev/null; then
  fail "root could log in"
fi
echo "ok    root is refused"
if controller ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o PubkeyAuthentication=no deploy@shoplite-test-cp1 true 2>/dev/null; then
  fail "a login without a key worked"
fi
echo "ok    a login without a key is refused"

step "the k3s cluster, behind UFW"
kubectl_cp() { docker exec shoplite-test-cp1 k3s kubectl "$@"; }
kubectl_cp get nodes -o wide
kubectl_cp -n kube-system rollout status deployment/coredns --timeout=300s >/dev/null ||
  fail "CoreDNS did not start: pods cannot run or pull images"
echo "ok    CoreDNS runs (pods start, images are pulled)"
# metrics-server (a pod) reads every node's kubelet on 10250: pod network and UFW rules
# across nodes work. The HPA of question 5 needs exactly this.
nodes_with_metrics() { kubectl_cp top nodes --no-headers 2>/dev/null | grep -vc '<unknown>' || true; }
for _ in $(seq 36); do
  [ "$(nodes_with_metrics)" -eq "$(echo $NODES | wc -w)" ] && break
  sleep 5
done
kubectl_cp top nodes || true
[ "$(nodes_with_metrics)" -eq "$(echo $NODES | wc -w)" ] || fail "metrics-server could not read every node"
echo "ok    metrics-server reads CPU and memory of every node"

step "kubelet asks the ECR credential provider for ECR images (worker1)"
# The test has no AWS role, so the plugin cannot get a token and the pull fails; what
# matters is that kubelet runs the plugin for an ECR image name at all.
ECR_IMAGE=123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/shoplite/web:rehearsal
kubectl_cp run ecr-probe --image="$ECR_IMAGE" --restart=Never \
  --overrides='{"apiVersion": "v1", "spec": {"nodeName": "worker1"}}' >/dev/null
provider_ran() {
  docker exec shoplite-test-worker1 journalctl -u k3s-agent --no-pager -o cat |
    grep -i 'credential provider' | grep -F "${ECR_IMAGE%%/*}"
}
for _ in $(seq 24); do provider_ran >/dev/null && break; sleep 5; done
kubectl_cp delete pod ecr-probe --wait=false >/dev/null 2>&1 || true
provider_ran | head -n 1 | cut -c1-240
provider_ran >/dev/null || fail "kubelet did not run the ECR credential provider for an ECR image"
echo "ok    kubelet runs ecr-credential-provider for ECR images (no AWS role here, so it fails as expected)"

step "the fetched kubeconfig works (used from worker1)"
controller cat /keys/kubeconfig | docker exec -i shoplite-test-worker1 sh -c 'cat > /tmp/kubeconfig'
docker exec shoplite-test-worker1 k3s kubectl --kubeconfig /tmp/kubeconfig get nodes --no-headers |
  grep -c ' Ready ' | grep -qx "$(echo $NODES | wc -w)" || fail "the fetched kubeconfig does not reach the cluster"
echo "ok    the kubeconfig from the kubeconfig role reaches the API at $CP_IP:6443"

echo
echo "PASS: hardening and k3s applied, idempotent and verified on $(echo $NODES | wc -w) nodes"
