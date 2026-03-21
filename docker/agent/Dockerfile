FROM node:22

# Claude Code CLI
RUN npm i -g @anthropic-ai/claude-code

# Tools utiles pour debug
RUN apt-get update && apt-get install -y postgresql-client curl jq && rm -rf /var/lib/apt/lists/*

# Non-root user (Claude Code refuses --dangerously-skip-permissions as root)
RUN useradd -m -s /bin/bash agent

# Pre-configure Claude: skip ALL interactive prompts
# - hasCompletedOnboarding: skip theme wizard
# - bypassPermissionsAccepted: skip "Yes, I accept" confirmation
# - hasTrustDialogAccepted: skip "trust this folder?" prompt
RUN mkdir -p /home/agent/.claude && \
    printf '%s\n' '{"hasCompletedOnboarding":true,"lastOnboardingVersion":"2.1.81","bypassPermissionsAccepted":true,"projects":{"/home/agent/workspace":{"hasTrustDialogAccepted":true,"allowedTools":[],"mcpServers":{}}}}' > /home/agent/.claude.json && \
    echo '{"theme":"dark"}' > /home/agent/.claude/settings.json && \
    chown -R agent:agent /home/agent/.claude /home/agent/.claude.json

USER agent
WORKDIR /home/agent/workspace

# Init git repo
RUN git init && git config user.email "agent@workbench" && git config user.name "agent"

CMD ["bash"]
