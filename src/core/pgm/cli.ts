#!/usr/bin/env node

/**
 * pgm — PostgreSQL Module Manager
 *
 * Usage:
 *   pgm app init              Initialize a new app in current directory
 *   pgm app install [module]  Install modules (copy files to app)
 *   pgm app deploy [module]   Deploy SQL to DB (dry run, --apply to execute)
 *   pgm app remove <module>   Remove module from workbench.json
 *   pgm app list              Show installed modules tree
 *
 *   pgm module new <name>     Scaffold a new module
 *   pgm module info <name>    Show module details
 *   pgm module list           List all available modules
 */

import fs from "node:fs/promises";
import path from "node:path";
import { Command } from "commander";
import { checkModules, deployModules } from "./deployer.js";
import { installModules } from "./installer.js";
import { buildPlxModule } from "./plx-builder.js";
import {
  findAppRoot,
  findWorkspaceRoot,
  listAvailableModules,
  loadAppConfig,
  loadManifest,
  resolve,
  saveAppConfig,
} from "./resolver.js";
import { findNextPorts, scaffoldApp, scaffoldModule } from "./scaffold.js";
import { cleanSupabaseMigrations, syncToSupabase } from "./supabase.js";

const program = new Command();

program.name("pgm").description("PostgreSQL Module Manager").version("0.1.0");

// ── pgm app ──────────────────────────────────────────────────────

const app = program.command("app").description("App lifecycle (init, install, deploy, remove, list)");

// --- app init ---

app
  .command("init")
  .description("Initialize a new app in the current directory")
  .action(async () => {
    const cwd = process.cwd();
    const name = path.basename(cwd);

    try {
      await fs.access(path.join(cwd, "workbench.json"));
      console.error("workbench.json already exists — this directory is already an app");
      process.exit(1);
    } catch {
      // good
    }

    const wsRoot = await findWorkspaceRoot(cwd);
    const ports = await findNextPorts(wsRoot);

    console.log(`Initializing app ${name}...\n`);
    console.log(`  ports: PG=${ports.pg} PostgREST=${ports.pgrst} HTTP=${ports.http} MCP=${ports.mcp}\n`);

    const created = await scaffoldApp(cwd, name, ports, wsRoot);
    for (const f of created) {
      console.log(`  ${f}`);
    }

    console.log(`\nDone. Next:`);
    console.log(`  pgm app install    # sync modules`);
    console.log(`  make up            # start stack`);
  });

// --- Shared helpers ---

async function resolveContext(cwd: string) {
  const appDir = await findAppRoot(cwd);
  const wsRoot = await findWorkspaceRoot(appDir);
  const modulesDir = path.join(wsRoot, "modules");
  const config = await loadAppConfig(appDir);
  return { appDir, wsRoot, modulesDir, config };
}

function printDeployResults(results: Awaited<ReturnType<typeof deployModules>>) {
  let allOk = true;
  for (const r of results) {
    const status = r.ok ? "ok" : "FAILED";
    console.log(`  ${r.module}@${r.version} ${status}`);
    for (const f of r.files) {
      if (f.ok) {
        console.log(`    ${f.name}`);
      } else {
        console.log(`    ${f.name} FAILED: ${f.error}`);
        allOk = false;
      }
    }
  }
  if (!allOk) {
    console.log("\nDeploy failed — fix errors above and retry");
    process.exit(1);
  }
}

