/**
 * MCanouil Reveal.js Plugin
 *
 * A comprehensive Reveal.js plugin providing:
 * - Section slide detection and outline generation
 * - Date superscript formatting (1st, 2nd, 3rd)
 * - Favicon generation from slide logo
 * - Code annotation fragment synchronisation
 * - Menu/logo visibility on title slide
 *
 * @author Mickaël Canouil
 * @license MIT
 * @version 1.0.0
 */

window.RevealJsMCanouil = function () {
  "use strict";

  // Default configuration
  const defaults = {
    // Feature toggles
    sectionOutline: true,
    dateSuperscript: true,
    faviconFromLogo: true,
    codeAnnotations: true, // Enable fragment navigation through code annotations
    menuLogoVisibility: true,
    debugBorders: false, // Show coloured borders on slides for overflow debugging
    // Section slide options
    sectionSlideStyle: "banner",
    // Colour customisation (null = use brand.yml colours via CSS custom properties)
    // Override these to use custom colours instead of brand-derived values
    sectionBackground: null,
    sectionForeground: null,
    outlineBorderColor: null,
  };

  let config = {};

  /**
   * Convert kebab-case string to camelCase.
   * @param {string} str - Kebab-case string (e.g., "debug-borders")
   * @returns {string} CamelCase string (e.g., "debugBorders")
   */
  function kebabToCamel(str) {
    return str.replace(/-([a-z])/g, function (_match, letter) {
      return letter.toUpperCase();
    });
  }

  /**
   * Normalise config object keys from kebab-case to camelCase.
   * Allows users to specify options in YAML-friendly format.
   * @param {Object} obj - Config object with potentially kebab-case keys
   * @returns {Object} Config object with camelCase keys
   */
  function normaliseConfig(obj) {
    var result = {};
    Object.keys(obj).forEach(function (key) {
      var camelKey = kebabToCamel(key);
      result[camelKey] = obj[key];
    });
    return result;
  }

  return {
    id: "mcanouil-revealjs",

    init: function (deck) {
      // Merge user config with defaults
      // Check both plugin namespace and top-level config for user options
      // This allows users to specify options directly under the format:
      //   format:
      //     mcanouil-revealjs:
      //       debug-borders: true
      // Or under the plugin namespace:
      //   format:
      //     mcanouil-revealjs:
      //       mcanouil-revealjs:
      //         debug-borders: true
      const deckConfig = deck.getConfig();
      const pluginConfig = normaliseConfig(deckConfig["mcanouil-revealjs"] || {});

      // Extract relevant top-level options (those matching our defaults)
      const topLevelConfig = {};
      Object.keys(defaults).forEach(function (key) {
        // Check camelCase version
        if (deckConfig[key] !== undefined) {
          topLevelConfig[key] = deckConfig[key];
        }
        // Check kebab-case version
        const kebabKey = key.replace(/([A-Z])/g, function (match) {
          return "-" + match.toLowerCase();
        });
        if (deckConfig[kebabKey] !== undefined) {
          topLevelConfig[key] = deckConfig[kebabKey];
        }
      });

      // Merge: defaults < plugin namespace < top-level
      // Top-level options take precedence (what user writes directly under format)
      config = { ...defaults, ...pluginConfig, ...topLevelConfig };

      // Apply colour customisations via CSS custom properties
      applyColourCustomisation(config);

      // Set up event listeners
      deck.on("ready", function () {
        if (config.sectionOutline) {
          processSectionSlides(deck, config);
        }
        if (config.dateSuperscript) {
          formatDates();
        }
        if (config.faviconFromLogo) {
          setFaviconFromLogo();
        }
        if (config.menuLogoVisibility) {
          updateMenuVisibility(deck.getIndices());
        }
        if (config.codeAnnotations) {
          setupCodeAnnotationFragments();
        }
        if (config.debugBorders) {
          applyDebugBorders();
        }
      });

      if (config.codeAnnotations) {
        deck.on("fragmentshown", function (event) {
          onAnnotationFragmentShown(event);
        });
        deck.on("fragmenthidden", function (event) {
          onAnnotationFragmentHidden(event);
        });
      }

      if (config.menuLogoVisibility) {
        deck.on("slidechanged", function (event) {
          updateMenuVisibility(event);
        });
      }
    },
  };

  // =========================================================================
  // COLOUR CUSTOMISATION
  // =========================================================================

  /**
   * Apply colour configuration as CSS custom properties on :root
   * @param {Object} config - Plugin configuration
   */
  function applyColourCustomisation(config) {
    const root = document.documentElement;
    if (config.sectionBackground) {
      root.style.setProperty("--mcanouil-section-bg", config.sectionBackground);
    }
    if (config.sectionForeground) {
      root.style.setProperty("--mcanouil-section-fg", config.sectionForeground);
    }
    if (config.outlineBorderColor) {
      root.style.setProperty(
        "--mcanouil-outline-border",
        config.outlineBorderColor
      );
    }
  }

  // =========================================================================
  // SECTION SLIDES
  // =========================================================================

  /**
   * Check if a section element has a direct h1 child (not inherited from nested sections)
   * @param {Element} section - Section element to check
   * @returns {Element|null} The h1 element if found as direct child, null otherwise
   */
  function getDirectH1(section) {
    for (let i = 0; i < section.children.length; i++) {
      const child = section.children[i];
      if (child.tagName === "H1") {
        return child;
      }
    }
    return null;
  }

  /**
   * Process section slides (level-1 headings) and add styling/outlines
   * Handles both flat and nested (vertical stack) Quarto slide structures
   * @param {Object} deck - Reveal.js deck instance
   * @param {Object} config - Plugin configuration
   */
  function processSectionSlides(deck, config) {
    // Get all sections (both top-level and nested)
    const allSections = document.querySelectorAll(".reveal .slides section");

    // First pass: identify and mark all section slides (those with direct h1)
    const sectionSlides = [];
    allSections.forEach(function (section) {
      // Skip title slide
      if (section.classList.contains("quarto-title-block") ||
        section.classList.contains("mcanouil-title-slide")) {
        return;
      }

      // Check for direct h1 child (not nested in another element)
      const h1 = getDirectH1(section);
      if (h1) {
        sectionSlides.push({ section: section, h1: h1 });

        // Add section slide classes
        section.classList.add("section-slide");
        section.classList.add("section-style-" + config.sectionSlideStyle);

        // Section slide styling is handled entirely by CSS via .section-slide class
        // Background and foreground colours are derived from brand.yml via SCSS variables

        // For banner style, wrap heading in banner div
        if (config.sectionSlideStyle === "banner") {
          wrapInBanner(section, h1);
        }
      }
    });

    // Second pass: generate outlines for section slides
    if (config.sectionOutline) {
      sectionSlides.forEach(function (sectionData) {
        const subsections = collectSubsections(sectionData.section);
        if (subsections.length > 0) {
          addSectionOutline(sectionData.section, subsections);
        }
      });
    }
  }

  /**
   * Wrap heading in banner structure for banner style
   * @param {Element} slide - Slide element
   * @param {Element} heading - H1 heading element
   */
  function wrapInBanner(slide, heading) {
    // Check if already wrapped
    if (heading.parentElement.classList.contains("section-banner")) {
      return;
    }

    // Create banner wrapper
    const banner = document.createElement("div");
    banner.className = "section-banner";

    // Insert banner at start of slide, then move heading into it
    // Using move semantics avoids DOM duplication and accessibility issues
    slide.insertBefore(banner, slide.firstChild);
    banner.appendChild(heading);
  }

  /**
   * Collect subsections (h2 headings) from sibling slides until next section
   * Handles both nested (vertical stack) and flat structures
   * @param {Element} sectionSlide - The section slide element
   * @returns {Array} Array of subsection objects with text and id
   */
  function collectSubsections(sectionSlide) {
    const subsections = [];
    const parent = sectionSlide.parentElement;

    // Check if this is inside a vertical stack (parent is also a section)
    if (parent && parent.tagName === "SECTION") {
      // Nested structure: collect h2s from sibling sections within the stack
      let foundCurrent = false;
      for (let i = 0; i < parent.children.length; i++) {
        const sibling = parent.children[i];
        if (sibling === sectionSlide) {
          foundCurrent = true;
          continue;
        }
        if (!foundCurrent) continue;
        if (sibling.tagName !== "SECTION") continue;

        // Stop if we hit another section slide (h1)
        if (getDirectH1(sibling)) {
          break;
        }

        // Collect h2 from this slide
        const h2 = sibling.querySelector("h2");
        if (h2) {
          subsections.push({
            text: h2.textContent,
            id: sibling.id || "",
          });
        }
      }
    } else {
      // Flat structure: collect from following top-level sections
      let current = sectionSlide.nextElementSibling;
      while (current) {
        if (current.tagName !== "SECTION") {
          current = current.nextElementSibling;
          continue;
        }

        // Stop if we hit another section slide (h1)
        if (getDirectH1(current) || current.querySelector(":scope > section > h1")) {
          break;
        }

        // Collect h2 from this slide
        const h2 = current.querySelector("h2");
        if (h2) {
          subsections.push({
            text: h2.textContent,
            id: current.id || "",
          });
        }

        current = current.nextElementSibling;
      }
    }

    return subsections;
  }

  /**
   * Add subsection outline to section slide
   * Inserts at start of slide (before banner) for correct grid placement
   * @param {Element} slide - Section slide element
   * @param {Array} subsections - Array of subsection objects
   */
  function addSectionOutline(slide, subsections) {
    const outline = document.createElement("div");
    outline.className = "section-outline";
    outline.setAttribute("role", "navigation");
    outline.setAttribute("aria-label", "Section outline");

    const ul = document.createElement("ul");
    ul.setAttribute("role", "list");
    subsections.forEach(function (sub) {
      const li = document.createElement("li");
      const a = document.createElement("a");
      a.href = "#/" + sub.id;
      a.textContent = sub.text;
      a.setAttribute("title", "Jump to: " + sub.text);
      li.appendChild(a);
      ul.appendChild(li);
    });

    outline.appendChild(ul);
    // Insert at start of slide for correct grid layout (outline top-right, banner bottom-left)
    slide.insertBefore(outline, slide.firstChild);
  }

  // =========================================================================
  // DATE SUPERSCRIPT
  // =========================================================================

  /**
   * Convert ordinal day numbers (1st, 2nd, 3rd, 4th, etc.) to superscript format
   */
  function formatDates() {
    // Look for date elements in various locations
    const selectors = [
      ".mcanouil-title-slide .date",
      ".quarto-title-block .date",
      ".title-content .date",
      "p.date",
      ".date",
      "div.listing-date"
    ];
    const dateElements = document.querySelectorAll(selectors.join(", "));
    dateElements.forEach(function (el) {
      // Wrap ordinal suffixes in <sup> - styling handled by CSS (.reveal .date sup)
      el.innerHTML = el.innerHTML.replace(
        /(\d+)(st|nd|rd|th)\b/gi,
        "$1<sup>$2</sup>"
      );
    });
  }

  // =========================================================================
  // FAVICON FROM LOGO
  // =========================================================================

  /**
   * Automatically generate favicon from the presentation logo
   */
  function setFaviconFromLogo() {
    const logo = document.querySelector("img.slide-logo[src]");
    if (!logo) {
      return;
    }

    const logoSrc = logo.getAttribute("src");
    if (!logoSrc) {
      return;
    }

    // Determine MIME type based on file extension
    let mimeType = "image/png";
    const extension = logoSrc.split(".").pop().toLowerCase();
    switch (extension) {
      case "svg":
        mimeType = "image/svg+xml";
        break;
      case "png":
        mimeType = "image/png";
        break;
      case "ico":
        mimeType = "image/x-icon";
        break;
      case "jpg":
      case "jpeg":
        mimeType = "image/jpeg";
        break;
    }

    // Create or update favicon link elements
    updateFaviconLink("icon", logoSrc, mimeType);
    updateFaviconLink("shortcut icon", logoSrc, mimeType);
  }

  /**
   * Update or create a favicon link element
   * @param {string} rel - Link rel attribute
   * @param {string} href - Favicon URL
   * @param {string} type - MIME type
   */
  function updateFaviconLink(rel, href, type) {
    let link = document.querySelector('link[rel="' + rel + '"]');
    if (!link) {
      link = document.createElement("link");
      link.rel = rel;
      document.head.appendChild(link);
    }
    link.type = type;
    link.href = href;
  }

  // =========================================================================
  // CODE ANNOTATION FRAGMENTS
  // =========================================================================

  /**
   * Get the next available fragment index for a slide.
   * Finds the maximum existing fragment index and returns the next one.
   * @param {Element} slide - The slide element
   * @returns {number} The next available fragment index
   */
  function getNextFragmentIndex(slide) {
    const allFragments = slide.querySelectorAll(".fragment[data-fragment-index]");
    let maxIndex = -1;
    allFragments.forEach(function (fragment) {
      const idx = parseInt(fragment.getAttribute("data-fragment-index"), 10);
      if (!isNaN(idx) && idx > maxIndex) {
        maxIndex = idx;
      }
    });
    return maxIndex + 1;
  }

  /**
   * Set up fragment triggers for code annotations.
   * Creates invisible fragment elements for each annotation anchor,
   * allowing navigation through annotations with arrow keys.
   */
  function setupCodeAnnotationFragments() {
    // Find all code blocks with annotations (directly, not per-slide to avoid duplicates)
    const annotatedCells = document.querySelectorAll(".reveal .slides .code-annotation-code");

    annotatedCells.forEach(function (codeBlock) {
      // Skip if already processed
      if (codeBlock.dataset.annotationFragmentsCreated) return;
      codeBlock.dataset.annotationFragmentsCreated = "true";

      const anchors = codeBlock.querySelectorAll(".code-annotation-anchor");
      if (anchors.length === 0) return;

      // Get the parent slide section
      const slide = codeBlock.closest("section");
      if (!slide) return;

      // Get the parent container to append fragments
      const parentNode = codeBlock.closest(".cell") || codeBlock.parentNode;

      // Find the next available fragment index (robust: checks existing indices)
      let currentIndex = getNextFragmentIndex(slide);

      // Create invisible fragment triggers for each annotation
      anchors.forEach(function (anchor, i) {
        const targetCell = anchor.dataset.targetCell;
        const targetAnnotation = anchor.dataset.targetAnnotation;

        const fragmentDiv = document.createElement("div");
        fragmentDiv.className = "code-annotation-fragment fragment";
        fragmentDiv.dataset.targetCell = targetCell;
        fragmentDiv.dataset.targetAnnotation = targetAnnotation;
        fragmentDiv.dataset.anchorIndex = i;
        fragmentDiv.setAttribute("data-fragment-index", currentIndex);
        fragmentDiv.style.display = "none";
        parentNode.appendChild(fragmentDiv);
        currentIndex++;
      });
    });
  }

  /**
   * Hide all annotation tooltips
   */
  function hideAllAnnotationTooltips() {
    const allAnchors = document.querySelectorAll(".code-annotation-anchor");
    allAnchors.forEach(function (anchor) {
      if (anchor._tippy) {
        anchor._tippy.hide();
      }
    });
  }

  /**
   * Show annotation tooltip for a specific anchor using tippy directly
   * @param {string} targetCell - The target cell ID
   * @param {string} targetAnnotation - The annotation number
   */
  function showAnnotationTooltip(targetCell, targetAnnotation) {
    const anchor = document.querySelector(
      '.code-annotation-anchor[data-target-cell="' + targetCell +
      '"][data-target-annotation="' + targetAnnotation + '"]'
    );

    if (anchor && anchor._tippy) {
      anchor._tippy.show();
    }
  }

  /**
   * Handle annotation fragment shown events.
   * Shows the corresponding annotation tooltip when fragment is revealed.
   * @param {Object} event - Reveal.js fragment event
   */
  function onAnnotationFragmentShown(event) {
    const fragment = event.fragment;
    if (!fragment || !fragment.classList.contains("code-annotation-fragment")) {
      return;
    }

    // Hide all tooltips first to ensure clean state
    hideAllAnnotationTooltips();

    // Show the target tooltip
    const targetCell = fragment.dataset.targetCell;
    const targetAnnotation = fragment.dataset.targetAnnotation;
    showAnnotationTooltip(targetCell, targetAnnotation);
  }

  /**
   * Handle annotation fragment hidden events.
   * Shows the previous annotation tooltip when navigating backwards.
   * @param {Object} event - Reveal.js fragment event
   */
  function onAnnotationFragmentHidden(event) {
    const fragment = event.fragment;
    if (!fragment || !fragment.classList.contains("code-annotation-fragment")) {
      return;
    }

    // Hide all tooltips first
    hideAllAnnotationTooltips();

    // Find the previous annotation fragment and show its tooltip
    const anchorIndex = parseInt(fragment.dataset.anchorIndex, 10);
    if (anchorIndex > 0) {
      // Get the previous fragment's target info
      const slide = fragment.closest("section");
      if (slide) {
        const prevFragment = slide.querySelector(
          '.code-annotation-fragment[data-anchor-index="' + (anchorIndex - 1) + '"]'
        );
        if (prevFragment) {
          const targetCell = prevFragment.dataset.targetCell;
          const targetAnnotation = prevFragment.dataset.targetAnnotation;
          showAnnotationTooltip(targetCell, targetAnnotation);
        }
      }
    }
  }

  // =========================================================================
  // MENU/LOGO/FOOTER VISIBILITY
  // =========================================================================

  /**
   * Update menu button, logo, slide number, and footer visibility
   * Hide on title slide, show on all other slides
   * @param {Object} event - Slide change event or indices object (unused, kept for API compatibility)
   */
  function updateMenuVisibility(event) {
    // Use class-based detection for robustness (works regardless of slide position)
    const currentSlide = document.querySelector(
      ".reveal .slides > section.present, .reveal .slides > section > section.present"
    );
    const isTitle = currentSlide && (
      currentSlide.classList.contains("mcanouil-title-slide") ||
      currentSlide.classList.contains("quarto-title-block")
    );

    // Menu button - hide on title slide
    const menuButton = document.querySelector(".slide-menu-button");
    if (menuButton) {
      menuButton.style.display = isTitle ? "none" : "";
    }

    // Logo - hide on title slide
    const logoImg = document.querySelector("div.has-logo > img.slide-logo");
    if (logoImg) {
      logoImg.style.display = isTitle ? "none" : "";
    }

    // Slide number - hide on title slide
    const slideNumber = document.querySelector(".reveal .slide-number");
    if (slideNumber) {
      slideNumber.style.display = isTitle ? "none" : "";
    }

    // Footer - hide on title slide
    const footer = document.querySelector(".reveal .footer");
    if (footer) {
      footer.style.display = isTitle ? "none" : "";
    }
  }

  // =========================================================================
  // DEBUG BORDERS
  // =========================================================================

  /**
   * Apply debug borders to all slides for overflow detection.
   * Colour coding:
   * - Red: Regular slides (top-level sections)
   * - Blue: Nested slides (vertical stack)
   * - Green: Title and closing slides
   * - Orange: Section slides
   * - Magenta dashed: Slides container boundary
   */
  function applyDebugBorders() {
    // Apply border to slides container
    const slidesContainer = document.querySelector(".reveal .slides");
    if (slidesContainer) {
      slidesContainer.style.outline = "2px dashed magenta";
      slidesContainer.style.outlineOffset = "-2px";
    }

    // Apply borders to all slide sections
    const sections = document.querySelectorAll(".reveal .slides > section");
    sections.forEach(function (section) {
      // Determine border colour based on slide type
      var borderColour = "red"; // Default for regular slides

      if (
        section.classList.contains("mcanouil-title-slide") ||
        section.classList.contains("mcanouil-closing-slide")
      ) {
        borderColour = "green";
      } else if (section.classList.contains("section-slide")) {
        borderColour = "orange";
      }

      // Apply inline styles
      section.style.border = "3px solid " + borderColour;
      section.style.boxSizing = "border-box";

      // Handle nested sections (vertical slides)
      const nestedSections = section.querySelectorAll("section");
      nestedSections.forEach(function (nested) {
        nested.style.border = "3px solid blue";
        nested.style.boxSizing = "border-box";
      });
    });
  }
};
