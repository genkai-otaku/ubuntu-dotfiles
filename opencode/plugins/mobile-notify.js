import { spawn } from "node:child_process";
import {
  appendFileSync,
  closeSync,
  existsSync,
  mkdirSync,
  openSync,
  realpathSync,
  statSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HOME = os.homedir();
const PLUGIN_PATH = realpathSync(fileURLToPath(import.meta.url));
const DOTFILES_DIR = path.resolve(path.dirname(PLUGIN_PATH), "../..");
const SENDER = path.join(DOTFILES_DIR, "claude-notify", "send-push.mjs");
const CONFIG = process.env.CLAUDE_NOTIFY_CONFIG
  ? path.resolve(process.env.CLAUDE_NOTIFY_CONFIG)
  : path.join(HOME, ".claude", "claude-notify.json");
const LOG_FILE = path.join(HOME, ".claude", "claude-notify.log");
const MAX_LOG_BYTES = 1024 * 1024;

function prepareLog() {
  mkdirSync(path.dirname(LOG_FILE), { recursive: true });
  try {
    if (statSync(LOG_FILE).size > MAX_LOG_BYTES) writeFileSync(LOG_FILE, "");
  } catch {
    // ログがまだ存在しない場合は、追記時に作成する。
  }
}

function log(message) {
  try {
    prepareLog();
    appendFileSync(LOG_FILE, `${new Date().toISOString()} [OpenCode] ${message}\n`);
  } catch {
    // 通知・ログの失敗でOpenCodeの動作を妨げない。
  }
}

function startPush(project) {
  if (!existsSync(SENDER)) {
    log(`送信スクリプトが見つかりません: ${SENDER}`);
    return;
  }
  if (!existsSync(CONFIG)) {
    log(`通知設定が見つかりません: ${CONFIG}`);
    return;
  }

  const nixNode = path.join(HOME, ".nix-profile", "bin", "node");
  const node = process.env.CLAUDE_NOTIFY_NODE || (existsSync(nixNode) ? nixNode : "node");
  let logFD;

  try {
    prepareLog();
    logFD = openSync(LOG_FILE, "a");
    const child = spawn(
      node,
      [
        SENDER,
        "--title",
        `[${project}] Stop (OpenCode)`,
        "--body",
        "タスクが完了しました",
        "--event",
        "Stop",
        "--tag",
        "OpenCode-Stop",
        "--project",
        project,
      ],
      { detached: true, stdio: ["ignore", logFD, logFD] },
    );
    child.on("error", (error) => log(`送信プロセスを起動できませんでした: ${error.message}`));
    child.unref();
  } catch (error) {
    log(`送信プロセスの起動に失敗しました: ${error.message}`);
  } finally {
    if (logFD !== undefined) closeSync(logFD);
  }
}

async function notifyCompletion(ctx, sessionID) {
  try {
    const session = await ctx.session.get({ sessionID });
    // 子セッションではなく、ユーザーが依頼した親タスクの完了だけを通知する。
    if (session.parentID) return;
    const directory = session.location?.directory;
    startPush(directory ? path.basename(directory) || "unknown" : "unknown");
  } catch (error) {
    log(`セッション情報を取得できませんでした (${sessionID}): ${error.message}`);
  }
}

// OpenCode V2 のプラグインローダーは id と setup を持つ default export を受け取る。
// ローカルプラグインでは @opencode/plugin の bare import を解決できない環境があるため、
// Plugin.define に依存せず同じ定義形式を直接 export する。
export default {
  id: "ubuntu-dotfiles.mobile-notify",
  setup(ctx) {
    log("通知プラグインを読み込みました");
    const controller = new AbortController();

    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
          if (event.type !== "session.execution.succeeded") continue;
          const sessionID = event.data?.sessionID;
          if (typeof sessionID === "string") void notifyCompletion(ctx, sessionID);
        }
      } catch (error) {
        if (!controller.signal.aborted) log(`イベント購読に失敗しました: ${error.message}`);
      }
    })();

    return () => controller.abort();
  },
};
