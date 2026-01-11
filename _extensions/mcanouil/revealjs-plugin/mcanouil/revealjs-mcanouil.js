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
    // Section slide options
    sectionSlideStyle: "banner",
    // Colour customisation (null = use CSS defaults)
    sectionBackground: null,
    sectionForeground: null,
    outlineBorderColor: null,
  };

  let config = {};

  return {
    id: "mcanouil-revealjs",

    init: function (deck) {
      // Merge user config with defaults
      const userConfig = deck.getConfig()["mcanouil-revealjs"] || {};
      config = { ...defaults, ...userConfig };

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

        // Background colour is set by Lua filter (section-slides.lua) via data-background-color
        // The filter runs during Pandoc AST processing, before HTML generation

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

    // Clone heading into banner
    const headingClone = heading.cloneNode(true);
    banner.appendChild(headingClone);

    // Insert banner at start of slide
    slide.insertBefore(banner, slide.firstChild);

    // Hide original heading
    heading.style.display = "none";
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
   * @param {Element} slide - Section slide element
   * @param {Array} subsections - Array of subsection objects
   */
  function addSectionOutline(slide, subsections) {
    const outline = document.createElement("div");
    outline.className = "section-outline";

    const ul = document.createElement("ul");
    subsections.forEach(function (sub) {
      const li = document.createElement("li");
      const a = document.createElement("a");
      a.href = "#/" + sub.id;
      a.textContent = sub.text;
      li.appendChild(a);
      ul.appendChild(li);
    });

    outline.appendChild(ul);
    slide.appendChild(outline);
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
      el.innerHTML = el.innerHTML.replace(
        /(\d+)(st|nd|rd|th)\b/gi,
        '$1<sup style="font-size: 0.6em; vertical-align: super;">$2</sup>'
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

      // Find existing fragment count to set proper indices
      const existingFragments = slide.querySelectorAll(".fragment:not(.code-annotation-fragment)");
      let currentIndex = existingFragments.length;

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
  // MENU/LOGO/FOOTER VISIBILITY AND STYLING
  // =========================================================================

  /**
   * Update menu button, logo, slide number visibility, and colours
   * based on slide position and type (title slide vs section slide)
   * @param {Object} event - Slide change event or indices object
   */
  function updateMenuVisibility(event) {
    const indexh = event.indexh !== undefined ? event.indexh : 0;
    const isTitle = indexh === 0;

    // Get current slide to check if it's a section slide
    const currentSlide = event.currentSlide || document.querySelector(".reveal .slides > section.present");
    const isSectionSlide = currentSlide && currentSlide.classList.contains("section-slide");

    // Menu button - hide on title, invert colour on section slides
    const menuButton = document.querySelector(".slide-menu-button");
    if (menuButton) {
      menuButton.style.display = isTitle ? "none" : "";
      if (isSectionSlide) {
        menuButton.classList.add("section-slide-menu");
      } else {
        menuButton.classList.remove("section-slide-menu");
      }
    }

    // Logo - hide on title, swap light/dark version on section slides
    const logoImg = document.querySelector("div.has-logo > img.slide-logo");
    if (logoImg) {
      logoImg.style.display = isTitle ? "none" : "";

      // Swap logo source for section slides (light logo on dark background)
      if (!logoImg.dataset.srcLight) {
        // Store original sources on first run
        logoImg.dataset.srcLight = logoImg.src;
        // Try to find dark version by swapping 'dark' and 'light' in path
        const darkSrc = logoImg.src.replace("logo-dark", "logo-light");
        logoImg.dataset.srcDark = darkSrc !== logoImg.src ? darkSrc : logoImg.src;
      }

      if (isSectionSlide) {
        logoImg.src = logoImg.dataset.srcDark;
      } else {
        logoImg.src = logoImg.dataset.srcLight;
      }
    }

    // Slide number - hide on title, invert colour on section slides
    const slideNumber = document.querySelector(".reveal .slide-number");
    if (slideNumber) {
      slideNumber.style.display = isTitle ? "none" : "";
      if (isSectionSlide) {
        slideNumber.classList.add("section-slide-number");
      } else {
        slideNumber.classList.remove("section-slide-number");
      }
    }

    // Footer colour inversion on section slides
    const footer = document.querySelector(".reveal .footer");
    if (footer) {
      if (isSectionSlide) {
        footer.classList.add("section-slide-footer");
      } else {
        footer.classList.remove("section-slide-footer");
      }
    }
  }
};
