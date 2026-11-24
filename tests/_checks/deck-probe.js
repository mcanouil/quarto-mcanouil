/**
 * mcanouil - deck probe for the check hooks
 * Visits the slides named in window.MC_PROBE_SLIDES, after the fonts load, and
 * writes one line per measure into a pre element with the id mc-probe:
 * - "<slide> shape x0 y0 x1 y1": the box of a motif shape, in slide pixels.
 * - "<slide> text x0 y0 x1 y1": a line box of text, or an image, in slide pixels.
 * - "<slide> slide|number|title|body x0 y0 x1 y1": on a section slide, the box
 *   of the slide, of the number, of the title with its rule, and of each other
 *   child that is not the motif, in slide pixels.
 * - "<slide> colour <name> <ratio> <threshold>": the lowest contrast ratio of
 *   an element on its effective background, and the ratio it needs. A name
 *   that ends in "-ring" is the focus ring of a control, read with the control
 *   focused, against the background around the control; a control with no
 *   ring reads 0.
 * - The page is read in the print layout of a PDF export when its URL has
 *   ?print-pdf; the slides are then paged as Reveal.js pages them.
 * - "<slide> codewindow key=value ...": the facts of each code window, see
 *   code_window_matches in lib.sh.
 * - "<slide> corner <top> <right>": on a ground slide, the gap between the box
 *   of the motif and the top right corner of the window, in window pixels.
 * - "<slide> page-corner <top> <right>": the same gap to the top right corner
 *   of the page of the slide in the print layout of a PDF export.
 * - "<slide> calloutlabel <offset> <ring-gap>": for each callout title, the
 *   middle of the capital letters of the label minus the middle of the icon,
 *   and the difference between the icon box and its ring, in slide pixels.
 * - "<slide> error <message>": the probe failed on the slide.
 *
 * @license MIT
 * @copyright 2026 Mickaël Canouil
 * @author Mickaël Canouil
 */
