FROM hashicorp/tfc-agent:1.13.1

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends openssh-client && \
    rm -rf /var/lib/apt/lists/*

COPY start-agent.sh /usr/local/bin/start-agent.sh
RUN chmod +x /usr/local/bin/start-agent.sh

ENTRYPOINT ["/usr/local/bin/terraform-agent-start.sh"]