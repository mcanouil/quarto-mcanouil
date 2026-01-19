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
 * Reveal.js plugin to control line highlighting fragment indices.
 *
 * This plugin allows synchronising code line highlights with specific fragment
 * indices, enabling tighter integration between code reveals and other slide
 * content.
 *
 * Usage in Quarto:
 * ```{.r code-line-numbers="|2|3" code-line-fragment-indices="1,2,4"}
 * line1
 * line2
 * line3
 * ```
 *
 * The code-line-fragment-indices attribute accepts a comma-separated list of
 * fragment indices. The number of indices should match the number of highlight
 * steps (including the initial state).
 */

window.RevealJsLineFragmentIndices = function () {
  "use strict";

  var defined = function (val) {
    return typeof val !== "undefined" && val !== null;
  };

  return {
    id: "RevealJsLineFragmentIndices",

    init: function (deck) {
      /**
       * Parse a comma-separated string of fragment indices.
       * @param {string} str - Comma-separated indices (e.g., "1,2,4")
       * @returns {Array<number|null>} Array of parsed indices
       */
      function parseIndices(str) {
        if (!str || typeof str !== "string") {
          return [];
        }
        return str.split(",").map(function (s) {
          var num = parseInt(s.trim(), 10);
          return isNaN(num) ? null : num;
        });
      }

      /**
       * Process all code blocks with line fragment indices attribute.
       * Modifies the data-fragment-index on highlight clones to match
       * the specified indices.
       */
      function processLineFragmentIndices() {
        var codeBlocks = deck
          .getRevealElement()
          .querySelectorAll("div.sourceCode[data-code-line-fragment-indices]");

        codeBlocks.forEach(function (sourceCodeDiv) {
          var indicesStr = sourceCodeDiv.getAttribute(
            "data-code-line-fragment-indices"
          );
          var indices = parseIndices(indicesStr);

          if (indices.length === 0) {
            return;
          }

          var pre = sourceCodeDiv.querySelector("pre");
          if (!pre) {
            return;
          }

          // Get all fragment clones created by quarto-line-highlight
          // These are <code> elements with class "fragment"
          var fragmentCodes = pre.querySelectorAll("code.fragment");

          if (fragmentCodes.length === 0) {
            return;
          }

          // Warn if counts do not match
          // indices[0] is for step 0 (original, no fragment)
          // indices[1..n] are for fragmentCodes[0..n-1]
          var expectedIndices = fragmentCodes.length + 1;
          if (indices.length !== expectedIndices) {
            console.warn(
              "[line-fragment-indices] Code block has " +
              expectedIndices +
              " highlight steps but " +
              indices.length +
              " fragment indices specified.",
              sourceCodeDiv
            );
          }

          // Apply indices to fragment clones
          // indices[0] is for the original (no fragment, skip)
          // indices[i+1] maps to fragmentCodes[i]
          fragmentCodes.forEach(function (fragment, i) {
            var targetIndex = indices[i + 1];
            if (defined(targetIndex)) {
              fragment.setAttribute("data-fragment-index", targetIndex);
            }
          });
        });
      }

      // Process on ready event, after quarto-line-highlight has run
      deck.on("ready", function () {
        processLineFragmentIndices();
      });
    },
  };
};
