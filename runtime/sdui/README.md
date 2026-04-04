# sdui

Schema target: `sdui`

Scope:

- `ui_*` primitives
- SDUI contracts
- SDUI facade

Incoming mapping:

- `pgv.ui_*`
- `pgv.view_schema`
- `pgv.api`
- `pgv._parse_uri`
- `pgv.app_nav`
- `pgv.nav_schema`
- `pgv.ui_form_for`

Current dependency boundary:

- `sdui` depends on extracted runtime schemas such as `i18n`, `util`, `query`, `catalog`
