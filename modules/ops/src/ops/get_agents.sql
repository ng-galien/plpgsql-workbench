CREATE OR REPLACE FUNCTION ops.get_agents()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_body text;
BEGIN
  -- Dynamic tmux grid: Alpine fetches /api/tmux and renders terminal cards
  v_body := '<div x-data="opsTmuxGrid">'
    || '<template x-if="loading"><p>Chargement des sessions tmux...</p></template>'
    || '<template x-if="!loading && sessions.length === 0">'
    || pgv.empty('Aucune session tmux active', 'Lancez un agent Claude dans un module pour le voir ici.')
    || '</template>'
    || '<div class="ops-agents-live">'
    || '<template x-for="s in sessions" :key="s.name">'
    || '<article class="ops-agent-live-card">'
    || '<header>'
    || '<span x-text="s.name"></span> '
    || '<small x-text="s.cwd"></small>'
    || '</header>'
    || '<div x-data="opsTerminal" class="ops-terminal" data-height="300px">'
    || '<div x-ref="terminal" :data-module="s.name"'
    || ' :data-ws="''ws://'' + location.hostname + '':3100/ws/tmux/'' + s.name"></div>'
    || '<div x-show="!connected" class="ops-terminal-status">Connexion...</div>'
    || '</div>'
    || '</article>'
    || '</template>'
    || '</div>'
    || '</div>';

  RETURN v_body;
END;
$function$;
