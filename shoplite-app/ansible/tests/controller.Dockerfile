# Test only: the Ansible controller, with the same pinned versions as the lab.
# Build context: the ansible/ folder (docker build -f ansible/tests/controller.Dockerfile ansible).
FROM python:3.12-alpine
RUN apk add --no-cache openssh-client
COPY requirements.txt requirements.yml /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements.txt \
 && ansible-galaxy collection install -r /tmp/requirements.yml -p /usr/share/ansible/collections
