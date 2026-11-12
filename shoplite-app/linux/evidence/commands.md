# Question 3: commands and evidence

Server: Ubuntu 24.04 (an EC2 instance in the lab) running the Docker Compose stack from question 2.
Commands marked **server** run on it, from the `shoplite-app` folder of the clone; commands marked
**other machine** run on a second computer (the lab terminal). `SERVER` is the server's IP address.
The screenshot for each part is listed at its end; the files go in this folder.

> **Safety:** keep a second SSH session to the server open the whole time you change SSH or the
> firewall. If the new settings lock you out, undo them from that second session.

## 0.1 Create the server

**other machine**, with AWS credentials, from the `shoplite-app` folder. `terraform/q3-server` creates the
server in a small VPC of its own; the security group lets in only this machine's address, on 22, 80, 443
and the test port 8000. Run `terraform/bootstrap` (the state bucket) first, once per AWS account.

```bash
terraform -chdir=terraform/bootstrap init && terraform -chdir=terraform/bootstrap apply
terraform -chdir=terraform/q3-server init \
  -backend-config="bucket=$(terraform -chdir=terraform/bootstrap output -raw state_bucket)" \
  -backend-config="region=$(terraform -chdir=terraform/bootstrap output -raw region)"
test -f ~/.ssh/id_ed25519 || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''
export TF_VAR_admin_cidr="$(curl -s https://checkip.amazonaws.com)/32"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
terraform -chdir=terraform/q3-server apply
SERVER=$(terraform -chdir=terraform/q3-server output -raw public_ip)
ssh ubuntu@$SERVER
```

## 0.2 Prepare the server and start the stack

This is also question 2's checkpoint on a clean machine.

**server**

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2 make git curl acl
sudo usermod -aG docker "$USER"   # log out and back in once, so the group applies
git clone https://github.com/SaikatGeek/devops-final.git   # until the repositories are split
cd devops-final/shoplite-app
make up && make smoke
```

Screenshot `00-make-up-smoke.png`: the end of `make up` and the `[smoke] PASS` line.

## 3.1 Users and SSH

**other machine**: create the key `deploy` will log in with, then copy the `.pub` file to the server.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/shoplite_deploy -N ''
scp ~/.ssh/shoplite_deploy.pub ubuntu@SERVER:
```

**server**: create the user and the group, and install the key.

```bash
sudo groupadd ops
sudo useradd --create-home --shell /bin/bash --groups ops deploy
sudo install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
sudo install -m 600 -o deploy -g deploy ~/shoplite_deploy.pub /home/deploy/.ssh/authorized_keys
id deploy
getent group ops
```

