// Measures of the title block of an HTML page, posted to the parent frame as
// JSON: the motif, the scheme toggle, the text over them, and the display of
// each decoration. Run by measure() in html.sh.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil
window.addEventListener("load", () => document.fonts.ready.then(() => {
  const header = document.getElementById("title-block-header");
  const motif = header && header.querySelector(":scope > svg.mc-motif");
  const out = { viewport: document.documentElement.clientWidth, overlaps: [] };
  const intersects = (a, b) => a.right > b.left && a.left < b.right && a.bottom > b.top && a.top < b.bottom;
  const textOver = (rect, label) => {
    const walker = document.createTreeWalker(header, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const node = walker.currentNode;
      if (!node.textContent.trim() || motif.contains(node)) continue;
      const range = document.createRange();
      range.selectNodeContents(node);
      for (const r of range.getClientRects()) {
        if (intersects(r, rect)) out.overlaps.push(label + ": " + node.textContent.trim().slice(0, 30));
      }
    }
  };
  if (header && motif) {
    const h = header.getBoundingClientRect();
    const m = motif.getBoundingClientRect();
    const style = getComputedStyle(motif);
    out.header = [h.top + window.scrollY, h.right];
    out.motif = [m.top + window.scrollY, m.right, m.width, m.height];
    out.box = [style.marginTop, style.marginRight, style.paddingTop, style.paddingRight].join(" ");
    textOver(m, "motif");
    const toggle = document.querySelector(".quarto-color-scheme-toggle");
    if (toggle && toggle.getClientRects().length) {
      const t = toggle.getBoundingClientRect();
      out.toggle = [t.left, t.top, t.right, t.bottom];
      out.toggleOverMotif = intersects(t, m);
      textOver(t, "toggle");
    }
  }
  // Text on a memo banner or band: each text with its colour contrast
  // against both ends of the ground gradient behind it.
  const parse = (text) => {
    const numbers = (text.match(/[\d.]+/g) || []).map(Number);
    const scale = text.startsWith("color(srgb") ? 255 : 1;
    return [numbers[0] * scale, numbers[1] * scale, numbers[2] * scale, numbers.length > 3 ? numbers[3] : 1];
  };
  const over = (top, bottom) => [0, 1, 2].map((i) => top[i] * top[3] + bottom[i] * (1 - top[3])).concat([1]);
  const luminance = (c) => {
    const [r, g, b] = c.slice(0, 3).map((v) => {
      const x = v / 255;
      return x <= 0.03928 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };
  const ratio = (a, b) => {
    const [high, low] = [luminance(a), luminance(b)].sort((x, y) => y - x);
    return (high + 0.05) / (low + 0.05);
  };
  const hex = (c) => "#" + c.slice(0, 3).map((v) => Math.round(v).toString(16).padStart(2, "0")).join("");
  const stopsOf = (el) => (getComputedStyle(el).backgroundImage.match(/(?:rgba?|color)\([^)]*\)/g) || []).map(parse);
  const ground = (el, label) => {
    const layers = [];
    let node = el;
    while (node && node.nodeType === 1 && getComputedStyle(node).backgroundImage === "none") {
      const colour = parse(getComputedStyle(node).backgroundColor);
      if (colour[3] > 0) layers.push(colour);
      node = node.parentElement;
    }
    const stops = node && node.nodeType === 1 ? stopsOf(node) : [];
    const results = stops.map((stop) => layers.reduceRight((below, layer) => over(layer, below), stop));
    const fg = parse(getComputedStyle(el).color);
    return {
      label, text: el.textContent.trim().slice(0, 24), fg: hex(fg), stops: stops.map(hex),
      ratios: results.map((result) => ratio(over(fg, result), result)),
    };
  };
  const memoBanner = document.querySelector("#title-block-header.mc-memo-banner");
  const memoBand = document.querySelector(".mc-page-footer.mc-memo-band");
  if (memoBanner) {
    out.ground = [];
    for (const [label, selector] of [["kicker", ".mc-kicker"], ["title", "h1.title"], ["term", "dl.mc-memo-fields dt"], ["description", "dl.mc-memo-fields dd"]]) {
      for (const el of memoBanner.querySelectorAll(selector)) out.ground.push(ground(el, label));
    }
    if (memoBand) {
      for (const el of memoBand.querySelectorAll(".mc-slot")) {
        if (el.textContent.trim()) out.ground.push(ground(el, "band"));
      }
    }
  }
  const fill = (el) => (el ? (getComputedStyle(el).backgroundImage === "none" ? "none" : "gradient") : "missing");

  const h2 = document.querySelector("main.content h2");
  const title = header && header.querySelector(".title");
  const show = (el, pseudo) => {
    if (!el) return "missing";
    const style = getComputedStyle(el, pseudo);
    return pseudo && (style.content === "none" || style.content === "normal") ? "none" : style.display;
  };
  out.decorations = {
    motif: show(motif, null),
    rule: show(header && header.querySelector(".mc-title-rule"), null),
    "h2::before": show(h2, "::before"),
    "h2::after": show(h2, "::after"),
    "title::before": show(title, "::before"),
    "title::after": show(title, "::after"),
    "kicker::before": show(header && header.querySelector(".mc-kicker"), "::before"),
    "kicker::after": show(header && header.querySelector(".mc-kicker"), "::after"),
  };
  if (memoBanner) {
    out.decorations["memo banner ground"] = fill(memoBanner);
    out.decorations["memo band ground"] = memoBand ? fill(memoBand) : "missing";
  }
  parent.postMessage(JSON.stringify(out), "*");
}));