(function () {
  "use strict";

  var lines = [];

  function parseColours(text) {
    var found = [];
    var pattern = /rgba?\(([^)]+)\)|color\(srgb ([^)]+)\)/g;
    var match;
    while ((match = pattern.exec(text || "")) !== null) {
      if (match[1] !== undefined) {
        var parts = match[1].split(/[\s,/]+/).filter(Boolean).map(Number);
        found.push([parts[0] / 255, parts[1] / 255, parts[2] / 255, parts.length > 3 ? parts[3] : 1]);
      } else {
        var srgb = match[2].split(/[\s/]+/).filter(Boolean).map(Number);
        found.push([srgb[0], srgb[1], srgb[2], srgb.length > 3 ? srgb[3] : 1]);
      }
    }
    return found;
  }

  function over(top, bottom) {
    var alpha = top[3];
    return [
      top[0] * alpha + bottom[0] * (1 - alpha),
      top[1] * alpha + bottom[1] * (1 - alpha),
      top[2] * alpha + bottom[2] * (1 - alpha),
      1,
    ];
  }

  function luminance(colour) {
    function channel(value) {
      return value <= 0.03928 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
    }
    return 0.2126 * channel(colour[0]) + 0.7152 * channel(colour[1]) + 0.0722 * channel(colour[2]);
  }

  function ratio(a, b) {
    var x = luminance(a);
    var y = luminance(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
  }

  // Colours of a computed background: the gradient stops, else the colour.
  function paints(style) {
    var stops = style.backgroundImage && style.backgroundImage !== "none" ? parseColours(style.backgroundImage) : [];
    var colour = parseColours(style.backgroundColor)[0];
    if (stops.length > 0) {
      return stops.map(function (stop) { return colour && colour[3] > 0 ? over(stop, over(colour, [1, 1, 1, 1])) : stop; });
    }
    return colour && colour[3] > 0 ? [colour] : [];
  }

  // Opaque colours behind the current slide: its Reveal.js background, where
  // Reveal.js sets the gradient or the colour, or its content layer; else the
  // viewport.
  function slideBases() {
    var innermost = Reveal.getSlideBackground(Reveal.getCurrentSlide());
    var content = innermost ? innermost.querySelector(":scope > .slide-background-content") : null;
    var found = innermost ? paints(getComputedStyle(innermost)) : [];
    var image = content ? paints(getComputedStyle(content)) : [];
    if (image.length > 0) {
      found = image;
    }
    if (found.length === 0 || found.every(function (c) { return c[3] === 0; })) {
      found = paints(getComputedStyle(document.body));
    }
    return found.map(function (c) { return c[3] < 1 ? over(c, [1, 1, 1, 1]) : c; });
  }

  // Backgrounds between the slide and an element, outermost first.
  function layers(element, stop) {
    var chain = [];
    for (var node = element; node && node !== stop && node !== document.body; node = node.parentElement) {
      chain.unshift(node);
    }
    return chain;
  }

  function measureColour(slide, name, element, pseudo, kind) {
    var style = getComputedStyle(element, pseudo || null);
    if (pseudo && kind === "text" && /^(none|normal|""( \/ "")?)$/.test(style.content)) { return; }
    if (style.display === "none" || style.visibility === "hidden") { return; }
    var rect = element.getBoundingClientRect();
    if (!pseudo && (rect.width === 0 || rect.height === 0)) { return; }
    var section = element.closest(".reveal .slides section");
    var backgrounds = slideBases();
    var fill = parseColours(style.webkitTextFillColor)[0];
    var clipped = fill && fill[3] === 0;
    layers(element, section ? section.parentElement : null).forEach(function (node) {
      if (node === element && ((!pseudo && clipped) || kind === "ring")) { return; }
      var own = paints(getComputedStyle(node));
      if (own.length === 0) { return; }
      var next = [];
      backgrounds.forEach(function (base) { own.forEach(function (paint) { next.push(over(paint, base)); }); });
      backgrounds = next;
    });
    var foregrounds;
    if (kind === "ring") {
      var drawn = style.outlineStyle !== "none" && parseFloat(style.outlineWidth) > 0;
      foregrounds = drawn ? parseColours(style.outlineColor) : [[0, 0, 0, 0]];
    } else if (kind === "mark") {
      foregrounds = parseColours(style.backgroundColor);
    } else {
      if (pseudo) {
        var pseudoPaint = paints(style);
        if (pseudoPaint.length > 0) {
          var stacked = [];
          backgrounds.forEach(function (base) { pseudoPaint.forEach(function (paint) { stacked.push(over(paint, base)); }); });
          backgrounds = stacked;
        }
      }
      foregrounds = clipped ? paints(style) : parseColours(style.color);
    }
    var lowest = Infinity;
    backgrounds.forEach(function (base) {
      foregrounds.forEach(function (fg) {
        lowest = fg[3] === 0 ? 0 : Math.min(lowest, ratio(fg[3] < 1 ? over(fg, base) : fg, base));
      });
    });
    var size = parseFloat(style.fontSize);
    var bold = parseInt(style.fontWeight, 10) >= 700;
    var threshold = kind === "mark" || kind === "ring" || size >= 24 || (bold && size >= 18.66) ? 3 : 4.5;
    lines.push([slide, "colour", name, lowest.toFixed(2), threshold].join(" "));
  }

  function measureBoxes(slide, section) {
    var scale = printing() ? 1 : Reveal.getScale();
    var origin = section.getBoundingClientRect();
    function add(name, rect) {
      lines.push([slide, name, (rect.left - origin.left) / scale, (rect.top - origin.top) / scale,
        (rect.right - origin.left) / scale, (rect.bottom - origin.top) / scale].join(" "));
    }
    section.querySelectorAll(".mc-motif path, .mc-motif rect, .mc-motif circle").forEach(function (shape) {
      add("shape", shape.getBoundingClientRect());
    });
    var walker = document.createTreeWalker(section, NodeFilter.SHOW_TEXT);
    for (var node = walker.nextNode(); node; node = walker.nextNode()) {
      if (!node.textContent.trim() || node.parentElement.closest("svg")) { continue; }
      var range = document.createRange();
      range.selectNodeContents(node);
      Array.prototype.forEach.call(range.getClientRects(), function (rect) {
        if (rect.width > 0 && rect.height > 0) { add("text", rect); }
      });
    }
    section.querySelectorAll("img").forEach(function (image) { add("text", image.getBoundingClientRect()); });
    if (section.classList.contains("mc-section")) {
      add("slide", section.getBoundingClientRect());
      Array.prototype.forEach.call(section.children, function (child) {
        if (child.classList.contains("mc-motif")) { return; }
        var role = child.classList.contains("mc-section-number") ? "number" : child.tagName === "H1" ? "title" : "body";
        add(role, child.getBoundingClientRect());
      });
    }
  }

  // Focus a control as a keyboard user would, and read its focus ring.
  function measureRing(slide, name, element) {
    element.focus({ focusVisible: true });
    if (!element.matches(":focus-visible")) {
      lines.push([slide, "error", name + "_not_focus_visible"].join(" "));
      return;
    }
    measureColour(slide, name, element, null, "ring");
    element.blur();
  }

  // Facts of a code window, as "key=value" words that code_window_matches in
  // lib.sh compares with the look of the preset. A colour is named by every
  // token it equals, joined with "+". The same function is in
  // html-measure-components.js.
  function codeWindowFacts(win) {
    var bar = win.querySelector(".code-with-filename-file");
    var code = win.querySelector("div.sourceCode pre");
    function token(name) {
      var probe = document.createElement("span");
      probe.style.color = "var(--mc-" + name + ")";
      win.appendChild(probe);
      var colour = getComputedStyle(probe).color;
      probe.remove();
      return colour;
    }
    function named(colour, names) {
      return names.filter(function (name) { return token(name) === colour; }).join("+") || "other";
    }
    var behind = "none";
    for (var node = code; node && node !== win.parentElement; node = node.parentElement) {
      var colour = getComputedStyle(node).backgroundColor;
      if (colour !== "rgba(0, 0, 0, 0)" && colour !== "transparent") {
        behind = colour;
        break;
      }
    }
    var frame = getComputedStyle(win);
    var title = getComputedStyle(bar);
    var deco = getComputedStyle(bar, "::before");
    return [
      "deco=" + (deco.content !== "none" && /url\(/.test(deco.backgroundImage) ? 1 : 0),
      "icon=" + (parseFloat(deco.height) / parseFloat(title.fontSize)).toFixed(2),
      "border=" + [
        parseFloat(frame.borderTopWidth),
        parseFloat(frame.borderLeftWidth),
        frame.borderTopStyle,
        named(frame.borderTopColor, ["line", "ink", "accent"]),
      ].join("/"),
      "radius=" + parseFloat(frame.borderTopLeftRadius),
      "shadow=" + (frame.boxShadow === "none" ? 0 : 1),
      "title-edge=" + title.borderBottomStyle,
      "gilded=" + (/gradient/.test(title.backgroundImage) ? 1 : 0),
      "body=" + named(behind, ["tint", "card"]),
    ].join(" ");
  }

  function measureCorner(slide, section) {
    var motif = section.querySelector(":scope > .mc-motif");
    if (!motif) { return; }
    var rect = motif.getBoundingClientRect();
    var box = (section.closest(".pdf-page") || section).getBoundingClientRect();
    lines.push([slide, "corner", rect.top, window.innerWidth - rect.right].join(" "));
    lines.push([slide, "page-corner", rect.top - box.top, box.right - rect.right].join(" "));
  }

  // Canvas metrics of "H" in the label font give the cap height and the
  // ascent above the baseline; the first line box of the label gives the
  // baseline. The icon box is the ring only when the ring gap is 0.
  function measureCalloutLabels(slide, section) {
    var scale = printing() ? 1 : Reveal.getScale();
    section.querySelectorAll(".callout .callout-title").forEach(function (title) {
      var icon = title.querySelector(".callout-icon");
      var label = title.querySelector("p");
      if (!icon || !label) { return; }
      var walker = document.createTreeWalker(label, NodeFilter.SHOW_TEXT);
      var node = walker.nextNode();
      while (node && !(node.textContent.trim() && !node.parentElement.closest(".screen-reader-only"))) {
        node = walker.nextNode();
      }
      if (!node) { return; }
      var range = document.createRange();
      range.selectNodeContents(node);
      var line = range.getClientRects()[0];
      if (!line) { return; }
      var context = document.createElement("canvas").getContext("2d");
      context.font = getComputedStyle(node.parentElement).font;
      var metrics = context.measureText("H");
      var ring = icon.getBoundingClientRect();
      var ringStyle = getComputedStyle(icon, "::before");
      var ringSize = parseFloat(ringStyle.height);
      if (ringStyle.boxSizing === "content-box") {
        ringSize += parseFloat(ringStyle.borderTopWidth) + parseFloat(ringStyle.borderBottomWidth) +
          parseFloat(ringStyle.paddingTop) + parseFloat(ringStyle.paddingBottom);
      }
      var capMiddle = line.top / scale + metrics.fontBoundingBoxAscent - metrics.actualBoundingBoxAscent / 2;
      var ringMiddle = (ring.top + ring.height / 2) / scale;
      lines.push([slide, "calloutlabel", (capMiddle - ringMiddle).toFixed(2),
        Math.abs(ring.height / scale - ringSize).toFixed(2)].join(" "));
    });
  }

  function measureSlide(slide) {
    var section = document.getElementById(slide);
    measureBoxes(slide, section);
    measureCorner(slide, section);
    measureCalloutLabels(slide, section);
    var targets = [
      [".mc-kicker", null, "text"],
      [".mc-section-number", null, "text"],
      ["figure.mc-quote", "::before", "text"],
      ["figcaption.mc-quote-attribution", "::before", "text"],
      ["figcaption.mc-quote-attribution", null, "text"],
      [".mc-ws-label", null, "text"],
      [".code-with-filename-file>pre", null, "text"],
      ["code.sourceCode>span,code.sourceCode>span>span", null, "text"],
    ];
    targets.forEach(function (target) {
      section.querySelectorAll(target[0]).forEach(function (element) {
        measureColour(slide, target[0] + (target[1] || ""), element, target[1], target[2]);
      });
    });
    var footer = document.querySelector(".reveal > .footer.mc-footer");
    if (footer && getComputedStyle(footer).display !== "none") {
      footer.querySelectorAll(".mc-slot").forEach(function (slot) {
        var position = (slot.className.match(/mc-slot-(left|centre|right)/) || [null, "slot"])[1];
        if (slot.textContent.trim()) { measureColour(slide, "footer-" + position, slot, null, "text"); }
      });
    }
    var number = document.querySelector(".reveal .slide-number");
    if (number && getComputedStyle(number).display !== "none" && number.textContent.trim()) {
      measureColour(slide, "slide-number", number, null, "text");
    }
    var menu = document.querySelector(".reveal .slide-menu-button .fa-bars");
    if (menu && getComputedStyle(menu.closest(".slide-menu-button")).display !== "none") {
      measureColour(slide, "menu-button", menu, "::before", "mark");
      measureRing(slide, "menu-button-ring", menu.closest("a"));
    }
    var numberLink = document.querySelector(".reveal .slide-number a");
    if (numberLink && getComputedStyle(number).display !== "none") {
      measureRing(slide, "slide-number-ring", numberLink);
    }
    section.querySelectorAll(".code-with-filename").forEach(function (win) {
      lines.push([slide, "codewindow", codeWindowFacts(win)].join(" "));
    });
    section.querySelectorAll("a[href]").forEach(function (link) {
      measureRing(slide, "link-ring", link);
    });
  }

  function next(slides) {
    if (slides.length === 0) {
      var out = document.createElement("pre");
      out.id = "mc-probe";
      out.textContent = lines.join("\n");
      document.body.appendChild(out);
      return;
    }
    var slide = slides[0];
    // The print layout shows every slide at once, so it is measured with no
    // timer; a slide in the presentation layout is measured once Reveal.js has
    // moved to it.
    if (printing()) {
      measure(slide);
      next(slides.slice(1));
      return;
    }
    var indices = Reveal.getIndices(document.getElementById(slide));
    Reveal.slide(indices.h, indices.v);
    setTimeout(function () {
      measure(slide);
      next(slides.slice(1));
    }, 300);
  }

  function measure(slide) {
    try {
      measureSlide(slide);
    } catch (error) {
      lines.push([slide, "error", String(error).replace(/\s+/g, "_")].join(" "));
    }
  }

  function printing() {
    return /[?&]print-pdf/.test(location.search);
  }

  // Reveal.js lays out a PDF export in animation frames, and a headless browser
  // run on virtual time never draws them. Do what it does to each slide: put it
  // in a page of the slide height, with the slide width and no offset.
  function paginate() {
    var width = Reveal.getConfig().width;
    var height = Reveal.getConfig().height;
    if (document.querySelector(".pdf-page")) { return; }
    document.querySelectorAll(".reveal .slides section:not(.stack)").forEach(function (slide) {
      var page = document.createElement("div");
      page.className = "pdf-page";
      page.style.height = height + "px";
      slide.parentNode.insertBefore(page, slide);
      page.appendChild(slide);
      slide.style.left = "0px";
      slide.style.top = "0px";
      slide.style.width = width + "px";
    });
    void document.body.offsetHeight;
  }

  function wait() {
    if (window.Reveal && Reveal.isReady()) {
      document.fonts.ready.then(function () {
        if (printing()) {
          paginate();
          // The print layout shows every slide at once, so fonts of the
          // slides load only after the first layout.
          return document.fonts.ready;
        }
      }).then(function () { next(window.MC_PROBE_SLIDES.slice()); });
    } else {
      setTimeout(wait, 50);
    }
  }
  wait();
})();
