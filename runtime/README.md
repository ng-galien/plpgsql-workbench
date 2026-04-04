# Runtime

`runtime/` contains platform schemas.

This directory is intentionally separate from `modules/`:

- `modules/` are business modules
- `runtime/` is platform code

The old `pgv` module is being dismantled into focused runtime areas:

- `i18n`
- `sdui`
- `query`
- `util`
- `catalog`
- `dev`

The target is not backward compatibility.

We prefer a clean architecture now, then align tooling and modules later.