async function runDeploy(
  ctx: Awaited<ReturnType<typeof resolveContext>>,
  moduleName: string | undefined,
  apply: boolean,
) {
  if (!ctx.config.modules || ctx.config.modules.length === 0) {
    console.log("No modules to deploy");
    return;
  }

  if (!ctx.config.connection) {
    console.error("No connection string in workbench.json — cannot deploy");
    process.exit(1);
  }

  const plan = await resolve(ctx.modulesDir, ctx.config.modules);

  if (moduleName) {
    const found = plan.order.find((m) => m.name === moduleName);
    if (!found) {
      console.error(`Module "${moduleName}" not in dependency tree`);
      process.exit(1);
    }
  }

  console.log(`Deploy plan (${plan.order.length} module(s)):\n`);
  for (const m of plan.order) {
    if (moduleName && m.name !== moduleName) {
      console.log(`  ${m.name}@${m.version} (skip)`);
      continue;
    }
    const deps = m.dependencies.length > 0 ? ` (after: ${m.dependencies.join(", ")})` : "";
    console.log(`  ${m.name}@${m.version}${deps}`);
    for (const sqlFile of m.sql) {
      console.log(`    ${sqlFile}`);
    }
  }

  console.log("\nChecking dependencies...\n");
  const checks = await checkModules(plan, ctx.config.connection, moduleName);
  let hasIssues = false;

  for (const cr of checks) {
    if (cr.checks.length === 0) {
      console.log(`  ${cr.module}: no dependencies`);
      continue;
    }
    for (const c of cr.checks) {
      const icon = c.present ? "ok" : "MISSING";
      console.log(`  ${cr.module}: ${c.kind} ${c.name} ${icon}`);
      if (!c.present) hasIssues = true;
    }
  }

  if (hasIssues) {
    console.log("\nDependency check failed — fix missing items before deploying");
    if (!apply) console.log("(dry run)");
    process.exit(1);
  }

  if (!apply) {
    console.log("\nAll checks passed — use --apply to execute");
    return;
  }

  console.log("\nApplying...\n");
  const results = await deployModules(ctx.modulesDir, plan, ctx.config.connection, moduleName);
  printDeployResults(results);
  console.log(`\n${results.length} module(s) deployed`);
}

// --- app install ---

app
  .command("install [module]")
  .description("Install modules (copy files, optionally deploy to DB)")
  .option("-d, --deploy", "Also deploy SQL to the database after copying (dry run first)")
  .option("--apply", "With --deploy: actually execute SQL (skip dry run)")
  .action(async (moduleName: string | undefined, opts: { deploy?: boolean; apply?: boolean }) => {
    const ctx = await resolveContext(process.cwd());

    if (!ctx.config.modules) ctx.config.modules = [];

    if (moduleName) {
      if (ctx.config.modules.includes(moduleName)) {
        console.log(`${moduleName} already in workbench.json`);
      } else {
        await loadManifest(ctx.modulesDir, moduleName);
        ctx.config.modules.push(moduleName);
        await saveAppConfig(ctx.appDir, ctx.config);
        console.log(`Added "${moduleName}" to workbench.json`);
      }
    }

    if (ctx.config.modules.length === 0) {
      console.log("No modules to install");
      return;
    }

    const plan = await resolve(ctx.modulesDir, ctx.config.modules);
    const results = await installModules(ctx.modulesDir, ctx.appDir, plan);

    console.log("");
    for (const r of results) {
      console.log(`  ${r.module}@${r.version}`);
      for (const f of r.files) {
        console.log(`    ${f}`);
      }
    }
    console.log(`\n${results.length} module(s) installed`);

    if (opts.deploy) {
      console.log("");
      await runDeploy(ctx, undefined, !!opts.apply);
    }
  });

// --- app deploy ---

app
  .command("deploy [module]")
  .description("Show deploy plan (dry run by default). Use --apply to execute.")
  .option("--apply", "Actually execute SQL against the database")
  .action(async (moduleName: string | undefined, opts: { apply?: boolean }) => {
    const ctx = await resolveContext(process.cwd());
    await runDeploy(ctx, moduleName, !!opts.apply);
  });

// --- app remove ---

app
  .command("remove <module>")
  .description("Remove a module from workbench.json")
  .action(async (moduleName: string) => {
    const ctx = await resolveContext(process.cwd());

    if (!ctx.config.modules || !ctx.config.modules.includes(moduleName)) {
      console.error(`Module "${moduleName}" not in workbench.json`);
      process.exit(1);
    }

    ctx.config.modules = ctx.config.modules.filter((m) => m !== moduleName);
    await saveAppConfig(ctx.appDir, ctx.config);
    console.log(`Removed "${moduleName}" from workbench.json`);
    console.log("Run 'pgm app install' to re-sync files");
  });

