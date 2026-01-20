/**
 * MIT License
 *
 * Copyright (c) 2026 Mickaël Canouil
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/**
 * Reveal.js plugin to enable fragment navigation through code annotations.
 *
 * This plugin creates invisible fragment elements for each code annotation anchor,
 * allowing users to navigate through annotations using arrow keys or fragment
 * navigation controls.
 *
 * Usage in Quarto:
 * Simply enable the plugin. It automatically detects code blocks with annotations
 * (elements with class .code-annotation-code containing .code-annotation-anchor
 * elements).
 *
 * The plugin:
 * - Creates hidden fragment triggers for each annotation.
 * - Shows annotation tooltips (via tippy.js) when fragments are revealed.
 * - Supports forward and backward navigation through annotations.
 * - Synchronises annotations with line highlighting when both are present.
 *
 * Configuration:
 * ```yaml
 * format:
 *   revealjs:
 *     code-annotation-fragments: true  # enabled by default
 * ```
 */

window.RevealJsCodeAnnotationFragments = function () {
  "use strict";

  /**
   * Convert kebab-case string to camelCase.
   * @param {string} str - Kebab-case string (e.g., "code-annotation-fragments")
   * @returns {string} CamelCase string (e.g., "codeAnnotationFragments")
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

  /**
   * Get the next available fragment index for a slide.
   * Finds the maximum existing fragment index and returns the next one.
   * @param {Element} slide - The slide element
   * @returns {number} The next available fragment index
   */
  function getNextFragmentIndex(slide) {
    var allFragments = slide.querySelectorAll(".fragment[data-fragment-index]");
    var maxIndex = -1;
    allFragments.forEach(function (fragment) {
      var idx = parseInt(fragment.getAttribute("data-fragment-index"), 10);
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
   *
   * When code blocks have line highlighting, annotations are synchronised
   * with the corresponding line highlight steps instead of creating
   * separate sequential fragments.
   */
  function setupCodeAnnotationFragments() {
    // Find all code blocks with annotations (directly, not per-slide to avoid duplicates)
    var annotatedCells = document.querySelectorAll(
      ".reveal .slides .code-annotation-code"
    );

    annotatedCells.forEach(function (codeBlock) {
      // Skip if already processed
      if (codeBlock.dataset.annotationFragmentsCreated) return;
      codeBlock.dataset.annotationFragmentsCreated = "true";

      var anchors = codeBlock.querySelectorAll(".code-annotation-anchor");
      if (anchors.length === 0) return;

      // Get the parent slide section
      var slide = codeBlock.closest("section");
      if (!slide) return;

      // Get the parent container to append fragments
      var parentNode = codeBlock.closest(".cell") || codeBlock.parentNode;

      // Check if this code block has line highlighting
      // Note: quarto-line-highlight removes data-code-line-numbers after processing,
      // so we detect line highlighting by checking for fragment clones with has-line-highlights
      var sourceCodeDiv = codeBlock.closest("div.sourceCode");
      var hasLineHighlighting =
        codeBlock.querySelector("code.fragment.has-line-highlights") !== null;

      if (hasLineHighlighting && sourceCodeDiv) {
        // Line highlighting is enabled - sync annotations with highlight steps
        var targetCell = sourceCodeDiv.id;
        var lineHighlightFragments = codeBlock.querySelectorAll(
          "code.fragment.has-line-highlights"
        );

        // Store mapping for fragment event handling
        codeBlock.dataset.annotationSyncMode = "line-highlight";
        codeBlock.dataset.targetCell = targetCell;

        // Build map of fragment index -> annotation numbers
        // Strategy: Map fragments to annotations by position
        // Fragment 0 -> Annotation 1, Fragment 1 -> Annotation 2, etc.
        var stepToAnnotations = {};

        // Get sorted fragment indices
        var fragmentIndices = [];
        lineHighlightFragments.forEach(function (fragment, i) {
          var fragIdx = parseInt(
            fragment.getAttribute("data-fragment-index"),
            10
          );
          if (isNaN(fragIdx)) fragIdx = i;
          fragmentIndices.push(fragIdx);
        });
        fragmentIndices.sort(function (a, b) {
          return a - b;
        });

        // Map each fragment to the corresponding annotation by position
        fragmentIndices.forEach(function (fragIdx, position) {
          // Position 0 maps to annotation 1, position 1 to annotation 2, etc.
          var annotationNum = String(position + 1);

          // Check if this annotation exists
          var annotationExists = Array.prototype.some.call(
            anchors,
            function (anchor) {
              return anchor.dataset.targetAnnotation === annotationNum;
            }
          );

          if (annotationExists) {
            // Map fragment index directly to annotation
            stepToAnnotations[fragIdx] = [annotationNum];
          }
        });

        // Store the mapping on the code block for event handlers
        codeBlock.dataset.stepToAnnotations = JSON.stringify(stepToAnnotations);
      } else {
        // No line highlighting - use original behaviour with sequential fragments
        var currentIndex = getNextFragmentIndex(slide);

        // Create invisible fragment triggers for each annotation
        anchors.forEach(function (anchor, i) {
          var targetCell = anchor.dataset.targetCell;
          var targetAnnotation = anchor.dataset.targetAnnotation;

          var fragmentDiv = document.createElement("div");
          fragmentDiv.className = "code-annotation-fragment fragment";
          fragmentDiv.dataset.targetCell = targetCell;
          fragmentDiv.dataset.targetAnnotation = targetAnnotation;
          fragmentDiv.dataset.anchorIndex = i;
          fragmentDiv.setAttribute("data-fragment-index", currentIndex);
          fragmentDiv.style.display = "none";
          parentNode.appendChild(fragmentDiv);
          currentIndex++;
        });
      }
    });
  }

  /**
   * Hide all annotation tooltips.
   */
  function hideAllAnnotationTooltips() {
    var allAnchors = document.querySelectorAll(".code-annotation-anchor");
    allAnchors.forEach(function (anchor) {
      if (anchor._tippy) {
        anchor._tippy.hide();
      }
    });
  }

  /**
   * Show annotation tooltip for a specific anchor using tippy directly.
   * @param {string} targetCell - The target cell ID
   * @param {string} targetAnnotation - The annotation number
   * @param {Element} [visibleFragment] - The currently visible fragment element (optional)
   */
  function showAnnotationTooltip(targetCell, targetAnnotation, visibleFragment) {
    var anchor = null;

    // If we have a visible fragment, look for the anchor within it first
    // This ensures correct positioning when line highlighting creates fragment clones
    if (visibleFragment) {
      anchor = visibleFragment.querySelector(
        '.code-annotation-anchor[data-target-cell="' +
          targetCell +
          '"][data-target-annotation="' +
          targetAnnotation +
          '"]'
      );
    }

    // Fallback to global search if not found in fragment
    if (!anchor) {
      anchor = document.querySelector(
        '.code-annotation-anchor[data-target-cell="' +
          targetCell +
          '"][data-target-annotation="' +
          targetAnnotation +
          '"]'
      );
    }

    if (anchor && anchor._tippy) {
      // Force position recalculation before showing
      if (anchor._tippy.popperInstance) {
        anchor._tippy.popperInstance.update();
      }
      anchor._tippy.show();
    } else if (anchor) {
      // If no tippy instance, trigger click to show annotation
      anchor.click();
    }
  }

  /**
   * Handle line highlight fragment events for synced annotations.
   * @param {Element} fragment - The line highlight fragment (code.fragment)
   * @param {boolean} isShown - True if fragment shown, false if hidden
   */
  function handleLineHighlightFragment(fragment, isShown) {
    // Get the fragment index
    var fragmentIndex = parseInt(
      fragment.getAttribute("data-fragment-index"),
      10
    );

    // Find the code block with annotation sync mode
    // Note: Both <div> and <pre> may have class "sourceCode", so use "div.sourceCode"
    var pre = fragment.closest("pre");
    var sourceCodeDiv = pre ? pre.closest("div.sourceCode") : null;
    if (!sourceCodeDiv) return;

    var codeBlock = sourceCodeDiv.querySelector(".code-annotation-code");
    if (!codeBlock || codeBlock.dataset.annotationSyncMode !== "line-highlight")
      return;

    var targetCell = codeBlock.dataset.targetCell;
    var stepToAnnotations;
    try {
      stepToAnnotations = JSON.parse(
        codeBlock.dataset.stepToAnnotations || "{}"
      );
    } catch (e) {
      return;
    }

    // Hide all tooltips first
    hideAllAnnotationTooltips();

    if (isShown) {
      // Fragment index maps directly to annotations
      var annotations = stepToAnnotations[fragmentIndex];
      if (annotations && annotations.length > 0) {
        // Show all matching annotation tooltips, passing the visible fragment
        annotations.forEach(function (annotationNum) {
          showAnnotationTooltip(targetCell, annotationNum, fragment);
        });
      }
    } else {
      // Fragment hidden - show previous fragment's annotations
      var prevFragmentIndex = fragmentIndex - 1;
      var prevAnnotations = stepToAnnotations[prevFragmentIndex];
      if (prevAnnotations && prevAnnotations.length > 0) {
        // Find the previous fragment element
        var prevFragment = pre.querySelector(
          'code.fragment[data-fragment-index="' + prevFragmentIndex + '"]'
        );
        prevAnnotations.forEach(function (annotationNum) {
          showAnnotationTooltip(targetCell, annotationNum, prevFragment);
        });
      }
    }
  }

  /**
   * Handle annotation fragment shown events.
   * Shows the corresponding annotation tooltip when fragment is revealed.
   * @param {Object} event - Reveal.js fragment event
   */
  function onAnnotationFragmentShown(event) {
    var fragment = event.fragment;
    if (!fragment) return;

    // Check if this is a line highlight fragment (code.fragment inside pre)
    if (
      fragment.tagName === "CODE" &&
      fragment.classList.contains("fragment") &&
      fragment.closest("pre")
    ) {
      handleLineHighlightFragment(fragment, true);
      return;
    }

    // Original behaviour for annotation fragments
    if (!fragment.classList.contains("code-annotation-fragment")) {
      return;
    }

    // Hide all tooltips first to ensure clean state
    hideAllAnnotationTooltips();

    // Show the target tooltip
    var targetCell = fragment.dataset.targetCell;
    var targetAnnotation = fragment.dataset.targetAnnotation;
    showAnnotationTooltip(targetCell, targetAnnotation);
  }

  /**
   * Handle annotation fragment hidden events.
   * Shows the previous annotation tooltip when navigating backwards.
   * @param {Object} event - Reveal.js fragment event
   */
  function onAnnotationFragmentHidden(event) {
    var fragment = event.fragment;
    if (!fragment) return;

    // Check if this is a line highlight fragment (code.fragment inside pre)
    if (
      fragment.tagName === "CODE" &&
      fragment.classList.contains("fragment") &&
      fragment.closest("pre")
    ) {
      handleLineHighlightFragment(fragment, false);
      return;
    }

    // Original behaviour for annotation fragments
    if (!fragment.classList.contains("code-annotation-fragment")) {
      return;
    }

    // Hide all tooltips first
    hideAllAnnotationTooltips();

    // Find the previous annotation fragment and show its tooltip
    var anchorIndex = parseInt(fragment.dataset.anchorIndex, 10);
    if (anchorIndex > 0) {
      // Get the previous fragment's target info
      var slide = fragment.closest("section");
      if (slide) {
        var prevFragment = slide.querySelector(
          '.code-annotation-fragment[data-anchor-index="' +
            (anchorIndex - 1) +
            '"]'
        );
        if (prevFragment) {
          var targetCell = prevFragment.dataset.targetCell;
          var targetAnnotation = prevFragment.dataset.targetAnnotation;
          showAnnotationTooltip(targetCell, targetAnnotation);
        }
      }
    }
  }

  return {
    id: "RevealJsCodeAnnotationFragments",

    init: function (deck) {
      // Check configuration
      var deckConfig = deck.getConfig();
      var enabled = true;

      // Check for boolean shorthand (code-annotation-fragments: true/false)
      if (typeof deckConfig["code-annotation-fragments"] === "boolean") {
        enabled = deckConfig["code-annotation-fragments"];
      }
      if (typeof deckConfig["codeAnnotationFragments"] === "boolean") {
        enabled = deckConfig["codeAnnotationFragments"];
      }

      // Check for object notation
      if (
        typeof deckConfig["code-annotation-fragments"] === "object" &&
        deckConfig["code-annotation-fragments"] !== null
      ) {
        var pluginConfig = normaliseConfig(
          deckConfig["code-annotation-fragments"]
        );
        if (typeof pluginConfig.enabled === "boolean") {
          enabled = pluginConfig.enabled;
        }
      }

      // Early exit if disabled
      if (!enabled) {
        return;
      }

      // Set up on ready event
      deck.on("ready", function () {
        setupCodeAnnotationFragments();
      });

      // Handle fragment events
      deck.on("fragmentshown", function (event) {
        onAnnotationFragmentShown(event);
      });

      deck.on("fragmenthidden", function (event) {
        onAnnotationFragmentHidden(event);
      });

      // Hide tooltips when changing slides
      deck.on("slidechanged", function () {
        hideAllAnnotationTooltips();
      });
    },
  };
};
