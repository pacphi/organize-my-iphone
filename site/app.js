// Interactive phone mockup for the organize-my-iphone site.
// The apps below are made up. Each layout function mirrors, in simplified form, what the
// matching scheme in the tool does. Limits follow the tool's GridSpec: 4x6 icons per page,
// 4 dock slots, 9 icons per folder page. The dock never changes.
(function () {
  "use strict";

  var PER_PAGE = 24;
  var PER_FOLDER_PAGE = 9;

  // n: name, c: category, col: icon color (null = no color data), u: weekly opens (null = not in the
  // usage file), t: time of day, v: verb, p: place, a: life area, d: days since installed.
  var APPS = [
    { n: "Mail", c: "Daily", col: "#3d8bfd", u: 60, t: "Work day", v: "Read", p: "Office", a: "Work", d: 900 },
    { n: "Notes", c: "Daily", col: "#ffc93c", u: 34, t: "Anytime", v: "Make", p: "Everywhere", a: "Everyday", d: 900 },
    { n: "Calendar", c: "Daily", col: "#ff5a5f", u: 40, t: "Morning", v: "Track", p: "Office", a: "Work", d: 900 },
    { n: "Reminders", c: "Daily", col: "#ff9f43", u: 22, t: "Morning", v: "Track", p: "Home", a: "Everyday", d: 900 },
    { n: "Weather", c: "Daily", col: "#48c6ef", u: 28, t: "Morning", v: "Read", p: "Everywhere", a: "Everyday", d: 900 },
    { n: "Clock", c: "Daily", col: "#2d2d34", u: 18, t: "Morning", v: "Tools", p: "Home", a: "Everyday", d: 900 },
    { n: "Docs", c: "Work", col: "#2f6fec", u: 30, t: "Work day", v: "Work", p: "Office", a: "Work", d: 400 },
    { n: "Sheets", c: "Work", col: "#1fae6a", u: 16, t: "Work day", v: "Work", p: "Office", a: "Work", d: 400 },
    { n: "Meet", c: "Work", col: "#0f9d8c", u: 24, t: "Work day", v: "Talk", p: "Office", a: "Work", d: 300 },
    { n: "Slides", c: "Work", col: "#f4a100", u: 6, t: "Work day", v: "Make", p: "Office", a: "Work", d: 300 },
    { n: "Terminal", c: "Work", col: "#111111", u: 9, t: "Work day", v: "Work", p: "Office", a: "Work", d: 120 },
    { n: "Muse", c: "AI", col: "#a259ff", u: 26, t: "Anytime", v: "Make", p: "Everywhere", a: "Learning", d: 20 },
    { n: "Sketchbot", c: "AI", col: "#ff6ac1", u: 4, t: "Evening", v: "Make", p: "Home", a: "Play", d: 6 },
    { n: "Voicey", c: "AI", col: null, u: null, t: "Anytime", v: "Talk", p: "Everywhere", a: "Learning", d: 3 },
    { n: "Bank", c: "Money", col: "#0b7a3e", u: 10, t: "Evening", v: "Track", p: "Home", a: "Money", d: 800 },
    { n: "Wallet", c: "Money", col: "#202124", u: 14, t: "Anytime", v: "Buy", p: "Everywhere", a: "Money", d: 900 },
    { n: "Stocks", c: "Money", col: "#7a7f8c", u: 5, t: "Morning", v: "Track", p: "Commute", a: "Money", d: 900 },
    { n: "Budget", c: "Money", col: "#36c26b", u: 3, t: "Evening", v: "Track", p: "Home", a: "Money", d: 60 },
    { n: "Maps", c: "Out & About", col: "#34c759", u: 36, t: "Anytime", v: "Go", p: "Travel", a: "Everyday", d: 900 },
    { n: "Rides", c: "Out & About", col: "#141414", u: 8, t: "Evening", v: "Go", p: "Travel", a: "Everyday", d: 500 },
    { n: "Parking", c: "Out & About", col: "#2c7be5", u: 2, t: "Work day", v: "Go", p: "Commute", a: "Everyday", d: 200 },
    { n: "Eats", c: "Out & About", col: "#ff3b30", u: 12, t: "Evening", v: "Buy", p: "Home", a: "Family", d: 450 },
    { n: "Shop", c: "Out & About", col: "#ff9500", u: 15, t: "Evening", v: "Buy", p: "Home", a: "Everyday", d: 700 },
    { n: "Trips", c: "Out & About", col: "#00b3a4", u: 1, t: "Anytime", v: "Go", p: "Travel", a: "Play", d: 30 },
    { n: "Music", c: "Media", col: "#fa2d48", u: 45, t: "Anytime", v: "Listen", p: "Commute", a: "Play", d: 900 },
    { n: "Pods", c: "Media", col: "#9b4dff", u: 30, t: "Morning", v: "Listen", p: "Commute", a: "Learning", d: 900 },
    { n: "Movies", c: "Media", col: "#e50914", u: 14, t: "Evening", v: "Watch", p: "Home", a: "Play", d: 600 },
    { n: "News", c: "Media", col: "#ff2d55", u: 20, t: "Morning", v: "Read", p: "Commute", a: "Learning", d: 900 },
    { n: "Books", c: "Media", col: "#ff8c1a", u: 8, t: "Evening", v: "Read", p: "Home", a: "Learning", d: 900 },
    { n: "Photos", c: "Media", col: "#f7c948", u: 32, t: "Anytime", v: "Browse", p: "Everywhere", a: "Family", d: 900 },
    { n: "Home", c: "Home & Health", col: "#ff9f0a", u: 18, t: "Evening", v: "Tools", p: "Home", a: "Family", d: 500 },
    { n: "Steps", c: "Home & Health", col: "#5ac8fa", u: 12, t: "Morning", v: "Track", p: "Gym", a: "Health", d: 250 },
    { n: "Sleep", c: "Home & Health", col: "#3a2d7d", u: 7, t: "Evening", v: "Track", p: "Home", a: "Health", d: 90 },
    { n: "Health", c: "Home & Health", col: "#ff375f", u: 9, t: "Anytime", v: "Track", p: "Gym", a: "Health", d: 900 },
    { n: "Puzzle", c: "Play", col: "#7b61ff", u: 16, t: "Evening", v: "Play", p: "Commute", a: "Play", d: 150 },
    { n: "Racer", c: "Play", col: "#ff6b00", u: 2, t: "Evening", v: "Play", p: "Home", a: "Play", d: 10 },
    { n: "Friends", c: "Play", col: "#1877f2", u: 38, t: "Anytime", v: "Talk", p: "Everywhere", a: "Family", d: 900 },
    { n: "Garden", c: "Play", col: null, u: null, t: "Morning", v: "Browse", p: "Home", a: "Play", d: 1 },
    { n: "Settings", c: "System", col: "#8e8e93", u: 6, t: "Anytime", v: "Tools", p: "Everywhere", a: "Everyday", d: 900 },
    { n: "Passwords", c: "System", col: "#30d158", u: 5, t: "Anytime", v: "Tools", p: "Everywhere", a: "Everyday", d: 900 },
    { n: "VPN", c: "System", col: "#0a84ff", u: 1, t: "Anytime", v: "Tools", p: "Travel", a: "Everyday", d: 700 },
    { n: "Files", c: "System", col: "#1e90ff", u: 7, t: "Work day", v: "Browse", p: "Office", a: "Work", d: 900 }
  ];

  var DOCK = [
    { n: "Call", col: "#34c759" },
    { n: "Text", col: "#30b0ff" },
    { n: "Web", col: "#5856d6" },
    { n: "Snap", col: "#4a4a52" }
  ];

  var CATEGORIES = ["Daily", "Work", "AI", "Money", "Out & About", "Media", "Home & Health", "Play", "System"];
  var TIMES = ["Morning", "Work day", "Evening", "Anytime"];
  var VERBS = ["Talk", "Watch", "Listen", "Make", "Buy", "Go", "Track", "Read", "Play", "Work", "Browse", "Tools"];
  var PLACES = ["Home", "Commute", "Office", "Travel", "Gym", "Everywhere"];
  var AREAS = ["Work", "Money", "Health", "Family", "Learning", "Play", "Everyday"];
  var BANDS = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Brown", "Gray", "Black"];

  // ---------- helpers ----------
  function chunk(list, size) {
    var out = [];
    for (var i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
    return out.length ? out : [[]];
  }
  function byName(a, b) { return a.n.localeCompare(b.n); }
  function byUse(a, b) { return (b.u || 0) - (a.u || 0) || byName(a, b); }
  function groupBy(list, key, order) {
    return order
      .map(function (g) { return { name: g, apps: list.filter(function (a) { return a[key] === g; }) }; })
      .filter(function (g) { return g.apps.length; });
  }
  function folder(name, apps) { return { folder: name, apps: apps }; }
  // One labeled run of pages per group; a group bigger than a page spills onto more pages.
  function labeledPages(groups, sorter) {
    var pages = [];
    groups.forEach(function (g) {
      chunk(g.apps.slice().sort(sorter || byName), PER_PAGE).forEach(function (p, i) {
        pages.push({ label: i ? g.name + " (more)" : g.name, items: p });
      });
    });
    return pages;
  }
  function plainPages(items) {
    return chunk(items, PER_PAGE).map(function (p) { return { items: p }; });
  }
  function hexToHsl(hex) {
    var r = parseInt(hex.slice(1, 3), 16) / 255, g = parseInt(hex.slice(3, 5), 16) / 255, b = parseInt(hex.slice(5, 7), 16) / 255;
    var max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2, h = 0, s = 0;
    if (max !== min) {
      var d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
      h *= 60;
    }
    return { h: h, s: s, l: l };
  }
  function band(hex) {
    var c = hexToHsl(hex);
    if (c.l < 0.16) return "Black";
    if (c.s < 0.15) return "Gray";
    if (c.h < 14 || c.h >= 345) return "Red";
    if (c.h < 40) return c.l < 0.35 ? "Brown" : "Orange";
    if (c.h < 65) return "Yellow";
    if (c.h < 170) return "Green";
    if (c.h < 250) return "Blue";
    if (c.h < 290) return "Purple";
    return "Pink";
  }

  // A messy "before" order that stays the same on every visit.
  function messy(list) {
    var seed = 7, out = list.slice();
    for (var i = out.length - 1; i > 0; i--) {
      seed = (seed * 9301 + 49297) % 233280;
      var j = Math.floor((seed / 233280) * (i + 1));
      var t = out[i]; out[i] = out[j]; out[j] = t;
    }
    return out;
  }

  // ---------- the layouts ----------
  var LAYOUTS = [
    {
      id: "before", group: "before", title: "Before: the mess", host: "c-scoot",
      text: "This is the sample phone as Scoot found it: apps wherever they landed when they were installed.",
      build: function () { return plainPages(messy(APPS)); }
    },
    {
      id: "category-pages", group: "now", title: "Category pages", host: "c-sortle",
      text: "Apps stay loose, clustered by what they do: all the Money apps together, then Media, and so on. Add --one-page-per-category to give each group its own page.",
      build: function () {
        var items = [];
        groupBy(APPS, "c", CATEGORIES).forEach(function (g) { items = items.concat(g.apps.slice().sort(byName)); });
        return plainPages(items);
      }
    },
    {
      id: "folder-board", group: "now", title: "Folder board", host: "c-gridley",
      text: "One named folder for each category, gathered on as few pages as possible. Tap a folder to look inside.",
      build: function () {
        return plainPages(groupBy(APPS, "c", CATEGORIES).map(function (g) { return folder(g.name, g.apps.slice().sort(byName)); }));
      }
    },
    {
      id: "alphabetical", group: "new", title: "Alphabetical", host: "c-pagelet",
      text: "A to Z, no thinking needed. Add --letter-folders to get one folder per letter instead.",
      build: function () { return plainPages(APPS.slice().sort(byName)); }
    },
    {
      id: "most-used", group: "new", title: "Most used", host: "c-scoot",
      text: "Your busiest apps come first. It reads how often you open each app from a --usage file. Without one, it keeps your current order.",
      build: function () { return plainPages(APPS.slice().sort(byUse)); }
    },
    {
      id: "time-of-day", group: "new", title: "Time of day", host: "c-lumi",
      text: "A page for each part of the day: Morning, Work day, Evening and Anytime. Swipe through your day.",
      build: function () { return labeledPages(groupBy(APPS, "t", TIMES), byUse); }
    },
    {
      id: "verb-folders", group: "new", title: "Verb folders", host: "c-sortle",
      text: "Folders named for what you want to do: Talk, Watch, Listen, Make, Buy, Go, Track, Read, Play, Work, Browse and Tools.",
      build: function () {
        return plainPages(groupBy(APPS, "v", VERBS).map(function (g) { return folder(g.name, g.apps.slice().sort(byUse)); }));
      }
    },
    {
      id: "rainbow", group: "new", title: "Rainbow", host: "c-lumi",
      text: "Color bands from red through black, then the apps with no color data (striped here). Colors come from an --icon-colors file plus a built-in table for Apple's apps. They are not read from the phone.",
      build: function () {
        var colored = APPS.filter(function (a) { return a.col; });
        var none = APPS.filter(function (a) { return !a.col; }).sort(byName);
        var items = [];
        BANDS.forEach(function (b) {
          items = items.concat(colored.filter(function (a) { return band(a.col) === b; })
            .sort(function (x, y) { return hexToHsl(x.col).l - hexToHsl(y.col).l; }));
        });
        return plainPages(items.concat(none));
      }
    },
    {
      id: "thumb-reach", group: "new", title: "Thumb reach", host: "c-gridley",
      text: "Like Most used, but on each page the top apps go in the bottom rows, where your thumb rests.",
      build: function () {
        return chunk(APPS.slice().sort(byUse), PER_PAGE).map(function (p) {
          // Busiest apps fill the last rows; the quietest end up at the top.
          return { items: p.slice().reverse() };
        });
      }
    },
    {
      id: "places", group: "new", title: "Places", host: "c-scoot",
      text: "A page for each place you use your phone: Home, Commute, Office, Travel, Gym and Everywhere.",
      build: function () { return labeledPages(groupBy(APPS, "p", PLACES), byUse); }
    },
    {
      id: "new-and-review", group: "new", title: "New and review", host: "c-pagelet",
      text: "Your newest apps on page 1, the rest by category, and a Review page for apps the --usage file never saw. Handy for a clean-out.",
      build: function () {
        var review = APPS.filter(function (a) { return a.u === null; }).sort(byName);
        var rest = APPS.filter(function (a) { return a.u !== null; });
        var fresh = rest.filter(function (a) { return a.d <= 30; }).sort(function (a, b) { return a.d - b.d; });
        var older = rest.filter(function (a) { return a.d > 30; });
        var pages = [{ label: "New", items: fresh }];
        var byCat = [];
        groupBy(older, "c", CATEGORIES).forEach(function (g) { byCat = byCat.concat(g.apps.slice().sort(byName)); });
        chunk(byCat, PER_PAGE).forEach(function (p) { pages.push({ label: "By category", items: p }); });
        if (review.length) pages.push({ label: "Review", items: review });
        return pages;
      }
    },
    {
      id: "essentials", group: "new", title: "Essentials", host: "c-rewindle",
      text: "One calm page of essentials (12 by default, change it with --essentials), and the rest in folders on later pages. No app is removed.",
      build: function () {
        var sorted = APPS.slice().sort(byUse);
        var top = sorted.slice(0, 12);
        var rest = sorted.slice(12);
        var folders = groupBy(rest, "c", CATEGORIES).map(function (g) { return folder(g.name, g.apps.slice().sort(byName)); });
        return [{ label: "Essentials", items: top }].concat(
          chunk(folders, PER_PAGE).map(function (p) { return { label: "Everything else", items: p }; })
        );
      }
    },
    {
      id: "life-areas", group: "new", title: "Life areas", host: "c-sortle",
      text: "A page for each part of your life: Work, Money, Health, Family, Learning, Play and Everyday.",
      build: function () { return labeledPages(groupBy(APPS, "a", AREAS), byUse); }
    }
  ];

  // ---------- rendering ----------
  var $ = function (id) { return document.getElementById(id); };
  var grid = $("grid"), dock = $("dock"), dots = $("dots"), label = $("page-label");
  var folderView = $("folder-view"), folderGrid = $("folder-grid"), folderDots = $("folder-dots");
  var state = { layout: null, pages: [], page: 0, folder: null, folderPage: 0, lastFocus: null };

  function initials(name) { return name.slice(0, 1); }

  function iconEl(app, tag) {
    var el = document.createElement(tag || "div");
    el.className = "icon";
    var tile = document.createElement("span");
    tile.className = "tile" + (app.col ? "" : " nocolor");
    if (app.col) tile.style.background = "linear-gradient(160deg, " + app.col + ", " + shade(app.col) + ")";
    tile.textContent = initials(app.n);
    tile.setAttribute("aria-hidden", "true");
    var lab = document.createElement("span");
    lab.className = "label";
    lab.textContent = app.n;
    el.appendChild(tile);
    el.appendChild(lab);
    return el;
  }

  function shade(hex) {
    var n = parseInt(hex.slice(1), 16);
    var r = Math.max(0, (n >> 16) - 40), g = Math.max(0, ((n >> 8) & 255) - 40), b = Math.max(0, (n & 255) - 40);
    return "rgb(" + r + "," + g + "," + b + ")";
  }

  function folderEl(f) {
    var el = document.createElement("button");
    el.type = "button";
    el.className = "icon folder";
    el.setAttribute("aria-label", f.folder + " folder, " + f.apps.length + " apps");
    var tile = document.createElement("span");
    tile.className = "tile";
    tile.setAttribute("aria-hidden", "true");
    f.apps.slice(0, 9).forEach(function (a) {
      var m = document.createElement("i");
      m.className = "mini";
      m.style.background = a.col || "#a7acbd";
      tile.appendChild(m);
    });
    var lab = document.createElement("span");
    lab.className = "label";
    lab.textContent = f.folder;
    el.appendChild(tile);
    el.appendChild(lab);
    el.addEventListener("click", function () { openFolder(f, el); });
    return el;
  }

  function renderDots(container, count, on) {
    container.innerHTML = "";
    if (count < 2) return;
    for (var i = 0; i < count; i++) {
      var d = document.createElement("i");
      if (i === on) d.className = "on";
      container.appendChild(d);
    }
  }

  function renderPage(animate) {
    var page = state.pages[state.page];
    grid.innerHTML = "";
    page.items.forEach(function (item) { grid.appendChild(item.folder ? folderEl(item) : iconEl(item)); });
    if (page.label) { label.textContent = page.label; label.hidden = false; } else { label.hidden = true; }
    renderDots(dots, state.pages.length, state.page);
    $("page-count").textContent = "Page " + (state.page + 1) + " of " + state.pages.length;
    $("prev").disabled = state.page === 0;
    $("next").disabled = state.page === state.pages.length - 1;
    if (animate) { grid.classList.remove("swap"); void grid.offsetWidth; grid.classList.add("swap"); }
  }

  function renderDock() {
    dock.innerHTML = "";
    DOCK.forEach(function (a) { dock.appendChild(iconEl(a)); });
  }

  function choose(id) {
    var layout = LAYOUTS.filter(function (l) { return l.id === id; })[0] || LAYOUTS[0];
    state.layout = layout;
    state.pages = layout.build();
    state.page = 0;
    closeFolder();
    document.querySelectorAll(".chip").forEach(function (c) {
      c.setAttribute("aria-pressed", String(c.dataset.id === layout.id));
    });
    $("host-title").textContent = layout.title;
    setTextWithFlags($("host-text"), layout.text);
    // The new layouts are not in 0.1.0 yet, so only show a command for ones that ship today.
    $("host-cmd").textContent = layout.group === "now" ? "organize-my-iphone apply " + layout.id + " --dry-run" : "";
    $("host-soon").hidden = layout.group !== "new";
    $("host-c").querySelector("use").setAttribute("href", "#" + layout.host);
    renderPage(true);
    checkLimits();
  }

  // Show command-line flags such as --usage as code that never breaks across lines.
  function setTextWithFlags(el, text) {
    el.textContent = "";
    text.split(/(--[a-z-]+)/).forEach(function (part) {
      if (!part) return;
      if (part.indexOf("--") === 0) {
        var c = document.createElement("code");
        c.className = "flag";
        c.textContent = part;
        el.appendChild(c);
      } else {
        el.appendChild(document.createTextNode(part));
      }
    });
  }

  function go(delta) {
    var next = state.page + delta;
    if (next < 0 || next >= state.pages.length) return;
    state.page = next;
    renderPage(true);
  }

  function openFolder(f, trigger) {
    state.folder = f;
    state.folderPage = 0;
    state.lastFocus = trigger;
    $("folder-name").textContent = f.folder;
    renderFolder();
    folderView.hidden = false;
    $("folder-close").focus();
  }
  function renderFolder() {
    var pages = chunk(state.folder.apps, PER_FOLDER_PAGE);
    folderGrid.innerHTML = "";
    pages[state.folderPage].forEach(function (a) { folderGrid.appendChild(iconEl(a)); });
    renderDots(folderDots, pages.length, state.folderPage);
  }
  function closeFolder() {
    if (!state.folder) return;
    state.folder = null;
    folderView.hidden = true;
    if (state.lastFocus && document.body.contains(state.lastFocus)) state.lastFocus.focus();
  }
  function folderGo(delta) {
    var count = chunk(state.folder.apps, PER_FOLDER_PAGE).length;
    var next = state.folderPage + delta;
    if (next < 0 || next >= count) return;
    state.folderPage = next;
    renderFolder();
  }

  // Sanity check that each layout keeps to the same limits the tool enforces.
  function checkLimits() {
    var seen = {};
    state.pages.forEach(function (p) {
      if (p.items.length > PER_PAGE) console.warn("Page over 24 icons in", state.layout.id);
      p.items.forEach(function (it) {
        (it.folder ? it.apps : [it]).forEach(function (a) { seen[a.n] = (seen[a.n] || 0) + 1; });
      });
    });
    var placed = Object.keys(seen);
    if (placed.length !== APPS.length || placed.some(function (k) { return seen[k] !== 1; })) {
      console.warn("Layout", state.layout.id, "does not place every app exactly once");
    }
  }

  // ---------- wiring ----------
  LAYOUTS.forEach(function (l) {
    var b = document.createElement("button");
    b.type = "button";
    b.className = "chip";
    b.dataset.id = l.id;
    b.textContent = l.title;
    b.setAttribute("aria-pressed", "false");
    b.addEventListener("click", function () { choose(l.id); });
    $("chips-" + l.group).appendChild(b);
  });

  $("prev").addEventListener("click", function () { go(-1); });
  $("next").addEventListener("click", function () { go(1); });
  $("folder-close").addEventListener("click", closeFolder);
  folderView.addEventListener("click", function (e) { if (e.target === folderView) closeFolder(); });

  document.addEventListener("keydown", function (e) {
    if (state.folder) {
      if (e.key === "Escape") closeFolder();
      if (e.key === "ArrowLeft") folderGo(-1);
      if (e.key === "ArrowRight") folderGo(1);
      return;
    }
    var inPlay = document.activeElement && document.activeElement.closest && document.activeElement.closest(".play");
    if (!inPlay) return;
    if (e.key === "ArrowLeft") go(-1);
    if (e.key === "ArrowRight") go(1);
  });

  // Swipe between pages (or folder pages) with a finger or mouse drag.
  var startX = null;
  var phone = $("phone");
  phone.addEventListener("pointerdown", function (e) { startX = e.clientX; });
  phone.addEventListener("pointerup", function (e) {
    if (startX === null) return;
    var dx = e.clientX - startX;
    startX = null;
    if (Math.abs(dx) < 40) return;
    if (state.folder) folderGo(dx < 0 ? 1 : -1); else go(dx < 0 ? 1 : -1);
  });

  renderDock();
  var fromHash = location.hash.replace("#layout-", "");
  choose(LAYOUTS.some(function (l) { return l.id === fromHash; }) ? fromHash : "before");
})();