// --- app list ---

app
  .command("list")
  .description("Show installed modules tree")
  .action(async () => {
    const ctx = await resolveContext(process.cwd());

    if (!ctx.config.modules || ctx.config.modules.length === 0) {
      console.log(`${ctx.config.name} (no modules)`);
      return;
    }

    const plan = await resolve(ctx.modulesDir, ctx.config.modules);

    console.log(ctx.config.name);
    for (let i = 0; i < plan.order.length; i++) {
      const m = plan.order[i];
      if (!m) continue;
      const isLast = i === plan.order.length - 1;
      const prefix = isLast ? "└── " : "├── ";
      const deps = m.dependencies.length > 0 ? ` (needs: ${m.dependencies.join(", ")})` : "";
      console.log(`${prefix}${m.name}@${m.version}${deps}`);
    }
  });

// ── pgm module ───────────────────────────────────────────────────

const mod = program.command("module").description("Module development (new, info, list)");

// --- module new ---

mod
  .command("new <name>")
  .description("Scaffold a new module")
  .option("-s, --schema <name>", "Public schema name (default: module name)")
  .option("-d, --description <text>", "Module description")
  .option("-p, --port <port>", "MCP server port (default: 3100)", "3100")
  .option("--plx", "Scaffold a PLX-first module (src/<name>.plx + generated build/*.sql)")
  .action(async (moduleName: string, opts: { schema?: string; description?: string; plx?: boolean; port: string }) => {
    const wsRoot = await findWorkspaceRoot(process.cwd());
    const modulesDir = path.join(wsRoot, "modules");
    const moduleDir = path.join(modulesDir, moduleName);

    try {
      await fs.access(moduleDir);
      console.error(`modules/${moduleName} already exists`);
      process.exit(1);
    } catch {
      // good
    }

    const schemaName = opts.schema ?? moduleName;
    const mcpPort = parseInt(opts.port, 10);
    if (opts.plx && schemaName !== moduleName) {
      console.error("PLX scaffolds currently require the public schema to match the module name");
      process.exit(1);
    }

    console.log(`Creating module ${moduleName}...\n`);

    const created = await scaffoldModule(moduleDir, moduleName, schemaName, mcpPort, {
      description: opts.description,
      mode: opts.plx ? "plx" : "sql",
    });
    for (const f of created) {
      console.log(`  ${f}`);
    }

    if (opts.plx) {
      console.log(`\nDone. Edit src/${moduleName}.plx, then run "pgm module build ${moduleName}".`);
    } else {
      console.log(`\nDone. Start dev DB (make dev-up) then iterate with pg_func_set.`);
    }
  });

// --- module info ---

mod
  .command("build <name>")
  .description("Build SQL artifacts from the module PLX entry when declared")
  .option("--no-validate", "Skip PG parser validation during PLX build")
  .action(async (moduleName: string, opts: { validate?: boolean }) => {
    const wsRoot = await findWorkspaceRoot(process.cwd());
    const modulesDir = path.join(wsRoot, "modules");
    const manifest = await loadManifest(modulesDir, moduleName);

    if (!manifest.plx?.entry) {
      console.log(`Module "${moduleName}" has no plx.entry`);
      return;
    }

    const result = await buildPlxModule(modulesDir, manifest, { validate: opts.validate });
    if (result.files.length === 0) {
      console.log(`No PLX artifacts generated for ${moduleName}`);
    } else {
      console.log(`Built ${moduleName} from ${manifest.plx.entry}`);
      for (const file of result.files) {
        console.log(`  ${file}`);
      }
    }

    for (const warning of result.warnings) {
      console.warn(`  WARN   ${moduleName}: ${warning}`);
    }
  });

