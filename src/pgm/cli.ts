#!/usr/bin/env node
/**
 * pgm — PostgreSQL Module Manager
 *
 * Usage:
 *   pgm init                 Initialize a new app in current directory
 *   pgm install [module]     Install modules (copy files to app)
 *   pgm deploy [module]      Deploy SQL to DB (dry run by default, --apply to execute)
 *   pgm remove <module>      Remove module from workbench.json
 *   pgm list                 Show installed modules tree
 *   pgm info <module>        Show module details
 *   pgm available            List all modules in workspace
 */

import { Command } from "commander";
import fs from "fs/promises";
import path from "path";
import {
  findWorkspaceRoot,
  findAppRoot,
  loadAppConfig,
  saveAppConfig,
  loadManifest,
  listAvailableModules,
  resolve,
} from "./resolver.js";
import { installModules } from "./installer.js";
import { checkModules, deployModules } from "./deployer.js";
import { findNextPorts, scaffold } from "./scaffold.js";

const program = new Command();

program
  .name("pgm")
  .description("PostgreSQL Module Manager")
  .version("0.1.0");

// --- init ---

program
  .command("init")
  .description("Initialize a new app in the current directory")
  .action(async () => {
    const cwd = process.cwd();
    const name = path.basename(cwd);

    // Check if already initialized
    try {
      await fs.access(path.join(cwd, "workbench.json"));
      console.error("workbench.json already exists — this directory is already an app");
      process.exit(1);
    } catch {
      // good, not initialized
    }

    const wsRoot = await findWorkspaceRoot(cwd);
    const ports = await findNextPorts(wsRoot);

    console.log(`Initializing ${name}...\n`);
    console.log(`  ports: PG=${ports.pg} PostgREST=${ports.pgrst} HTTP=${ports.http} MCP=${ports.mcp}\n`);

    const created = await scaffold(cwd, name, ports, wsRoot);
    for (const f of created) {
      console.log(`  ${f}`);
    }

    console.log(`\nDone. Next:`);
    console.log(`  pgm install        # sync modules`);
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

// --- deploy (shared) ---

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

  // Show deploy plan
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

  // Check dependencies against live DB
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

// --- install ---

program
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

// --- deploy ---

program
  .command("deploy [module]")
  .description("Show deploy plan (dry run by default). Use --apply to execute.")
  .option("--apply", "Actually execute SQL against the database")
  .action(async (moduleName: string | undefined, opts: { apply?: boolean }) => {
    const ctx = await resolveContext(process.cwd());
    await runDeploy(ctx, moduleName, !!opts.apply);
  });

// --- remove ---

program
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
    console.log("Run 'pgm install' to re-sync files");
  });

// --- list ---

program
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
      const isLast = i === plan.order.length - 1;
      const prefix = isLast ? "└── " : "├── ";
      const deps = m.dependencies.length > 0 ? ` (needs: ${m.dependencies.join(", ")})` : "";
      console.log(`${prefix}${m.name}@${m.version}${deps}`);
    }
  });

// --- info ---

program
  .command("info <module>")
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

// --- available ---

program
  .command("available")
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

program.parse();
