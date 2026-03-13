CREATE OR REPLACE FUNCTION ops.get_index()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN '<div x-data="opsTmuxGrid">'
    || '<template x-if="loading"><p>Chargement...</p></template>'
    || '<template x-if="!loading && sessions.length === 0">'
    || pgv.empty('Aucune session active', 'make agents pour lancer les agents.')
    || '</template>'
    || '<template x-if="!loading && sessions.length > 0">'
    || '<div>'
    || '<table role="grid">'
    || '<thead><tr><th>Agent</th><th>Status</th></tr></thead>'
    || '<tbody>'
    || '<template x-for="s in sessions" :key="s.name">'
    || '<tr @click="activateSession(s.name)" class="pgv-link" :class="{ ''ops-row-selected'': activeModule === s.name }">'
    || '<td><span class="ops-agent-dot" :class="{ connected: s._connected, disconnected: s._disconnected && !s._reconnecting, loading: s._reconnecting }"></span> <span x-text="s.name"></span></td>'
    || '<td><span class="pgv-badge" :class="s.status && s.status !== ''idle'' ? ''pgv-badge-success'' : ''pgv-badge-default''" x-text="s.status || ''idle''"></span></td>'
    || '</tr>'
    || '</template>'
    || '</tbody>'
    || '</table>'
    || '<template x-if="activeModule">'
    || pgv.card(
        '<span x-text="activeModule"></span>',
        '<div class="ops-agents-terminal">'
        || '<template x-for="s in sessions" :key="''term-'' + s.name">'
        || '<div x-show="activeModule === s.name">'
        || '<div :data-terminal-for="s.name" class="ops-terminal-body"></div>'
        || '</div>'
        || '</template>'
        || '</div>',
        NULL
      )
    || '</template>'
    || '</div>'
    || '</template>'
    || '</div>';
END;
$function$;