**server**: install `linux/sshd_config` (no root login, no password login), check it, restart SSH.

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
sudo install -m 644 linux/sshd_config /etc/ssh/sshd_config
sudo sshd -t && sudo systemctl restart ssh
sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication) '
```

`sshd -T` prints the values sshd really uses, after every file in `/etc/ssh/sshd_config.d/`.
Expected: `permitrootlogin no`, `passwordauthentication no`, `kbdinteractiveauthentication no`,
`pubkeyauthentication yes`.

To prove that root is refused because of `PermitRootLogin no` and not because root has no key,
give root the same key for the test and take it away afterwards.

**server**

```bash
sudo cp /root/.ssh/authorized_keys /root/.ssh/authorized_keys.bak
sudo sh -c 'cat ~ubuntu/shoplite_deploy.pub >> /root/.ssh/authorized_keys'
```

**other machine**

```bash
ssh -i ~/.ssh/shoplite_deploy deploy@SERVER id             # works: key login as deploy
ssh -o PubkeyAuthentication=no deploy@SERVER                # refused: Permission denied (publickey)
ssh -i ~/.ssh/shoplite_deploy root@SERVER                   # refused, although the key is valid
```

`Permission denied (publickey)` lists the only method the server accepts; a password is never asked.

**server**

```bash
sudo journalctl -u ssh --since "10 min ago" --no-pager | grep -i 'root login refused'
sudo mv /root/.ssh/authorized_keys.bak /root/.ssh/authorized_keys
```

Screenshots: `01-users.png` (`id`, `getent`), `02-sshd-effective.png` (`sshd -T`),
`03-ssh-refused.png` (the three `ssh` attempts and the `ROOT LOGIN REFUSED` log line).

## 3.2 File permissions

**server**

```bash
sudo mkdir -p /var/log/shoplite
sudo chown root:ops /var/log/shoplite
sudo chmod 2750 /var/log/shoplite
sudo setfacl -d -m g:ops:rx /var/log/shoplite
ls -ld /var/log/shoplite
getfacl /var/log/shoplite
```

- `chown root:ops`: root owns the folder; its group is `ops`.
- `chmod 2750`: owner `rwx`, group `r-x`, others nothing. The `2` (setgid) makes new files belong to `ops` too.
- `setfacl -d -m g:ops:rx`: the one ACL rule, a *default* rule, so files created later are also
  readable by `ops` and by nobody else, whatever the creating program's umask is.

Check with a new file:

```bash
echo "test line" | sudo tee /var/log/shoplite/check.log >/dev/null
ls -l /var/log/shoplite/
sudo -u deploy cat /var/log/shoplite/check.log    # deploy is in ops: prints the line
sudo -u nobody cat /var/log/shoplite/check.log    # not in ops: Permission denied
sudo rm /var/log/shoplite/check.log
```

**Why 777 is wrong:** 777 lets every user on the server read, change and delete the logs and put
files in the folder, so any account (or attacker using one) could read private data or erase the
evidence, while only the `ops` group needs to read them.

Screenshot `04-permissions.png`: `ls -ld`, `getfacl`, and the two `cat` results.

## 3.3 systemd backup service

**server**

```bash
sudo install -m 755 linux/systemd/shoplite-backup.sh /usr/local/bin/shoplite-backup
sudo install -m 644 linux/systemd/shoplite-backup.service linux/systemd/shoplite-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now shoplite-backup.timer
sudo systemctl start shoplite-backup.service      # one backup now, without waiting for the night
systemctl status shoplite-backup.service shoplite-backup.timer --no-pager
systemctl list-timers shoplite-backup.timer --no-pager
sudo sh -c 'ls -l /var/backups/shoplite/; f=$(ls -1t /var/backups/shoplite/*.sql | head -n 1); grep -E "^(CREATE TABLE|COPY)" "$f"'
```

`Restart=on-failure` in action: with Postgres stopped the backup fails, and systemd schedules a retry.

```bash
docker compose stop postgres
sudo systemctl start shoplite-backup.service; systemctl status shoplite-backup.service --no-pager | head -n 5
docker compose start postgres                      # the retry 5 minutes later succeeds
```

Screenshots: `05-backup-status.png` (both `systemctl status`), `06-list-timers.png` (`list-timers`
and the backup files), `07-backup-restart.png` (`activating (auto-restart)` after the failure).

## 3.4 Firewall and ports

**server**

```bash
sudo sh linux/firewall/ufw.sh
sudo ss -tulpn
```

To show a *blocked* port that has a program listening on it, start a temporary listener on port
8000 (in the lab the security group allows 8000 for this test, so only UFW can block it):

```bash
nc -lk 8000 &          # stop it afterwards with: kill %1
sudo ss -tlpn 'sport = :8000'
```

**other machine**

```bash
curl -s -o /dev/null -w 'port 80: HTTP %{http_code}\n' http://SERVER/   # open: HTTP 200
nc -vz -w 5 SERVER 8000                                                   # blocked: timed out
```

Screenshots: `08-ufw-status.png` (`ufw status verbose`), `09-listening-ports.png` (`ss -tulpn`),
`10-port-test.png` (the `curl` and `nc` results from the other machine).

## After grading

**other machine** (cost guard): remove the server, its VPC and its key pair.

```bash
terraform -chdir=terraform/q3-server destroy
```
