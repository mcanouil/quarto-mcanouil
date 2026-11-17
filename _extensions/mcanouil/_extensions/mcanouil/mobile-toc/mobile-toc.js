/**
 * Mobile TOC - Narrow-screen table of contents
 * Shows the table of contents as a pill and a bottom sheet on narrow screens.
 *
 * @license MIT
 * @copyright 2026 Mickaël Canouil
 * @author Mickaël Canouil
 */

/*
 * Upstream: https://github.com/quarto-dev/quarto-cli/issues/5961
 * Remove when: the minimum Quarto version includes the fix.
 * Quarto hides the side table of contents below the Bootstrap md breakpoint
 * and shows nothing in its place.
 * Below that width, add a pill that opens a copy of the list in a bottom sheet.
 */
(() => {
  const SHEET_ID = "mobile-toc-sheet";

  const readCloseLabel = () => {
    const raw = document.getElementById("mobile-toc-options")?.textContent;
    try {
      return JSON.parse(raw)?.labels?.close || "Close";
    } catch (error) {
      console.error("mobile-toc: cannot read #mobile-toc-options.", error);
      return "Close";
    }
  };

  const start = () => {
    const toc = document.querySelector("nav#TOC");
    const list = toc?.querySelector(":scope > ul");
    if (
      !list ||
      document.getElementById("TOC-body") ||
      toc.closest("main") ||
      !Object.hasOwn(HTMLElement.prototype, "popover") ||
      list.querySelectorAll("a").length < 2
    ) {
      return;
    }

    const label = toc.querySelector("#toc-title")?.textContent.trim() || "Contents";
    const closeLabel = readCloseLabel();
    const breakpoint =
      getComputedStyle(document.documentElement).getPropertyValue("--bs-breakpoint-md").trim() || "768px";
    const narrow = window.matchMedia(`(width < ${breakpoint})`);

    const build = () => {
      const sheet = document.createElement("div");
      sheet.id = SHEET_ID;
      sheet.className = "mobile-toc-sheet";
      sheet.popover = "auto";
      sheet.setAttribute("role", "navigation");
      sheet.setAttribute("aria-labelledby", "mobile-toc-sheet-label");

      const header = document.createElement("div");
      header.className = "mobile-toc-sheet-header";
      const sheetLabel = document.createElement("span");
      sheetLabel.id = "mobile-toc-sheet-label";
      sheetLabel.className = "mobile-toc-sheet-label";
      sheetLabel.textContent = label;
      const close = document.createElement("button");
      close.type = "button";
      close.className = "mobile-toc-close";
      close.setAttribute("popovertarget", SHEET_ID);
      close.setAttribute("popovertargetaction", "hide");
      close.setAttribute("aria-label", closeLabel);
      close.innerHTML = '<i class="bi bi-x-lg" aria-hidden="true"></i>';
      header.append(sheetLabel, close);
      sheet.append(header);

      let copy = null;
      const mount = () => {
        const fresh = list.cloneNode(true);
        [fresh, ...fresh.querySelectorAll("[id], [inert]")].forEach((el) => {
          el.removeAttribute("id");
          el.inert = false;
        });
        const focusedHref = copy?.contains(document.activeElement)
          ? document.activeElement.getAttribute("href")
          : null;
        if (copy) copy.replaceWith(fresh);
        else sheet.append(fresh);
        copy = fresh;
        markCurrent();
        if (focusedHref) {
          [...copy.querySelectorAll("a")].find((a) => a.getAttribute("href") === focusedHref)?.focus();
        }
      };
      const markCurrent = () => {
        copy.querySelectorAll("a[aria-current]").forEach((a) => a.removeAttribute("aria-current"));
        const active = copy.querySelectorAll("a.active");
        active[active.length - 1]?.setAttribute("aria-current", "location");
      };
      const mirrorClasses = () => {
        const selector = "ul, li, a";
        const source = list.querySelectorAll(selector);
        const target = copy.querySelectorAll(selector);
        source.forEach((el, index) => {
          if (target[index].className !== el.className) target[index].className = el.className;
        });
        markCurrent();
      };
      mount();
      const HEADING = ":is(h1, h2, h3, h4, h5, h6)";
      const focusHeading = (id) => {
        const target = document.getElementById(id);
        const active = document.activeElement;
        if (!target || (active !== document.body && !active?.classList.contains("mobile-toc-pill"))) return;
        const heading = target.matches(HEADING) ? target : target.querySelector(`:scope > ${HEADING}`) || target;
        if (!heading.hasAttribute("tabindex")) {
          heading.setAttribute("tabindex", "-1");
          heading.addEventListener("blur", () => heading.removeAttribute("tabindex"), { once: true });
        }
        heading.focus({ preventScroll: true });
      };
      const isPlainSamePageClick = (event, link) =>
        !event.defaultPrevented &&
        !(event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) &&
        link.origin + link.pathname === location.origin + location.pathname;
      sheet.addEventListener("click", (event) => {
        const link = event.target.closest("a");
        if (!link) return;
        sheet.hidePopover();
        if (!isPlainSamePageClick(event, link)) return;
        let id;
        try {
          id = decodeURIComponent(link.hash.slice(1));
        } catch {
          return;
        }
        requestAnimationFrame(() => focusHeading(id));
      });

      // Other scripts may add children inside TOC links, so a copy paired by position can drift.
      // Clone the list again on any child change, and copy only classes otherwise.
      // Both are coalesced to one update for each animation frame.
      let frame = 0;
      let reclone = false;
      const observer = new MutationObserver((records) => {
        if (records.some((record) => record.type === "childList")) reclone = true;
        if (frame) return;
        frame = requestAnimationFrame(() => {
          frame = 0;
          if (reclone) mount();
          else mirrorClasses();
          reclone = false;
        });
      });
      observer.observe(list, {
        subtree: true,
        childList: true,
        attributes: true,
        attributeFilter: ["class"],
      });

      const pill = document.createElement("button");
      pill.type = "button";
      pill.className = "mobile-toc-pill";
      pill.setAttribute("popovertarget", SHEET_ID);
      pill.innerHTML = '<i class="bi bi-list-nested" aria-hidden="true"></i>';
      const pillLabel = document.createElement("span");
      pillLabel.className = "mobile-toc-pill-label";
      pillLabel.textContent = label;
      pill.append(pillLabel);
      document.body.append(pill, sheet);

      const root = document.documentElement;
      const writePillHeight = () => {
        root.style.setProperty("--mobile-toc-pill-height", `${pill.getBoundingClientRect().height}px`);
      };
      const pillObserver = new ResizeObserver(writePillHeight);
      pillObserver.observe(pill);

      // Content wider than the screen widens the layout viewport on a phone,
      // and a fixed element follows its far edge off screen.
      // Offset the pill, the sheet and back-to-top by the gap to the visual viewport.
      // A hidden fixed box measures the area that fixed elements use, which leaves out
      // a classic desktop scrollbar.
      const viewport = window.visualViewport;
      const listeners = new AbortController();
      let placeFrame = 0;
      let area = null;
      if (viewport) {
        const { signal } = listeners;
        area = document.createElement("div");
        area.setAttribute("aria-hidden", "true");
        area.style.cssText =
          "display: block; position: fixed; inset: 0; margin: 0; padding: 0; border: 0; " +
          "width: auto; height: auto; min-width: 0; min-height: 0; max-width: none; max-height: none; " +
          "visibility: hidden; pointer-events: none;";
        document.body.append(area);
        const apply = () => {
          placeFrame = 0;
          const box = area.getBoundingClientRect();
          const offsetX = box.right - (viewport.offsetLeft + viewport.width);
          const offsetY = box.bottom - (viewport.offsetTop + viewport.height);
          const offsetLeft = viewport.offsetLeft - box.left;
          root.style.setProperty("--mobile-toc-offset-x", `${Math.max(0, offsetX)}px`);
          root.style.setProperty("--mobile-toc-offset-y", `${Math.max(0, offsetY)}px`);
          root.style.setProperty("--mobile-toc-offset-left", `${Math.max(0, offsetLeft)}px`);
        };
        const place = () => {
          if (!placeFrame) placeFrame = requestAnimationFrame(apply);
        };
        viewport.addEventListener("resize", place, { signal });
        viewport.addEventListener("scroll", place, { signal });
        window.addEventListener("resize", place, { signal });
        window.addEventListener("scroll", place, { signal, passive: true });
        window.addEventListener("load", place, { signal });
        apply();
      }

      sheet.addEventListener("toggle", (event) => {
        if (event.newState !== "open") return;
        const link = sheet.querySelector("a.active");
        if (!link) return;
        const top = link.offsetTop;
        const bottom = top + link.offsetHeight;
        if (top < sheet.scrollTop) sheet.scrollTop = top;
        else if (bottom > sheet.scrollTop + sheet.clientHeight) sheet.scrollTop = bottom - sheet.clientHeight;
      });

      return () => {
        listeners.abort();
        pillObserver.disconnect();
        cancelAnimationFrame(placeFrame);
        area?.remove();
        ["pill-height", "offset-x", "offset-y", "offset-left"].forEach((name) =>
          root.style.removeProperty(`--mobile-toc-${name}`),
        );
        observer.disconnect();
        cancelAnimationFrame(frame);
        if (sheet.matches(":popover-open")) sheet.hidePopover();
        pill.remove();
        sheet.remove();
      };
    };

    let teardown = null;
    const sync = () => {
      if (narrow.matches && !teardown) teardown = build();
      if (!narrow.matches && teardown) {
        teardown();
        teardown = null;
      }
    };
    sync();
    narrow.addEventListener("change", sync);
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
