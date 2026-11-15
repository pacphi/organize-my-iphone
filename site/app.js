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
  // The same 11 slices, in the same order, as the tool's ColorBand.
  var BANDS = ["Red", "Orange", "Yellow", "Green", "Teal", "Blue", "Purple", "Pink", "White", "Gray", "Black"];
  var BAND_SWATCH = {
    Red: "#FF3B30", Orange: "#FF9500", Yellow: "#FFD60A", Green: "#34C759", Teal: "#30B0C7", Blue: "#007AFF",
    Purple: "#8E44D9", Pink: "#FF2D92", White: "#F2F2F7", Gray: "#8E8E93", Black: "#1C1C1E"
  };

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
        pages.push({ label: i ? g.name + " (" + (i + 1) + ")" : g.name, items: p });
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
  // Mirrors ColorBand.of in the tool: hue, saturation and brightness (HSB).
  function band(hex) {
    var r = parseInt(hex.slice(1, 3), 16) / 255, g = parseInt(hex.slice(3, 5), 16) / 255, b = parseInt(hex.slice(5, 7), 16) / 255;
    var max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min, h = 0;
    var sat = max === 0 ? 0 : d / max, bright = max;
    if (d) {
      h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
      h *= 60;
    }
    if (bright < 0.22) return "Black";
    if (sat < 0.18) return bright > 0.85 ? "White" : bright < 0.3 ? "Black" : "Gray";
    if (h >= 15 && h < 45) return "Orange";
    if (h >= 45 && h < 70) return "Yellow";
    if (h >= 70 && h < 165) return "Green";
    if (h >= 165 && h < 195) return "Teal";
    if (h >= 195 && h < 255) return "Blue";
    if (h >= 255 && h < 290) return "Purple";
    if (h >= 290 && h < 345) return "Pink";
    return "Red";
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
      id: "before", group: "before", title: "Before: the mess", host: "c-scoot", who: "Scoot",
      text: "This is the sample phone as Scoot found it: apps wherever they landed when they were installed.",
      build: function () { return plainPages(messy(APPS)); }
    },
    {
      id: "category-pages", group: "now", title: "Category pages", host: "c-sortle", who: "Sortle",
      text: "Apps stay loose, clustered by what they do: all the Money apps together, then Media, and so on. Add --one-page-per-category to give each group its own page.",
      build: function () {
        var items = [];
        groupBy(APPS, "c", CATEGORIES).forEach(function (g) { items = items.concat(g.apps.slice().sort(byName)); });
        return plainPages(items);
      }
    },
    {
      id: "folder-board", group: "now", title: "Folder board", host: "c-gridley", who: "Gridley",
      text: "One named folder for each category, gathered on as few pages as possible. Tap a folder to look inside.",
      build: function () {
        return plainPages(groupBy(APPS, "c", CATEGORIES).map(function (g) { return folder(g.name, g.apps.slice().sort(byName)); }));
      }
    },
    {
      id: "alphabetical", group: "new", title: "Alphabetical", host: "c-blockapede", who: "Blockapede",
      text: "Blockapede is made of letters, so of course it sorts A to Z. No thinking needed. Add --letter-folders for one folder per letter.",
      build: function () {
        return chunk(APPS.slice().sort(byName), PER_PAGE).map(function (p) {
          return { label: p[0].n[0] + "\u2013" + p[p.length - 1].n[0], items: p };
        });
      }
    },
    {
      id: "most-used", group: "new", title: "Most used", host: "c-toppy", who: "Toppy",
      text: "Toppy wears the crown, and so do your busiest apps: they fill page 1. Usage comes from a --usage file (copy the order from Screen Time). No file? Your current icon order stands in, and the preview says so.",
      build: function () { return plainPages(APPS.slice().sort(byUse)); }
    },
    {
      id: "time-of-day", group: "new", title: "Time of day", host: "c-dayzee", who: "Dayzee",
      text: "Dayzee is always half awake. Every part of the day gets its own page: Morning, Work day, Evening and Anytime. Pair the pages with a Focus in Settings for a Home Screen that changes with your day.",
      build: function () { return labeledPages(groupBy(APPS, "t", TIMES), byUse); }
    },
    {
      id: "verb-folders", group: "new", title: "Verb folders", host: "c-verbie", who: "Verbie",
      text: "Verbie has four hands and things to do. Folders are named for actions: Talk, Watch, Listen, Make, Buy, Go, Track, Read, Play, Work, Browse and Tools.",
      build: function () {
        return plainPages(groupBy(APPS, "v", VERBS).map(function (g) { return folder(g.name, g.apps.slice().sort(byUse)); }));
      }
    },
    {
      id: "rainbow", group: "new", title: "Rainbow", host: "c-rainbelle", who: "Rainbelle",
      text: "Rainbelle lives in a rainbow and thinks you should too. Apps go in 11 color bands, red through black, then any with no color data (striped here). Colors come from a built-in table for Apple's apps, from App Store icons if you add --icon-colors-from-store, and from your own --icon-colors file, which wins. Wrong match? Fix it on the color wheel below.",
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
      id: "thumb-reach", group: "new", title: "Thumb reach", host: "c-reachlet", who: "Reachlet",
      text: "Reachlet has one very long arm and no patience for top rows. Same order as Most used, but on every full page the top apps sit in the bottom rows: rank 1 bottom left. A page that isn't full keeps plain order, because iOS slides icons up to fill gaps.",
      build: function () {
        return chunk(APPS.slice().sort(byUse), PER_PAGE).map(function (p) {
          // As in the tool: on a full page, rank 1 sits bottom left and the bottom row fills first.
          // A page that isn't full keeps plain rank order, because iOS moves icons up to fill gaps.
          if (p.length < PER_PAGE) return { items: p };
          var rows = chunk(p, 4).reverse();
          return { items: [].concat.apply([], rows) };
        });
      }
    },
    {
      id: "places", group: "new", title: "Places", host: "c-packpin", who: "Packpin",
      text: "Packpin goes everywhere. Each place gets its own page: Home, Commute, Office, Travel, Gym and Everywhere. Pair them with a Focus in Settings so the right page shows up in the right place.",
      build: function () { return labeledPages(groupBy(APPS, "p", PLACES), byUse); }
    },
    {
      id: "new-and-review", group: "new", title: "New and review", host: "c-lensley", who: "Lensley",
      text: "Lensley looks very closely. Your newest apps go on page 1 (from a --recent file, or a best guess from your layout), the rest by category, and a Review page at the back holds apps your --usage file never mentions. Delete candidates, basically.",
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
      id: "essentials", group: "new", title: "Essentials", host: "c-pebbs", who: "Pebbs",
      text: "Pebbs keeps it calm: one page of essentials (12 by default, up to 24 with --essentials) and everything else in category folders on later pages. No app is removed. Tip: hide the other pages on the phone for a truly zen Home Screen.",
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
      id: "life-areas", group: "new", title: "Life areas", host: "c-slicey", who: "Slicey",
      text: "Slicey is a pie chart of your whole life. You get a page for each slice: Work, Money, Health, Family, Learning, Play and Everyday.",
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
    $("host-name").textContent = layout.who;
    setTextWithFlags($("host-text"), layout.text);
    // The new layouts are not in 0.1.0 yet, so only show a command for ones that ship today.
    $("host-cmd").textContent = layout.group === "before" ? "" : "organize-my-iphone apply " + layout.id + " --dry-run";
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

  // ---------- Rainbelle's color wheel ----------
  // Like colors.html from the tool: one slice per band, sized by app count. Click a slice to see its apps.
  function buildWheel() {
    var host = $("wheel"), list = $("wheel-list"), legend = $("wheel-legend");
    if (!host) return;
    var NS = "http://www.w3.org/2000/svg";
    var groups = {};
    BANDS.forEach(function (b) { groups[b] = []; });
    var none = [];
    APPS.forEach(function (a) { if (a.col) groups[band(a.col)].push(a); else none.push(a); });
    var cx = 110, cy = 110, R = 100, r = 46, step = (Math.PI * 2) / BANDS.length;
    var buttons = {};

    function pick(b) {
      Object.keys(buttons).forEach(function (k) {
        buttons[k].btn.setAttribute("aria-pressed", String(k === b));
        buttons[k].path.classList.toggle("on", k === b);
      });
      var apps = b === "none" ? none : groups[b];
      $("wheel-title").textContent = b === "none" ? "No color data" : b;
      list.textContent = "";
      if (!apps.length) {
        var li = document.createElement("li");
        li.className = "wheel-empty";
        li.textContent = "No sample apps landed here.";
        list.appendChild(li);
      }
      apps.slice().sort(byName).forEach(function (a) { list.appendChild(iconEl(a, "li")); });
    }

    BANDS.forEach(function (b, i) {
      var a0 = i * step - Math.PI / 2, a1 = a0 + step;
      var p = function (rad, ang) { return (cx + rad * Math.cos(ang)).toFixed(2) + " " + (cy + rad * Math.sin(ang)).toFixed(2); };
      var path = document.createElementNS(NS, "path");
      path.setAttribute("d", "M" + p(R, a0) + " A" + R + " " + R + " 0 0 1 " + p(R, a1) + " L" + p(r, a1) +
        " A" + r + " " + r + " 0 0 0 " + p(r, a0) + " Z");
      path.setAttribute("fill", BAND_SWATCH[b]);
      path.setAttribute("class", "slice");
      path.addEventListener("click", function () { pick(b); });
      var mid = a0 + step / 2;
      var t = document.createElementNS(NS, "text");
      t.setAttribute("x", (cx + 74 * Math.cos(mid)).toFixed(1));
      t.setAttribute("y", (cy + 74 * Math.sin(mid) + 5).toFixed(1));
      t.setAttribute("class", "slice-n" + (b === "White" || b === "Yellow" ? " dark" : ""));
      t.textContent = groups[b].length;
      host.appendChild(path);
      host.appendChild(t);

      var btn = document.createElement("button");
      btn.type = "button";
      btn.className = "chip wheel-chip";
      btn.setAttribute("aria-pressed", "false");
      var sw = document.createElement("i");
      sw.style.background = BAND_SWATCH[b];
      btn.appendChild(sw);
      btn.appendChild(document.createTextNode(b + " · " + groups[b].length));
      btn.addEventListener("click", function () { pick(b); });
      legend.appendChild(btn);
      buttons[b] = { btn: btn, path: path };
    });
    var nb = document.createElement("button");
    nb.type = "button";
    nb.className = "chip wheel-chip";
    nb.setAttribute("aria-pressed", "false");
    var nsw = document.createElement("i");
    nsw.className = "nocolor";
    nb.appendChild(nsw);
    nb.appendChild(document.createTextNode("No color data · " + none.length));
    nb.addEventListener("click", function () { pick("none"); });
    legend.appendChild(nb);
    buttons.none = { btn: nb, path: document.createElementNS(NS, "path") };

    var biggest = BANDS.reduce(function (best, b) { return groups[b].length > groups[best].length ? b : best; }, BANDS[0]);
    pick(biggest);
  }

  // ---------- wiring ----------
  LAYOUTS.forEach(function (l) {
    var b = document.createElement("button");
    b.type = "button";
    b.className = "chip";
    b.dataset.id = l.id;
    var ic = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    ic.setAttribute("class", "chip-c");
    ic.setAttribute("aria-hidden", "true");
    var u = document.createElementNS("http://www.w3.org/2000/svg", "use");
    u.setAttribute("href", "#" + l.host);
    ic.appendChild(u);
    b.appendChild(ic);
    b.appendChild(document.createTextNode(l.title));
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
  buildWheel();
  var fromHash = location.hash.replace("#layout-", "");
  choose(LAYOUTS.some(function (l) { return l.id === fromHash; }) ? fromHash : "before");
})();
