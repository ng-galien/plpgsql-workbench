CREATE OR REPLACE FUNCTION ops.get_agents()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
BEGIN
  v_body := '<div x-data="opsTmuxGrid">'
    || '<div class="ops-toolbar">'
    || '<button class="outline" @click="expandAll()">Ouvrir tout</button>'
    || '<button class="outline" @click="collapseAll()">Fermer tout</button>'
    || '<button class="outline" @click="pingAll()">Ping agents</button>'
    || '</div>'
    || '<template x-if="loading"><p class="ops-loading">Chargement...</p></template>'
    || '<template x-if="!loading && sessions.length === 0">'
    || pgv.empty('Aucune session active', 'make agents pour lancer les agents.')
    || '</template>'
    || '<div class="ops-agents-list">'
    || '<template x-for="s in sessions" :key="s.name">'
    || '<article class="ops-agent-card" :class="{ ''ops-agent-card--open'': s.open }">'
    || '<header class="ops-agent-card-header" @click="toggle(s)">'
    || '<span class="ops-agent-dot" :class="{ connected: s._connected, disconnected: s._disconnected, loading: !s._connected && !s._disconnected }"></span>'
    || '<span class="ops-agent-name" x-text="s.name"></span>'
    || '<span class="ops-agent-status" :class="{ ''ops-agent-status--active'': s.status && s.status !== ''idle'' }" x-text="s.status || ''idle''"></span>'
    || '<span class="ops-agent-chevron">&#9654;</span>'
    || '</header>'
    || '<div class="ops-agent-body" x-show="s.open">'
    || '<div x-data="opsTerminal" :data-module="s.name" x-effect="if(s.open && !_module) $nextTick(() => connect(s.name))" class="ops-terminal">'
    || '<div x-ref="terminal"></div>'
    || '<div x-show="!connected" class="ops-terminal-status">Connexion...</div>'
    || '</div>'
    || '</div>'
    || '</article>'
    || '</template>'
    || '</div>'
    || '</div>';

  RETURN v_body;
END;
$function$;
