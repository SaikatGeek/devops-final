#!/bin/sh
# Firewall of the ShopLite server (question 3.4), with UFW: incoming traffic is denied by
# default and only SSH (22), HTTP (80) and HTTPS (443) may come in.
# Run as root from the shoplite-app folder: sudo sh linux/firewall/ufw.sh
# Keep a second SSH session open while running it, so a mistake cannot lock you out.
#
# Docker publishes container ports with its own iptables rules, which UFW does not see.
# That is why docker-compose.yml publishes only web (port 80): nothing else in the stack
# can be reached from outside.
set -eu

ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   # SSH; allowed before enabling, so the open session stays up
ufw allow 80/tcp   # HTTP: the ShopLite page
ufw allow 443/tcp  # HTTPS
ufw --force enable # --force skips the "may disrupt existing ssh connections" prompt
ufw status verbose
