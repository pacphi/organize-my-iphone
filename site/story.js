// Scroll story for the organize-my-iphone site: reveal-on-scroll panels, a progress bar with a
// rider, a terminal that follows the command tour, and critters you can poke.
(function () {
  "use strict";

  var reduceMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  document.documentElement.classList.add("js");

  // ---------- reveal panels as they scroll into view ----------
  // A plain scroll check (not IntersectionObserver) so nothing can stay hidden by accident.
  var pending = Array.prototype.slice.call(document.querySelectorAll(".reveal"));
  function revealVisible() {
    if (!pending.length) return;
    var limit = window.innerHeight * 0.92;
    pending = pending.filter(function (el) {
      if (reduceMotion || el.getBoundingClientRect().top < limit) { el.classList.add("in"); return false; }
      return true;
    });
  }
  revealVisible();
  window.addEventListener("scroll", function () { requestAnimationFrame(revealVisible); }, { passive: true });
  window.addEventListener("resize", revealVisible);

  // ---------- reading progress, with Scoot riding along ----------
  var fill = document.getElementById("progress-fill");
  var rider = document.getElementById("progress-rider");
  var ticking = false;
  function updateProgress() {
    ticking = false;
    var max = document.documentElement.scrollHeight - window.innerHeight;
    var p = max > 0 ? Math.min(1, Math.max(0, window.scrollY / max)) : 0;
    fill.style.transform = "scaleX(" + p + ")";
    rider.style.left = "calc(" + (p * 100) + "% - " + (p * 34) + "px)";
  }
  window.addEventListener("scroll", function () {
    if (!ticking) { ticking = true; requestAnimationFrame(updateProgress); }
  }, { passive: true });
  updateProgress();

  // ---------- command tour: the terminal follows the step in view ----------
  // Example output, shortened, in the tool's own style. The apps are the made-up ones from the phone.
  var SCRIPTS = {
    doctor: [
      "$ organize-my-iphone doctor",
      "Workspace: ~/.organize-my-iphone",
      "[ok]   cfgutil: …/cfgutil",
      "[ok]   iPhone: My iPhone",
      "[ok]   Ollama: a chat model",
      "[miss] Apple on-device model: not available on this Mac",
      "",
      "Close the Apple Configurator window before scanning: it locks the phone while open."
    ],
    run: [
      "$ organize-my-iphone run --open",
      "✓ Read apps and Home Screen layout from the iPhone · My iPhone",
      "  Found 42 app icons on 2 page(s) with 0 folder(s).",
      "✓ Look up 42 app(s) in the App Store",
      "✓ Placed 30 app(s) by App Store genre and built-in rules",
      "✓ Classify 12 app(s) with Ollama",
      "✓ Build 12 layout proposal(s)",
      "✓ Write the preview page",
      "",
      "Nothing on the phone has changed.",
      "When you have picked a proposal, check it and apply it:",
      "  organize-my-iphone apply <scheme> --dry-run",
      "  organize-my-iphone apply <scheme>",
      "Schemes built: category-pages, folder-board, alphabetical, …"
    ],
    scan: [
      "$ organize-my-iphone scan",
      "→ Read apps and Home Screen layout from the iPhone",
      "✓ Read apps and Home Screen layout from the iPhone · My iPhone",
      "  Found 42 app icons on 2 page(s) with 0 folder(s).",
      "  Layout backed up to ~/.organize-my-iphone/backups/icon-layout-…-scan.json"
    ],
    enrich: [
      "$ organize-my-iphone enrich",
      "→ Look up 42 app(s) in the App Store",
      "✓ Look up 42 app(s) in the App Store",
      "  (Only app IDs are sent, like com.example.notes.)",
      "",
      "$ organize-my-iphone enrich --offline",
      "- App Store lookup skipped (--offline)"
    ],
    classify: [
      "$ organize-my-iphone classify",
      "✓ Placed 30 app(s) by App Store genre and built-in rules",
      "→ Classify 12 app(s) with Ollama",
      "✓ Classify 12 app(s) with Ollama",
      "",
      "  Money          4   Bank, Budget, Stocks, Wallet",
      "  Media          6   Books, Movies, Music, News, …"
    ],
    plan: [
      "$ organize-my-iphone plan",
      "✓ Build 12 layout proposal(s)",
      "",
      "Folder board (folder-board)",
      "  1 page(s), 9 folder(s)",
      "  Daily          6   Calendar, Clock, Mail, Notes, …",
      "  Work           5   Docs, Meet, Sheets, Slides, …",
      "  AI             3   Muse, Sketchbot, Voicey",
      "  …"
    ],
    preview: [
      "$ organize-my-iphone preview --open",
      "→ Write the preview page",
      "✓ Write the preview page",
      "  ~/.organize-my-iphone/preview.html",
      "",
      "(Your browser opens with every proposal side by side.)"
    ],
    dry: [
      "$ organize-my-iphone apply folder-board --dry-run",
      "✓ Read the current layout from the iPhone · My iPhone",
      "My iPhone: 40 of 42 icons will change page or folder",
      "(1 page(s), 9 folder(s)).",
      "",
      "Dry run: nothing was changed."
    ],
    apply: [
      "$ organize-my-iphone apply folder-board",
      "✓ Read the current layout from the iPhone · My iPhone",
      "My iPhone: 40 of 42 icons will change page or folder.",
      "Current layout saved to ~/.organize-my-iphone/backups/…-before-apply.json",
      "Apply the folder board layout to My iPhone? [y/N] y",
      "✓ Write the new layout to My iPhone",
      "Done. To undo: organize-my-iphone restore"
    ],
    restore: [
      "$ organize-my-iphone restore",
      "✓ Read the current layout from the iPhone · My iPhone",
      "Restoring icon-layout-…-before-apply.json to My iPhone.",
      "Continue? [y/N] y",
      "✓ Write the restored layout to My iPhone",
      "Done."
    ]
  };

  var termBody = document.getElementById("term-body");
  var termTitle = document.getElementById("term-title");
  var tourHost = document.getElementById("tour-c");
  var steps = document.querySelectorAll(".tour-step");
  var current = null;
  var typing = null;

  function lineClass(line) {
    if (line.indexOf("$ ") === 0) return "t-cmd";
    if (line.indexOf("✓") === 0 || line.indexOf("[ok]") === 0) return "t-ok";
    if (line.indexOf("[miss]") === 0 || line.indexOf("- ") === 0) return "t-warn";
    if (line.indexOf("→") === 0) return "t-go";
    return "";
  }

  function showStep(name, host) {
    if (name === current) return;
    current = name;
    steps.forEach(function (s) { s.classList.toggle("active", s.dataset.step === name); });
    tourHost.querySelector("use").setAttribute("href", "#" + host);
    tourHost.classList.remove("hop"); void tourHost.getBoundingClientRect(); tourHost.classList.add("hop");
    termTitle.textContent = "organize-my-iphone " + (name === "dry" ? "apply --dry-run" : name);
    var lines = SCRIPTS[name] || [];
    if (typing) clearTimeout(typing);
    termBody.textContent = "";
    var i = 0;
    (function next() {
      if (i >= lines.length) return;
      var span = document.createElement("span");
      span.className = lineClass(lines[i]);
      span.textContent = lines[i] + "\n";
      termBody.appendChild(span);
      i++;
      if (reduceMotion) next(); else typing = setTimeout(next, 110);
    })();
  }

  if (steps.length) {
    if ("IntersectionObserver" in window) {
      var stepIO = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (e.isIntersecting) showStep(e.target.dataset.step, e.target.dataset.host);
        });
      }, { rootMargin: "-45% 0px -45% 0px" });
      steps.forEach(function (s) { stepIO.observe(s); });
    }
    showStep(steps[0].dataset.step, steps[0].dataset.host);
    steps.forEach(function (s) {
      s.addEventListener("click", function () { showStep(s.dataset.step, s.dataset.host); });
    });
  }

  // ---------- poke a critter ----------
  var QUIPS = {
    scoot: [
      "Hi! I read your apps. Only read. Promise.",
      "I back up your layout before anyone touches it.",
      "My tail is a USB plug. Please don't ask how I charge.",
      "42 apps? Rookie numbers. I've seen phones with a folder named \"Folder\"."
    ],
    lumi: [
      "Every layout gets a preview first. No surprises.",
      "I glow so you don't have to squint.",
      "Pick a layout on the phone! I'll wait. I'm a jelly. I'm good at floating.",
      "Window-shopping is free. Applying is optional."
    ],
    rewindle: [
      "Changed your mind? I can put it all back with restore.",
      "Slow and steady. And backed up.",
      "I never move the dock. The dock is sacred.",
      "Try --dry-run first. Rehearsals are cool."
    ]
  };
  var quip = document.getElementById("quip");
  var quipTimer = null;
  var counters = {};
  document.querySelectorAll(".roamer").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var key = btn.dataset.quips;
      var list = QUIPS[key] || ["Hi!"];
      counters[key] = ((counters[key] === undefined ? -1 : counters[key]) + 1) % list.length;
      quip.textContent = list[counters[key]];
      quip.hidden = false;
      var r = btn.getBoundingClientRect();
      var w = Math.min(260, window.innerWidth - 32);
      quip.style.width = w + "px";
      quip.style.left = Math.max(16, Math.min(window.innerWidth - w - 16, r.left + r.width / 2 - w / 2)) + "px";
      quip.style.top = Math.max(16, r.top - 16) + "px";
      quip.classList.remove("show"); void quip.offsetWidth; quip.classList.add("show");
      btn.classList.remove("poked"); void btn.offsetWidth; btn.classList.add("poked");
      clearTimeout(quipTimer);
      quipTimer = setTimeout(function () { quip.hidden = true; }, 3200);
    });
  });
  window.addEventListener("scroll", function () { if (!quip.hidden) quip.hidden = true; }, { passive: true });
})();
