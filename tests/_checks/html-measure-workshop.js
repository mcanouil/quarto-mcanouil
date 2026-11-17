// Measures of the workshop blocks of an HTML page (objectives, prerequisites,
// exercises, solutions and checkpoints), posted to the parent frame as JSON.
// Run by measure() in html.sh.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil
window.addEventListener("load", () => document.fonts.ready.then(() => {
  const out = { scheme: document.body.classList.contains("quarto-dark") ? "dark" : "light" };
  const shown = (el) => el.getClientRects().length > 0 && getComputedStyle(el).visibility !== "hidden";

  // Colours as [r, g, b, a], with r, g and b from 0 to 255.
  const parse = (text) => {
    const numbers = (text.match(/[\d.]+/g) || []).map(Number);
    if (text.startsWith("color(srgb")) {
      return [numbers[0] * 255, numbers[1] * 255, numbers[2] * 255, numbers.length > 3 ? numbers[3] : 1];
    }
    return [numbers[0], numbers[1], numbers[2], numbers.length > 3 ? numbers[3] : 1];
  };
  const over = (top, bottom) => {
    const a = top[3];
    return [0, 1, 2].map((i) => top[i] * a + bottom[i] * (1 - a)).concat([1]);
  };
  const background = (el) => {
    const layers = [];
    for (let node = el; node && node.nodeType === 1; node = node.parentElement) {
      const colour = parse(getComputedStyle(node).backgroundColor);
      if (colour[3] > 0) layers.push(colour);
      if (colour[3] >= 1) break;
    }
    let result = [255, 255, 255, 1];
    for (let i = layers.length - 1; i >= 0; i--) result = over(layers[i], result);
    return result;
  };
  const luminance = (c) => {
    const [r, g, b] = c.slice(0, 3).map((v) => {
      const s = v / 255;
      return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };
  const ratio = (a, b) => {
    const [high, low] = [luminance(a), luminance(b)].sort((x, y) => y - x);
    return (high + 0.05) / (low + 0.05);
  };
  const hex = (c) => "#" + c.slice(0, 3).map((v) => Math.round(v).toString(16).padStart(2, "0")).join("");

  // Each block: its kind, its visible label, and the label of its group.
  out.blocks = [...document.querySelectorAll(".mc-ws")].map((block) => {
    const label = block.querySelector(":scope > .mc-ws-label, :scope > summary");
    const named = block.getAttribute("aria-labelledby");
    return {
      kind: (block.className.match(/mc-ws-(objectives|prerequisites|exercise|solution|checkpoint)/) || [null, "?"])[1],
      label: label && shown(label) ? label.innerText.trim() : "",
      group: block.getAttribute("role") || block.tagName.toLowerCase(),
      named: named ? (document.getElementById(named) || { innerText: "" }).innerText.trim() : "",
    };
  });

  // Text colours of the blocks, with the colour behind them. A closed
  // solution shows its summary only, so the samples open it first.
  out.closed = [...document.querySelectorAll("details.mc-ws-solution")].map((details) => !details.open);
  document.querySelectorAll("details.mc-ws-solution").forEach((details) => { details.open = true; });
  const SAMPLES = [
    ["label", ".mc-ws-label"],
    ["summary", ".mc-ws-solution > summary"],
    ["block text", ".mc-ws p:not(.mc-ws-label), .mc-ws li"],
  ];
  out.colours = [];
  for (const [label, selector] of SAMPLES) {
    for (const el of document.querySelectorAll(selector)) {
      if (!shown(el)) continue;
      const bg = background(el);
      const fg = over(parse(getComputedStyle(el).color), bg);
      out.colours.push({ label, text: el.textContent.trim().slice(0, 24), fg: hex(fg), bg: hex(bg), ratio: ratio(fg, bg), bgLuminance: luminance(bg) });
    }
  }

  // Code: no ligatures and no contextual alternates.
  out.code = [...document.querySelectorAll("main code, main pre")].map((el) => {
    const style = getComputedStyle(el);
    return { ligatures: style.fontVariantLigatures, features: style.fontFeatureSettings };
  });

  // Decoration of the blocks: a pseudo-element with no content is hidden.
  out.decorations = {};
  for (const el of document.querySelectorAll(".mc-ws-label, .mc-ws > summary")) {
    for (const pseudo of ["::before", "::after"]) {
      const style = getComputedStyle(el, pseudo);
      if (style.content !== "none" && style.content !== "normal" && style.display !== "none") {
        out.decorations["label" + pseudo] = style.display;
      }
    }
  }
  // A decorative mark must be silent: generated content with an empty
  // alternative text, or none.
  out.silent = [...document.querySelectorAll(".mc-ws-label")].every((el) => ["::before", "::after"].every((pseudo) => {
    const content = getComputedStyle(el, pseudo).content;
    return content === "none" || content === "normal" || content === '""' || /\/ ?""$/.test(content);
  }));
  parent.postMessage(JSON.stringify(out), "*");
}));
