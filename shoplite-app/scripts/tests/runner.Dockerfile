# Test only: what the pipeline's shell steps find on GitHub's ubuntu-24.04 runner (bash, git
# and yq 4), for the pipeline rehearsal (scripts/tests/pipeline.sh).
FROM mikefarah/yq:4.54.1
USER root
RUN apk add --no-cache bash git
ENTRYPOINT []
