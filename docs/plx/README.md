# PLX Docs

Cette arborescence complète la référence de syntaxe PLX dans [PLX-SYNTAX.md](/Users/alexandreboyer/dev/projects/plpgsql-workbench/docs/PLX-SYNTAX.md).

- [GUIDELINES.md](/Users/alexandreboyer/dev/projects/plpgsql-workbench/docs/plx/GUIDELINES.md): comment bien modéliser et où placer la logique
- [PATTERNS.md](/Users/alexandreboyer/dev/projects/plpgsql-workbench/docs/plx/PATTERNS.md): recettes concrètes et points d'extension
- [MIGRATION.md](/Users/alexandreboyer/dev/projects/plpgsql-workbench/docs/plx/MIGRATION.md): méthode de portage depuis un module legacy

Ordre de lecture conseillé:

1. [PLX-SYNTAX.md](/Users/alexandreboyer/dev/projects/plpgsql-workbench/docs/PLX-SYNTAX.md)
2. [GUIDELINES.md](/Users/alexandreboyer/dev/projects/plpgsql-workbench/docs/plx/GUIDELINES.md)
3. [PATTERNS.md](/Users/alexandreboyer/dev/projects/plpgsql-workbench/docs/plx/PATTERNS.md)
4. [MIGRATION.md](/Users/alexandreboyer/dev/projects/plpgsql-workbench/docs/plx/MIGRATION.md)

Rappels manifeste:

- `plx.entry`: point d'entrée declaratif du module
- `plx.sqlLib`: bibliotheque SQL appliquee avant les artefacts generes par PLX
- `plx.seed`: donnees de reference
- `plx.post_apply`: complements finaux apres apply principal
