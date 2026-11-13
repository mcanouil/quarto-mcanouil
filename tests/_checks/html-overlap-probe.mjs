/**
 * mcanouil - overlap toggle probe for the check hooks
 * Opens an HTML page in a headless Chromium browser in real time, through the
 * DevTools protocol (Node.js built-in fetch and WebSocket, no package), waits
 * until Quarto swaps the contents column for its toggle (the fixture puts
 * margin content beside the contents), and prints the toggle state as JSON:
 * { margin, toggle, button, expanded, controls, closedInert, originalOut }.
 * Quarto builds the toggle from an IntersectionObserver, which a --dump-dom
 * run under virtual time does not drive.
 *
 * Usage: node html-overlap-probe.mjs <browser> <page.html> <width> <height>
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

const [browser, page, width, height] = process.argv.slice(2);
if (!browser || !page) {
  console.error("usage: node html-overlap-probe.mjs <browser> <page.html> <width> <height>");
  process.exit(2);
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const profile = mkdtempSync(join(tmpdir(), "mc-overlap-"));
const child = spawn(browser, [
  "--headless=new", "--disable-gpu", "--no-first-run", "--hide-scrollbars",
  "--remote-debugging-port=0", `--user-data-dir=${profile}`, `--window-size=${width || 1440},${height || 900}`,
  "about:blank",
], { stdio: "ignore" });

// What the page answers: the toggle, and whether the closed copy and the
// hidden original stay out of the tab order.
const MEASURE = `(() => {
  const margin = document.querySelector("main :is(.column-margin, .column-page-right, .column-screen-inset-right)");
  const overlap = document.querySelector(".quarto-sidebar-toggle");
  if (!overlap) return { margin: Boolean(margin), toggle: false };
  const title = overlap.querySelector(".quarto-sidebar-toggle-title");
  const control = title && (title.tagName === "BUTTON" || title.getAttribute("role") === "button" ? title : title.querySelector("button"));
  const contents = overlap.querySelector(".quarto-sidebar-toggle-contents");
  const original = document.querySelector("#quarto-margin-sidebar");
  const reachable = (el) => Boolean(el) && [...el.querySelectorAll("a[href], button")].some((a) =>
    a.tabIndex >= 0 && !a.closest("[inert]") && getComputedStyle(a).visibility !== "hidden" && a.getClientRects().length > 0);
  return {
    margin: Boolean(margin),
    toggle: true,
    button: Boolean(control),
    expanded: control ? control.getAttribute("aria-expanded") : null,
    controls: Boolean(control && control.getAttribute("aria-controls") && document.getElementById(control.getAttribute("aria-controls"))),
    closedInert: Boolean(contents && (contents.closest("[inert]") || contents.hasAttribute("hidden") || !reachable(contents))),
    originalOut: !reachable(original),
  };
})()`;

const finish = async (result, code) => {
  const closed = new Promise((resolve) => child.once("exit", resolve));
  child.kill();
  await closed;
  rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  if (result) console.log(JSON.stringify(result));
  process.exit(code);
};

try {
  const portFile = join(profile, "DevToolsActivePort");
  for (let i = 0; i < 100 && !existsSync(portFile); i++) await sleep(100);
  const port = readFileSync(portFile, "utf8").split("\n")[0];
  const target = await (await fetch(`http://127.0.0.1:${port}/json/new?${pathToFileURL(page).href}`, { method: "PUT" })).json();
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
  const evaluate = async (expression) => (await send("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true })).result.result.value;

  for (let i = 0; i < 100 && (await evaluate("document.readyState")) !== "complete"; i++) await sleep(100);
  await evaluate("document.fonts.ready.then(() => true)");
  // Quarto checks the overlap on scroll and resize events only, so the page
  // gets a resize event once the observers have seen the margin content.
  await sleep(500);
  let result = await evaluate(MEASURE);
  for (let i = 0; i < 30 && result.margin && !result.toggle; i++) {
    await evaluate("window.dispatchEvent(new Event('resize')), true");
    await sleep(100);
    result = await evaluate(MEASURE);
  }
  await finish(result, 0);
} catch (error) {
  console.error(`html-overlap-probe: ${error.message}`);
  await finish(null, 1);
}
