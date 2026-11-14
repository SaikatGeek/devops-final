# Test only: a Git server over smart HTTP (git http-backend behind nginx), so ArgoCD in the
# local rehearsal (scripts/tests/bootstrap-cluster.sh) reads the two repositories the way
# it reads GitHub. Repositories: bare repos in /srv/git (<name>.git), which the rehearsal
# creates inside the running container.
FROM alpine:3.22
RUN apk add --no-cache nginx fcgiwrap spawn-fcgi git git-daemon \
 && git config --system --add safe.directory '*' \
 && mkdir -p /run/nginx /srv/git
COPY gitserver-nginx.conf /etc/nginx/http.d/default.conf
# git http-backend runs as nginx, so it gets nginx's home (root's would only give warnings).
CMD ["sh", "-c", "HOME=/var/lib/nginx spawn-fcgi -s /run/fcgiwrap.sock -u nginx -U nginx -- /usr/bin/fcgiwrap && exec nginx -g 'daemon off;'"]
