FROM node:22

# Claude Code CLI
RUN npm i -g @anthropic-ai/claude-code

# Tools utiles pour debug
RUN apt-get update && apt-get install -y postgresql-client curl jq && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# On monte le reste en volume
CMD ["bash"]
