(function () {
  "use strict";

  var baseurl = (window.GameClub && window.GameClub.baseurl) || "";
  var shareModalSelectedOccurrences = null;
  var shareModalEscapeHandler = null;

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

  function buildMarkdown(occList, wrapForDiscord) {
    if (occList.length === 0) return "";
    var siteUrl = window.location.origin + (baseurl || "") + "/";
    var wrap = function (url) {
      return wrapForDiscord ? "<" + url + ">" : url;
    };
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
        lines.push("- [More information](" + wrap(eventLink) + ")");
        lines.push("");
      });
    });
    if (slugs.length === 1) {
      lines.push("Find [this group](" + wrap(siteUrl + "clubs/" + encodeURIComponent(slugs[0]) + "/") + ") and more on [botc-events.uk](" + wrap(siteUrl) + ")");
    } else {
      lines.push("Find these groups and more on [botc-events.uk](" + wrap(siteUrl) + ")");
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
      discordCheckbox: document.getElementById("share-events-modal-discord"),
    };
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
    function showToast() {
      if (window.showShareToast) window.showShareToast("Copied to clipboard");
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(
        showToast,
        function () {
          if (document.execCommand) document.execCommand("copy", false, text);
          showToast();
        }
      );
    } else if (document.execCommand) {
      document.execCommand("copy", false, text);
      showToast();
    }
  }

  function show(selected) {
    if (!selected || selected.length === 0) return;
    var el = getModalElements();
    if (!el.modal || !el.code) return;
    shareModalSelectedOccurrences = selected;
    if (el.discordCheckbox) el.discordCheckbox.checked = true;
    var markdown = buildMarkdown(selected, true);
    el.code.textContent = markdown;
    el.modal.removeAttribute("hidden");
    el.modal.setAttribute("aria-hidden", "false");
    el.modal.scrollTop = 0;
    var content = el.modal.querySelector(".share-events-modal__content");
    if (content) {
      if (!content.hasAttribute("tabindex")) content.setAttribute("tabindex", "-1");
      content.focus();
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(markdown).then(
        function () {
          if (window.showShareToast) window.showShareToast("Copied to clipboard");
        },
        function () {}
      );
    }
    if (window.lucide) lucide.createIcons();
    if (shareModalEscapeHandler) document.removeEventListener("keydown", shareModalEscapeHandler);
    shareModalEscapeHandler = function (e) {
      if (e.key === "Escape") hideShareModal();
    };
    document.addEventListener("keydown", shareModalEscapeHandler);
  }

  function init() {
    var el = getModalElements();
    if (!el.modal) return;
    if (el.backdrop) el.backdrop.addEventListener("click", hideShareModal);
    if (el.closeBtn) el.closeBtn.addEventListener("click", hideShareModal);
    if (el.copyBtn) el.copyBtn.addEventListener("click", copyModalToClipboard);
    if (el.discordCheckbox) {
      el.discordCheckbox.addEventListener("change", function () {
        if (shareModalSelectedOccurrences && shareModalSelectedOccurrences.length > 0) {
          var modalEl = getModalElements();
          if (modalEl.code) modalEl.code.textContent = buildMarkdown(shareModalSelectedOccurrences, this.checked);
        }
      });
    }
  }

  window.ShareEventsModal = { show: show };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