mod
  .command("info <name>")
  .description("Show module details")
  .action(async (moduleName: string) => {
    const wsRoot = await findWorkspaceRoot(process.cwd());
    const modulesDir = path.join(wsRoot, "modules");
    const manifest = await loadManifest(modulesDir, moduleName);

    console.log(`${manifest.name}@${manifest.version}`);
    console.log(`  ${manifest.description}`);
    console.log("");
    console.log(`  schemas:`);
    if (manifest.schemas.public) console.log(`    public:  ${manifest.schemas.public}`);
    if (manifest.schemas.private) console.log(`    private: ${manifest.schemas.private}`);
    console.log(`  dependencies: ${manifest.dependencies.length > 0 ? manifest.dependencies.join(", ") : "none"}`);
    console.log(`  extensions: ${manifest.extensions.length > 0 ? manifest.extensions.join(", ") : "none"}`);
    console.log(`  sql: ${manifest.sql.join(", ")}`);
    if (manifest.plx?.entry) {
      console.log(`  plx: ${manifest.plx.entry}`);
      if (manifest.plxContract) {
        const plxDepends = manifest.plxContract.depends.length > 0 ? manifest.plxContract.depends.join(", ") : "none";
        console.log(`    contract module: ${manifest.plxContract.moduleName}`);
        console.log(`    contract depends: ${plxDepends}`);
        console.log(
          `    contract symbols: ${manifest.plxContract.exports.length} export, ${manifest.plxContract.internals.length} internal`,
        );
      }
    }
    const frontend = manifest.assets?.frontend ?? [];
    const scripts = manifest.assets?.scripts ?? [];
    const styles = manifest.assets?.styles ?? [];
    console.log(`  assets: ${frontend.length > 0 ? frontend.join(", ") : "none"}`);
    if (scripts.length > 0) console.log(`  scripts: ${scripts.join(", ")}`);
    if (styles.length > 0) console.log(`  styles: ${styles.join(", ")}`);
    if (manifest.docker) {
      console.log(`  docker: ${manifest.docker.image}`);
      if (manifest.docker.note) console.log(`    ${manifest.docker.note}`);
    }
  });

// --- module list ---

mod
  .command("list")
  .description("List all available modules in the workspace")
  .action(async () => {
    const wsRoot = await findWorkspaceRoot(process.cwd());
    const modulesDir = path.join(wsRoot, "modules");
    const modules = await listAvailableModules(modulesDir);

    if (modules.length === 0) {
      console.log("No modules found");
      return;
    }

    for (const name of modules) {
      const manifest = await loadManifest(modulesDir, name);
      console.log(`  ${manifest.name}@${manifest.version}  ${manifest.description}`);
    }
  });

// ── pgm supabase ────────────────────────────────────────────────

const supa = program.command("supabase").description("Supabase deployment (sync migrations)");

// --- supabase sync ---

supa
  .command("sync")
  .description("Generate Supabase migrations from module build files")
  .argument("<modules...>", "Module names to include (dependencies resolved automatically)")
  .option("--clean", "Remove previously generated migrations first")
  .action(async (moduleNames: string[], opts: { clean?: boolean }) => {
    const wsRoot = await findWorkspaceRoot(process.cwd());

    if (opts.clean) {
      const removed = await cleanSupabaseMigrations(wsRoot);
      if (removed > 0) console.log(`Cleaned ${removed} previous migration(s)`);
    }

    console.log(`Syncing modules: ${moduleNames.join(", ")}\n`);
    const result = await syncToSupabase(wsRoot, moduleNames);

    console.log(`Modules (dependency order): ${result.modules.join(" → ")}\n`);
    console.log(`Generated ${result.migrations.length} migration(s):`);
    for (const m of result.migrations) {
      console.log(`  supabase/migrations/${m}`);
    }
    console.log(`\nDeploy with: supabase db push`);
  });

// --- supabase clean ---

supa
  .command("clean")
  .description("Remove auto-generated Supabase migrations")
  .action(async () => {
    const wsRoot = await findWorkspaceRoot(process.cwd());
    const removed = await cleanSupabaseMigrations(wsRoot);
    console.log(`Removed ${removed} migration(s)`);
  });

program.parse();
