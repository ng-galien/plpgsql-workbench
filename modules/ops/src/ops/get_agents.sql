CREATE OR REPLACE FUNCTION ops.get_agents()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_body text;
BEGIN
  v_body := '<div x-data="opsTmuxGrid">'
    || '<div class="ops-toolbar">'
    || '<button class="outline" @click="trigResize()">Trig resize</button>'
    || '<button class="outline" @click="pingAll()">Ping agents</button>'
    || '<button class="outline" @click="scrollBottom()">Scroll bas</button>'
    || '</div>'
    || '<template x-if="loading"><p class="ops-loading">Chargement...</p></template>'
    || '<template x-if="!loading && sessions.length === 0">'
    || pgv.empty('Aucune session active', 'make agents pour lancer les agents.')
    || '</template>'
    || '<div class="ops-agents-live">'
    || '<template x-for="s in sessions" :key="s.name">'
    || '<div class="ops-agent-card">'
    || '<div class="ops-agent-card-header">'
    || '<span class="ops-agent-dot loading" :class="{ connected: s._connected, disconnected: s._disconnected, loading: !s._connected && !s._disconnected }"></span>'
    || '<span class="ops-agent-name" x-text="s.name"></span>'
    || '<span class="ops-agent-meta" x-text="s.dead ? ''dead'' : ''live''"></span>'
    || '</div>'
    || '<div x-data="opsTerminal" :data-module="s.name" x-init="$nextTick(() => connect(s.name))" class="ops-terminal">'
    || '<div x-ref="terminal"></div>'
    || '<div x-show="!connected" class="ops-terminal-status">Connexion...</div>'
    || '</div>'
    || '</div>'
    || '</template>'
    || '</div>'
    || '</div>';

  RETURN v_body;
END;
$function$;
