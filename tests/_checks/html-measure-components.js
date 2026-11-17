// Measures of the components of an HTML page (callouts, tabsets, code, tables
// and block quotes), posted to the parent frame as JSON. Run by measure() in
// html.sh.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil
window.addEventListener("load", () => document.fonts.ready.then(() => {
  const out = { scheme: document.body.classList.contains("quarto-dark") ? "dark" : "light" };
  const shown = (el) => el.getClientRects().length > 0 && getComputedStyle(el).visibility !== "hidden";
  const intersects = (a, b) => a.right > b.left && a.left < b.right && a.bottom > b.top && a.top < b.bottom;

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
  // The colour behind an element: its background over those of its ancestors.
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
  const opacity = (el) => {
    let value = 1;
    for (let node = el; node && node.nodeType === 1; node = node.parentElement) {
      value *= Number(getComputedStyle(node).opacity);
    }
    return value;
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

  // Text colours of the components, with the colour behind them.
  const SAMPLES = [
    ["callout title", ".callout .callout-title-container"],
    ["callout body", ".callout .callout-body p"],
    ["callout", ".callout"],
    ["tab", ".panel-tabset .nav-tabs .nav-link"],
    ["tab panel", ".panel-tabset .tab-content > .active"],
    ["code window title", ".code-with-filename-file pre"],
    ["code block", "div.sourceCode pre"],
    ["code token", "div.sourceCode code span[class]"],
    ["inline code", "p code"],
    ["table cell", "main table td, main table th"],
    ["table caption", "main table caption, main .table-caption"],
    ["quote", "main figure.mc-quote blockquote p"],
    ["quote attribution", "main figure.mc-quote figcaption"],
  ];
  out.colours = [];
  for (const [label, selector] of SAMPLES) {
    for (const el of document.querySelectorAll(selector)) {
      if (!shown(el)) continue;
      const bg = background(el);
      const fg = over(parse(getComputedStyle(el).color).slice(0, 3).concat([opacity(el)]), bg);
      const text = (el.textContent || "").trim().slice(0, 24);
      // An active tab may be inverted (mono): its contrast counts, not its scheme.
      const name = label === "tab" && el.classList.contains("active") ? "active tab" : label;
      out.colours.push({ label: name, text, fg: hex(fg), bg: hex(bg), ratio: ratio(fg, bg), bgLuminance: luminance(bg) });
    }
  }

  // Each callout has a visible text title. A custom title hides the type in
  // a screen reader span, so the type must show another way: that span made
  // visible, or the icon glyph.
  const glyph = (callout) => {
    const container = callout.querySelector(".callout-icon-container");
    const icon = callout.querySelector(".callout-icon");
    if (!container || !icon || !shown(container)) return "";
    const style = getComputedStyle(icon, "::before");
    if (style.display === "none" || style.content === "none" || style.content === "normal") return "";
    return style.content;
  };
  out.callouts = [...document.querySelectorAll(".callout")].map((callout) => {
    const title = callout.querySelector(".callout-header .callout-title-container");
    const hidden = title && title.querySelector(".screen-reader-only");
    const typeText = hidden && hidden.getBoundingClientRect().width > 2 ? hidden.textContent.trim() : "";
    return {
      type: callout.className.match(/callout-(note|tip|warning|important|caution)/)[1],
      title: title && shown(title) ? title.innerText.trim() : "",
      custom: Boolean(hidden),
      typeShown: !hidden || Boolean(typeText) || /[^\s"\/]/.test(glyph(callout).replace(/\/ ?""$/, "")),
      typeText,
      glyph: glyph(callout),
    };
  });

  // Callout icons carry no text: no text node, and generated content with an
  // empty alternative text, or none.
  out.icons = [...document.querySelectorAll(".callout .callout-icon")].map((icon) => {
    const content = getComputedStyle(icon, "::before").content;
    const silent = content === "none" || content === "normal" || content === '""' || /\/ ?""$/.test(content);
    return { text: icon.textContent.trim(), content, silent };
  });

  // Text over the corner motif of a callout (its ::after box).
  out.motifOverlaps = [];
  out.motifs = 0;
  for (const callout of document.querySelectorAll(".callout")) {
    const style = getComputedStyle(callout, "::after");
    if (style.content === "none" || style.content === "normal" || style.display === "none") continue;
    out.motifs += 1;
    const box = callout.getBoundingClientRect();
    const width = parseFloat(style.width);
    const height = parseFloat(style.height);
    const top = box.top + parseFloat(style.top || 0);
    const right = box.right - parseFloat(style.right || 0);
    const rect = { left: right - width, right, top, bottom: top + height };
    const walker = document.createTreeWalker(callout, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const node = walker.currentNode;
      if (!node.textContent.trim() || !shown(node.parentElement)) continue;
      const range = document.createRange();
      range.selectNodeContents(node);
      for (const r of range.getClientRects()) {
        if (intersects(r, rect)) out.motifOverlaps.push(node.textContent.trim().slice(0, 30));
      }
    }
  }

  // Display of each decoration: a pseudo-element with no content is hidden.
  const show = (el, pseudo) => {
    if (!el) return "missing";
    const style = getComputedStyle(el, pseudo);
    return style.content === "none" || style.content === "normal" ? "none" : style.display;
  };
  out.decorations = {};
  const DECORATIONS = [
    ["callout::after", ".callout", "::after"],
    ["callout-title::before", ".callout .callout-title-container", "::before"],
    ["callout-title::after", ".callout .callout-title-container", "::after"],
    ["tab::before", ".panel-tabset .nav-link", "::before"],
    ["tab::after", ".panel-tabset .nav-link", "::after"],
    ["quote::before", "main figure.mc-quote", "::before"],
    ["quote::after", "main figure.mc-quote", "::after"],
    ["attribution::before", "main figure.mc-quote figcaption", "::before"],
  ];
  for (const [name, selector, pseudo] of DECORATIONS) {
    for (const el of document.querySelectorAll(selector)) {
      const value = show(el, pseudo);
      if (value !== "none") out.decorations[name] = value;
    }
  }
  // The active tab: its mark in forced colours, and the cues other than
  // colour that tell it from an inactive tab.
  const active = document.querySelector(".panel-tabset .nav-link.active");
  const inactive = document.querySelector(".panel-tabset .nav-link:not(.active)");
  if (active) {
    const style = getComputedStyle(active);
    out.activeTab = { decoration: style.textDecorationLine, border: style.borderBottomStyle + " " + style.borderBottomWidth };
  }
  out.activeCues = [];
  if (active && inactive) {
    const cue = (el) => {
      const s = getComputedStyle(el);
      const before = getComputedStyle(el, "::before");
      const after = getComputedStyle(el, "::after");
      return {
        weight: s.fontWeight,
        decoration: s.textDecorationLine,
        shadow: s.boxShadow,
        border: s.borderBottomStyle + " " + s.borderBottomWidth,
        before: before.content,
        after: after.content + " " + after.backgroundImage,
      };
    };
    const a = cue(active);
    const b = cue(inactive);
    out.activeCues = Object.keys(a).filter((key) => a[key] !== b[key]);
  }
  parent.postMessage(JSON.stringify(out), "*");
}));
