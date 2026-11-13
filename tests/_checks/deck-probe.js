/**
 * mcanouil - deck probe for the check hooks
 * Visits the slides named in window.MC_PROBE_SLIDES, after the fonts load, and
 * writes one line per measure into a pre element with the id mc-probe:
 * - "<slide> shape x0 y0 x1 y1": the box of a motif shape, in slide pixels.
 * - "<slide> text x0 y0 x1 y1": a line box of text, or an image, in slide pixels.
 * - "<slide> colour <name> <ratio> <threshold>": the lowest contrast ratio of
 *   an element on its effective background, and the ratio it needs. A name
 *   that ends in "-ring" is the focus ring of a control, read with the control
 *   focused, against the background around the control; a control with no
 *   ring reads 0.
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
    var scale = Reveal.getScale();
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

  function measureSlide(slide) {
    var section = document.getElementById(slide);
    measureBoxes(slide, section);
    var targets = [
      [".mc-kicker", null, "text"],
      [".mc-section-number", null, "text"],
      ["figure.mc-quote", "::before", "text"],
      ["figcaption.mc-quote-attribution", "::before", "text"],
      ["figcaption.mc-quote-attribution", null, "text"],
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
    var indices = Reveal.getIndices(document.getElementById(slide));
    Reveal.slide(indices.h, indices.v);
    setTimeout(function () {
      try {
        measureSlide(slide);
      } catch (error) {
        lines.push([slide, "error", String(error).replace(/\s+/g, "_")].join(" "));
      }
      next(slides.slice(1));
    }, 300);
  }

  function wait() {
    if (window.Reveal && Reveal.isReady()) {
      document.fonts.ready.then(function () { next(window.MC_PROBE_SLIDES.slice()); });
    } else {
      setTimeout(wait, 50);
    }
  }
  wait();
})();
