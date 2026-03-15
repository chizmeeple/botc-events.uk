(function () {
  "use strict";

  var baseurl = window.GameClub ? window.GameClub.baseurl : "";
  var shareMode = false;
  var shareModalEscapeHandler = null;

  function getEventsData() {
    var el = document.getElementById("club-events-data");
    if (!el || !el.textContent) return [];
    try {
      return JSON.parse(el.textContent);
    } catch (e) {
      return [];
    }
  }

  function formatTime(iso) {
    if (!iso) return "";
    var d = new Date(iso);
    var h = d.getHours();
    var m = d.getMinutes();
    return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
  }

  function formatDate(iso) {
    if (!iso) return "";
    var d = new Date(iso);
    var days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
    var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    var day = days[d.getDay()];
    var date = d.getDate();
    var month = months[d.getMonth()];
    var year = d.getFullYear();
    return day + ", " + (date < 10 ? "0" : "") + date + " " + month + " " + year;
  }

  function getSelectedOccurrences(allEvents) {
    var checkboxes = document.querySelectorAll("#club-upcoming-events .share-checkbox:checked");
    var occs = [];
    for (var i = 0; i < checkboxes.length; i++) {
      var slug = checkboxes[i].getAttribute("data-slug");
      var startTime = checkboxes[i].getAttribute("data-start-time");
      var occ = allEvents.find(function (o) {
        return o.slug === slug && o.start_time === startTime;
      });
      if (occ) occs.push(occ);
    }
    return occs;
  }

  function buildMarkdown(occList) {
    if (occList.length === 0) return "";
    var siteUrl = window.location.origin + (baseurl || "") + "/";
    var lines = [];
    var bySlug = {};
    occList.forEach(function (occ) {
      if (!bySlug[occ.slug]) bySlug[occ.slug] = { club_name: occ.club_name, items: [] };
      bySlug[occ.slug].items.push(occ);
    });
    var slugs = Object.keys(bySlug);
    slugs.forEach(function (slug) {
      var group = bySlug[slug];
      var groupUrl = siteUrl + "clubs/" + encodeURIComponent(slug) + "/";
      lines.push("## " + group.club_name);
      lines.push("");
      group.items.forEach(function (occ) {
        var startDate = formatDate(occ.start_time);
        var startTime = formatTime(occ.start_time);
        var loc = occ.location || {};
        var locName = loc.name || "";
        var locAddr = loc.address || "";
        var cost = occ.cost != null && occ.cost !== "" ? occ.cost : "Free";
        var eventLink = occ.signup || groupUrl;
        lines.push("### " + occ.eventname);
        lines.push("");
        lines.push("- " + startDate + " ⋅ " + startTime);
        if (locName || locAddr) {
          var locLine = locName ? "**" + locName + "**" : "";
          if (locAddr) locLine += (locLine ? ", " : "") + locAddr;
          lines.push("- " + locLine);
        }
        lines.push("- Cost: " + cost);
        lines.push("- [More information](" + eventLink + ")");
        lines.push("");
      });
    });
    if (slugs.length === 1) {
      lines.push("Find [this group](" + siteUrl + "clubs/" + encodeURIComponent(slugs[0]) + "/) and more on [botc-events.uk](" + siteUrl + ")");
    } else {
      lines.push("Find these groups and more on [botc-events.uk](" + siteUrl + ")");
    }
    return lines.join("\n");
  }

  function getModalElements() {
    return {
      modal: document.getElementById("share-events-modal"),
      code: document.getElementById("share-events-modal-code"),
      copyBtn: document.getElementById("share-events-modal-copy"),
      closeBtn: document.getElementById("share-events-modal-close"),
      backdrop: document.querySelector("#share-events-modal .share-events-modal__backdrop"),
    };
  }

  function showShareModal(markdown) {
    var el = getModalElements();
    if (!el.modal || !el.code) return;
    el.code.textContent = markdown;
    el.modal.removeAttribute("hidden");
    el.modal.setAttribute("aria-hidden", "false");
    if (el.copyBtn) el.copyBtn.focus();
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(markdown).catch(function () {});
    }
    if (window.lucide) lucide.createIcons();
    if (shareModalEscapeHandler) document.removeEventListener("keydown", shareModalEscapeHandler);
    shareModalEscapeHandler = function (e) {
      if (e.key === "Escape") hideShareModal();
    };
    document.addEventListener("keydown", shareModalEscapeHandler);
  }

  function hideShareModal() {
    var el = getModalElements();
    if (!el.modal) return;
    el.modal.setAttribute("hidden", "");
    el.modal.setAttribute("aria-hidden", "true");
    if (shareModalEscapeHandler) {
      document.removeEventListener("keydown", shareModalEscapeHandler);
      shareModalEscapeHandler = null;
    }
  }

  function copyModalToClipboard() {
    var el = getModalElements();
    if (!el.code) return;
    var text = el.code.textContent;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(
        function () {},
        function () {
          if (document.execCommand) document.execCommand("copy", false, text);
        }
      );
    } else if (document.execCommand) {
      document.execCommand("copy", false, text);
    }
  }

  function updateShareButtonLabel() {
    var btn = document.getElementById("share-events-btn");
    if (!btn) return;
    btn.textContent = shareMode ? "Copy Information" : "Share Event Information";
  }

  function init() {
    var eventsDataEl = document.getElementById("club-events-data");
    var shareBtn = document.getElementById("share-events-btn");
    var container = document.getElementById("club-upcoming-events");
    if (!eventsDataEl || !shareBtn || !container) return;

    var allEvents = getEventsData();
    if (allEvents.length === 0) return;

    shareBtn.addEventListener("click", function () {
      if (!shareMode) {
        shareMode = true;
        updateShareButtonLabel();
        container.classList.add("club-upcoming-events--share-mode");
        return;
      }
      var selected = getSelectedOccurrences(allEvents);
      if (selected.length === 0) return;
      var markdown = buildMarkdown(selected);
      showShareModal(markdown);
    });

    var modalEl = getModalElements();
    if (modalEl.backdrop) modalEl.backdrop.addEventListener("click", hideShareModal);
    if (modalEl.closeBtn) modalEl.closeBtn.addEventListener("click", hideShareModal);
    if (modalEl.copyBtn) modalEl.copyBtn.addEventListener("click", copyModalToClipboard);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
