import { asFunction } from "awilix";
import { createBroadcastTool } from "../commands/plpgsql/broadcast.js";
import { createMsgInboxTool, createMsgTool } from "../commands/plpgsql/msg.js";
import { type HookRule, inputStr, type Plugin } from "../core/plugin.js";

export const pgMessagingPlugin: Plugin = {
  id: "pg-messaging",
  name: "Inter-Agent Messaging",
  requires: ["withClient"],

  register(container) {
    container.register({
      msgTool: asFunction(createMsgTool).singleton(),
      msgInboxTool: asFunction(createMsgInboxTool).singleton(),
      broadcastTool: asFunction(createBroadcastTool).singleton(),
    });
  },

  hooks(): HookRule[] {
    return [
      {
        toolPattern: /pg_msg$/,
        evaluate(ctx) {
          const msgType = inputStr(ctx, "type");
          const to = inputStr(ctx, "to");
          if (msgType !== "info" && to !== "lead" && to !== "*") {
            return {
              action: "deny",
              reason:
                `Les messages de type '${msgType}' ne peuvent pas être envoyés directement à un autre module.\n` +
                `Deux options :\n` +
                `1. Envoyer au lead : pg_msg from:${ctx.module} to:lead type:${msgType} subject:...\n` +
                `2. Créer une issue : pg_query sql: "INSERT INTO workbench.issue_report(issue_type, module, description, context) VALUES ('${msgType === "bug_report" ? "bug" : "enhancement"}', '${to}', '<description>', '{}')"\n` +
                `Seuls les messages de type 'info' peuvent être envoyés directement entre modules.`,
            };
          }
          return null;
        },
      },
    ];
  },
};
