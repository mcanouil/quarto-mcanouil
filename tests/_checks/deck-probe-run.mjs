/**
 * mcanouil - deck probe runner for the check hooks
 * Opens a deck page that carries deck-probe.js in a headless Chromium browser
 * in real time, through the DevTools protocol (Node.js built-in fetch and
 * WebSocket, no package), waits for the probe to write its <pre id="mc-probe">,
 * and prints its text. A run under virtual time (--dump-dom with
 * --virtual-time-budget) can stop before the probe ends when the machine is
 * busy; real time with a real timeout does not.
 *
 * Usage: node deck-probe-run.mjs <browser> <page.html> [query] [timeout-seconds]
 * Exits 1 with no output when the probe writes nothing before the timeout.
 *
 * @license MIT
 * @copyright 2026 Mickaël Canouil
 * @author Mickaël Canouil
 */
import { spawn } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [browser, page, query = "", timeout = "90"] = process.argv.slice(2);
if (!browser || !page) {
  console.error("usage: node deck-probe-run.mjs <browser> <page.html> [query] [timeout-seconds]");
  process.exit(2);
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const profile = mkdtempSync(join(tmpdir(), "mc-deck-probe-"));
const child = spawn(browser, [
  "--headless=new", "--disable-gpu", "--no-first-run", "--hide-scrollbars",
  "--remote-debugging-port=0", `--user-data-dir=${profile}`, "--window-size=1600,900",
  "about:blank",
], { stdio: ["ignore", "ignore", "pipe"] });
let browserError = "";
child.stderr.on("data", (chunk) => { browserError += chunk; });

const finish = async (text, code) => {
  const closed = new Promise((resolve) => {
    if (child.exitCode !== null || child.signalCode !== null) resolve();
    else child.once("exit", resolve);
  });
  child.kill();
  await closed;
  rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  if (text) console.log(text);
  process.exit(code);
};

try {
  const portFile = join(profile, "DevToolsActivePort");
  const url = pathToFileURL(page).href + query;
  // A busy machine can write the port file before the browser listens on the
  // port, so the port is read and the target opened again until both work.
  let target = null;
  let failure = "the browser wrote no DevToolsActivePort";
  for (let i = 0; i < 300 && target === null; i++) {
    try {
      const port = existsSync(portFile) ? readFileSync(portFile, "utf8").split("\n")[0].trim() : "";
      if (port) {
        target = await (await fetch(`http://127.0.0.1:${port}/json/new?${url}`, { method: "PUT" })).json();
      }
    } catch (error) {
      failure = error.message;
    }
    if (target === null) await sleep(100);
  }
  if (target === null) throw new Error(`no DevTools target after 30 s: ${failure}${browserError ? `\n${browserError.trim()}` : ""}`);
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.onopen = resolve;
    socket.onerror = reject;
  });
  let id = 0;
  const pending = new Map();
  socket.onmessage = (event) => {
    const message = JSON.parse(event.data);
    if (pending.has(message.id)) {
      pending.get(message.id)(message);
      pending.delete(message.id);
    }
  };
  const send = (method, params = {}) => new Promise((resolve) => {
    id += 1;
    pending.set(id, resolve);
    socket.send(JSON.stringify({ id, method, params }));
  });
  // While the page loads, an evaluation can meet a context that is gone; it
  // then answers null, and the loop asks again.
  const evaluate = async (expression) => {
    const answer = await send("Runtime.evaluate", { expression, returnByValue: true });
    return answer.result && answer.result.result ? answer.result.result.value ?? null : null;
  };

  const deadline = Date.now() + Number(timeout) * 1000;
  let text = null;
  while (Date.now() < deadline) {
    text = await evaluate('(document.getElementById("mc-probe") || {}).textContent ?? null');
    if (text !== null) break;
    await sleep(200);
  }
  await finish(text, text === null ? 1 : 0);
} catch (error) {
  console.error(`deck-probe-run: ${error.message}`);
  await finish(null, 1);
}
