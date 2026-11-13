// Measures of the contents (nav#TOC), the sidebar (#quarto-sidebar), the
// narrow-screen contents pill and sheet, and the chapter header of an HTML
// page, posted to the parent frame as JSON. Run by measure() in html.sh, which
// sets window.mcMode to the mode of the measure: forced, print, reduced, rtl,
// dark or nothing.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil
const mcMeasure = () => {
  const mode = window.mcMode || "";
  const out = { mode, scheme: document.body.classList.contains("quarto-dark") ? "dark" : "light", width: window.innerWidth };
  const shown = (el) => Boolean(el) && el.getClientRects().length > 0 && getComputedStyle(el).visibility !== "hidden";

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
  const colour = (label, el) => {
    const bg = background(el);
    const fg = over(parse(getComputedStyle(el).color).slice(0, 3).concat([opacity(el)]), bg);
    return { label, text: (el.textContent || "").trim().slice(0, 24), fg: hex(fg), bg: hex(bg), ratio: ratio(fg, bg), bgLuminance: luminance(bg) };
  };

  // The cues other than colour that tell one element from another.
  const cues = (a, b) => {
    const cue = (el) => {
      const s = getComputedStyle(el);
      const before = getComputedStyle(el, "::before");
      const after = getComputedStyle(el, "::after");
      const visible = (p) => (p.content === "none" || p.content === "normal" || p.display === "none" ? "none" : p.content + " " + p.backgroundImage + " " + p.backgroundColor);
      return {
        weight: s.fontWeight,
        decoration: s.textDecorationLine,
        shadow: s.boxShadow,
        outline: s.outlineStyle === "none" ? "none" : s.outlineStyle + " " + s.outlineWidth,
        border: [s.borderInlineStartStyle, s.borderInlineStartWidth, s.borderBottomStyle].join(" "),
        before: visible(before),
        after: visible(after),
        background: s.backgroundColor,
      };
    };
    const x = cue(a);
    const y = cue(b);
    return Object.keys(x).filter((key) => x[key] !== y[key]);
  };
  // A mark of the current entry that survives forced colours: an outline, a
  // border, an underline or a visible generated marker.
  const forcedMark = (el) => {
    const s = getComputedStyle(el);
    const before = getComputedStyle(el, "::before");
    const marker = before.content !== "none" && before.content !== "normal" && before.display !== "none";
    return {
      outline: s.outlineStyle !== "none" && parseFloat(s.outlineWidth) >= 1,
      border: s.borderInlineStartStyle !== "none" && parseFloat(s.borderInlineStartWidth) >= 2,
      underline: s.textDecorationLine.includes("underline"),
      marker,
      weight: Number(s.fontWeight) >= 600,
    };
  };
  // The focus ring of an element: its outline, and its contrast with the
  // colour behind the element.
  const ring = (el) => {
    el.focus({ focusVisible: true });
    const s = getComputedStyle(el);
    const outline = parse(s.outlineColor);
    const behind = background(el.parentElement);
    const result = {
      style: s.outlineStyle,
      width: parseFloat(s.outlineWidth),
      colour: hex(outline),
      behind: hex(behind),
      ratio: ratio(over(outline, behind), behind),
      focused: document.activeElement === el,
    };
    el.blur();
    return result;
  };
  const durations = (el, pseudo) => {
    if (!el) return [];
    const s = getComputedStyle(el, pseudo);
    return s.transitionDuration.split(",").concat(s.animationDuration.split(",")).map((v) => parseFloat(v) || 0);
  };
  // Contents.
  const toc = document.querySelector("nav#TOC");
  if (toc) {
    const column = toc.closest("#quarto-margin-sidebar") || toc.parentElement;
    const cs = getComputedStyle(column);
    out.toc = {
      shown: shown(toc),
      label: toc.querySelector("#toc-title") && shown(toc.querySelector("#toc-title")) ? toc.querySelector("#toc-title").innerText.trim() : "",
      position: cs.position,
      overflowY: cs.overflowY,
      maxHeight: cs.maxHeight,
      overflowX: toc.scrollWidth > toc.clientWidth + 1,
      printDisplay: [getComputedStyle(column).display, getComputedStyle(toc).display],
    };
    const links = [...toc.querySelectorAll(":scope > ul a.nav-link")];
    // Indent of an entry from the start edge of the contents, from the
    // computed styles, so that it holds for the levels Quarto keeps closed.
    const indent = (a) => {
      let value = 0;
      for (let node = a; node && node !== toc; node = node.parentElement) {
        const st = getComputedStyle(node);
        value += parseFloat(st.paddingInlineStart) + parseFloat(st.marginInlineStart) + (node === a ? 0 : parseFloat(st.borderInlineStartWidth));
      }
      return Math.round(value);
    };
    out.toc.entries = links.map((a) => {
      const rect = a.getBoundingClientRect();
      const lineHeight = parseFloat(getComputedStyle(a).lineHeight) || 16;
      let depth = 0;
      for (let node = a.parentElement; node && node !== toc; node = node.parentElement) {
        if (node.tagName === "UL") depth += 1;
      }
      return {
        text: a.textContent.trim().replace(/\s+/g, " ").slice(0, 40),
        depth,
        shown: shown(a),
        indent: indent(a),
        lines: shown(a) ? Math.round(rect.height / lineHeight) : 0,
        overflow: a.scrollWidth > a.clientWidth + 1,
      };
    });
    const current = toc.querySelector("a.nav-link.active");
    const other = links.find((a) => a !== current && shown(a));
    out.toc.current = current
      ? { text: current.innerText.trim().slice(0, 40), ariaCurrent: current.getAttribute("aria-current"), cues: other ? cues(current, other) : [], forced: forcedMark(current) }
      : null;
    out.colours = links.filter(shown).map((a) => colour(a === current ? "current entry" : "entry", a));
    const title = toc.querySelector("#toc-title");
    if (shown(title)) out.colours.push(colour("contents label", title));
    const actions = [...document.querySelectorAll("#quarto-margin-sidebar :is(.quarto-other-links, .toc-actions, .quarto-code-links) a")].filter(shown);
    out.toc.actions = actions.length;
    actions.forEach((a) => out.colours.push(colour("action", a)));
    if (other) {
      other.dispatchEvent(new MouseEvent("mouseover", { bubbles: true }));
      out.toc.ring = ring(other);
    }
    out.toc.motion = durations(links[0]).concat(durations(current, "::after"));
  }

  // Sidebar.
  const sidebar = document.querySelector("#quarto-sidebar");
  if (sidebar) {
    const cs = getComputedStyle(sidebar);
    out.sidebar = {
      shown: shown(sidebar) && sidebar.getBoundingClientRect().width > 40,
      printDisplay: cs.display,
      toggles: [...sidebar.querySelectorAll(".sidebar-item-toggle, .sidebar-item-section button")].map((b) => ({
        tag: b.tagName,
        expanded: b.getAttribute("aria-expanded"),
        controls: b.getAttribute("aria-controls"),
        target: Boolean(b.getAttribute("aria-controls") && document.getElementById(b.getAttribute("aria-controls"))),
        marker: (() => {
          const icon = b.querySelector(".bi") || b;
          const s = getComputedStyle(icon, "::before");
          return s.content;
        })(),
      })),
    };
    const links = [...sidebar.querySelectorAll("a.sidebar-link")];
    const current = sidebar.querySelector("a.sidebar-link.active");
    const other = links.find((a) => a !== current && shown(a));
    out.sidebar.current = current
      ? { text: current.innerText.trim().slice(0, 40), ariaCurrent: current.getAttribute("aria-current"), cues: other && shown(current) ? cues(current, other) : [], forced: forcedMark(current) }
      : null;
    if (shown(sidebar)) {
      out.sidebar.colours = links.filter(shown).map((a) => colour(a === current ? "current page" : "page", a));
      const title = sidebar.querySelector(".sidebar-title a");
      if (shown(title)) out.sidebar.colours.push(colour("sidebar title", title));
      sidebar.querySelectorAll(".sidebar-item-section button .menu-text").forEach((t) => shown(t) && out.sidebar.colours.push(colour("part header", t)));
      if (other) out.sidebar.ring = ring(other);
    }
    const toggle = sidebar.querySelector(".sidebar-item-toggle");
    out.sidebar.motion = durations(sidebar).concat(durations(toggle && toggle.querySelector(".bi"), "::before"));
  }

  // Menu button of the sidebar drawer, below 992 pixels.
  const menu = document.querySelector(".quarto-secondary-nav .quarto-btn-toggle");
  if (menu) {
    const rect = menu.getBoundingClientRect();
    out.menu = { shown: shown(menu), width: rect.width, height: rect.height, expanded: menu.getAttribute("aria-expanded") };
    if (shown(menu)) out.menuColour = colour("menu button", menu);
  }

  // Scroll offset of anchors under the fixed header.
  const header = document.querySelector("#quarto-header");
  out.scroll = {
    paddingTop: parseFloat(getComputedStyle(document.documentElement).scrollPaddingTop) || 0,
    headingMargin: parseFloat(getComputedStyle(document.querySelector("main h2, main h3") || document.body).scrollMarginTop) || 0,
    header: header && getComputedStyle(header).position === "fixed" ? header.getBoundingClientRect().height : 0,
  };

  // Chapter header of a full report. The text of a link, with its spaces
  // collapsed: a grid layout puts a line break between number and title.
  const linkText = (a) => a.textContent.replace(/\s+/g, " ").trim();
  const chapter = document.querySelector(".mc-chapter-contents");
  if (chapter) {
    out.chapter = {
      label: ((chapter.querySelector(".mc-chapter-contents-title") || {}).textContent || "").trim(),
      links: [...chapter.querySelectorAll("a")].map(linkText),
      kicker: ((document.querySelector(".mc-kicker") || {}).textContent || "").trim(),
    };
    out.chapter.colours = [...chapter.querySelectorAll("a, .mc-chapter-contents-title")].filter(shown).map((el) => colour("chapter contents", el));
    out.chapters = [...document.querySelectorAll(".mc-chapter-contents")].map((nav) => [...nav.querySelectorAll("a")].map(linkText));
  }

  // Narrow screens: the pill and the sheet of mobile-toc.
  const pill = document.querySelector(".mobile-toc-pill");
  out.pills = [...document.querySelectorAll(".mobile-toc-pill, .quarto-toc-pill")].filter(shown).map((p) => p.className);
  const finish = () => parent.postMessage(JSON.stringify(out), "*");
  if (pill && shown(pill)) {
    const rect = pill.getBoundingClientRect();
    out.pill = { height: rect.height, width: rect.width, colour: colour("pill", pill), label: pill.innerText.trim(), bottom: window.innerHeight - rect.bottom };
    pill.click();
    setTimeout(() => {
      const sheet = document.querySelector(".mobile-toc-sheet");
      if (sheet && shown(sheet)) {
        const box = sheet.getBoundingClientRect();
        const current = sheet.querySelector("a[aria-current]") || sheet.querySelector("a.active");
        const other = [...sheet.querySelectorAll("a")].find((a) => a !== current);
        out.sheet = {
          heightShare: box.height / window.innerHeight,
          colours: [...sheet.querySelectorAll("a, .mobile-toc-sheet-label")].map((el) => colour(el === current ? "sheet current" : "sheet entry", el)),
          close: Boolean(sheet.querySelector(".mobile-toc-close")),
          current: current ? { ariaCurrent: current.getAttribute("aria-current"), cues: other ? cues(current, other) : [] } : null,
          motion: durations(sheet),
        };
      }
      finish();
    }, 400);
  } else if (menu && shown(menu) && mode === "open") {
    menu.click();
    setTimeout(() => {
      const s = document.querySelector("#quarto-sidebar");
      out.drawer = { shown: shown(s) && s.getBoundingClientRect().width > 40, expanded: menu.getAttribute("aria-expanded") };
      if (out.drawer.shown) {
        out.drawer.colours = [...s.querySelectorAll("a.sidebar-link")].filter(shown).map((a) => colour("drawer page", a));
      }
      finish();
    }, 900);
  } else {
    finish();
  }
};
window.addEventListener("load", () => document.fonts.ready.then(mcMeasure));
