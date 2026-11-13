# Test only: a Kubernetes node as Ansible sees it, like the EC2 nodes: Ubuntu 24.04 with
# systemd, sshd, python3, CA certificates (HTTPS downloads) and an `ubuntu` user with
# passwordless sudo. Run it with --privileged so systemd, UFW and k3s work inside it.
FROM ubuntu:24.04
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      systemd systemd-sysv openssh-server python3 sudo ufw acl iproute2 netcat-openbsd \
      ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-ubuntu \
 && systemctl enable ssh.service
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
