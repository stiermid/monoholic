(() => {
  const settings = document.currentScript?.dataset || {};
  const updates = [];
  let hintIndex = 0;

  const updateAll = () => updates.forEach((update) => update());
  const observer =
    typeof ResizeObserver === "function" ? new ResizeObserver(updateAll) : null;
  const contentObserver =
    typeof MutationObserver === "function"
      ? new MutationObserver(updateAll)
      : null;

  function enhance(region, content, hintAnchor, label, labelledBy) {
    // Also respect author-provided wrappers and repeated script inclusion.
    if (region.hasAttribute("data-scroll-enhanced")) return;
    region.setAttribute("data-scroll-enhanced", "");
    const originalAttributes = new Set(region.getAttributeNames());
    const hint = document.createElement("p");
    do {
      hint.id = `monoholic-scroll-hint-${++hintIndex}`;
    } while (document.getElementById(hint.id));
    hint.className = "scroll-hint";
    hint.textContent =
      settings.scrollHint || "Scroll horizontally to see more.";
    hint.hidden = true;
    hintAnchor.after(hint);

    function setAutomaticAttribute(name, value) {
      if (originalAttributes.has(name)) return;
      if (value === null) region.removeAttribute(name);
      else region.setAttribute(name, value);
    }

    function update() {
      const overflows = region.scrollWidth > region.clientWidth + 1;
      hint.hidden = !overflows;
      setAutomaticAttribute("tabindex", overflows ? "0" : null);
      setAutomaticAttribute("role", overflows ? "region" : null);
      if (
        !originalAttributes.has("aria-label") &&
        !originalAttributes.has("aria-labelledby")
      ) {
        setAutomaticAttribute(
          labelledBy ? "aria-labelledby" : "aria-label",
          overflows ? labelledBy || label : null,
        );
      }

      // Preserve descriptions supplied by the author or other scripts.
      const descriptions = new Set(
        (region.getAttribute("aria-describedby") || "")
          .split(/\s+/)
          .filter(Boolean),
      );
      if (overflows) descriptions.add(hint.id);
      else descriptions.delete(hint.id);
      if (descriptions.size) {
        region.setAttribute("aria-describedby", [...descriptions].join(" "));
      } else {
        region.removeAttribute("aria-describedby");
      }
    }

    updates.push(update);
    update();
    observer?.observe(region);
    if (content !== region) observer?.observe(content);
    contentObserver?.observe(content, {
      childList: true,
      characterData: true,
      subtree: true,
    });
  }

  document.querySelectorAll(".page-content table").forEach((table) => {
    let wrapper = table.parentElement;
    if (!wrapper.classList.contains("table-scroll")) {
      wrapper = document.createElement("div");
      wrapper.className = "table-scroll";
      table.before(wrapper);
      wrapper.append(table);
    }
    const label =
      table.getAttribute("aria-label") ||
      table.caption?.textContent.trim() ||
      settings.tableLabel ||
      "Table";
    enhance(
      wrapper,
      table,
      wrapper,
      label,
      table.getAttribute("aria-labelledby"),
    );
  });

  document.querySelectorAll(".page-content pre").forEach((block) => {
    const hintAnchor = block.closest("div.highlighter-rouge") || block;
    enhance(block, block, hintAnchor, settings.codeLabel || "Code block");
  });

  window.addEventListener("resize", updateAll);
  // A font swap can change overflow without resizing the container itself.
  if (document.fonts) {
    document.fonts.ready.then(updateAll);
    document.fonts.addEventListener("loadingdone", updateAll);
  }
})();
