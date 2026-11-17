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
  parent.postMessage(JSON.stringify(out), "*");
}));
