#!/usr/bin/env bash
# Rehearses ansible/site.yml on three local containers that stand in for the EC2 nodes:
#   1. build a node image and the Ansible controller image
#   2. start the "nodes" (cp1, worker1, worker2) on a test network that plays the VPC
#   3. run site.yml twice; the second run must change nothing (idempotency)
#   4. check the result with tests/verify.yml and with real connections through UFW
#   5. remove everything again
# Needs only Docker. Run it from shoplite-app/: bash ansible/tests/run.sh
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
  for n in $NODES; do docker rm -f "shoplite-test-$n" >/dev/null 2>&1 || true; done
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
for n in $NODES; do
  docker run -d --name "shoplite-test-$n" --hostname "$n" --privileged --network "$NET" \
    shoplite/ansible-test-node >/dev/null
done
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

# The test network plays the VPC; deploy gets the same test key.
EXTRA=$(printf '{"vpc_cidr": "%s", "hardening_deploy_public_key": "%s"}' "$SUBNET" "$PUBKEY")

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
docker exec -d shoplite-test-cp1 nc -lk 10250
sleep 1
docker exec shoplite-test-worker1 nc -z -w 3 shoplite-test-cp1 10250 ||
  fail "10250 from inside the VPC should be open"
echo "ok    10250/tcp from inside the VPC reaches cp1"
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

echo
echo "PASS: hardening applied, idempotent and verified on $(echo $NODES | wc -w) nodes"
