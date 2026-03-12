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
    || '<span class="ops-agent-dot" :class="{ connected: s._connected, disconnected: s._disconnected && !s._reconnecting, loading: s._reconnecting }"></span>'
    || '<span class="ops-agent-name" x-text="s.name"></span>'
    || '<span class="ops-agent-status" :class="{ ''ops-agent-status--active'': s.status && s.status !== ''idle'' }" x-text="s.status || ''idle''"></span>'
    || '<span class="ops-agent-chevron">&#9654;</span>'
    || '</header>'
    || '<div class="ops-agent-body" x-show="s.open">'
    || '<div class="ops-terminal" :data-terminal-for="s.name" @click="activateSession(s.name)">'
    || '<div class="ops-terminal-status"'
    || ' x-show="activeModule === s.name && (s._reconnecting || s._backpressure || !s._connected)"'
    || ' :class="{ ''ops-terminal-status--reconnecting'': s._reconnecting, ''ops-terminal-status--backpressure'': s._backpressure }">'
    || '<span x-text="s._backpressure ? ''Buffer plein...'' : s._reconnecting ? ''Reconnexion...'' : ''Connexion...''"></span>'
    || '</div>'
    || '</div>'
    || '</div>'
    || '</article>'
    || '</template>'
    || '</div>'
    || '</div>';

  RETURN v_body;
END;
$function$;
