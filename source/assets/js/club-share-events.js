(function () {
  "use strict";

  var shareMode = false;

  function getEventsData() {
    var el = document.getElementById("club-events-data");
    if (!el || !el.textContent) return [];
    try {
      return JSON.parse(el.textContent);
    } catch (e) {
      return [];
    }
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
      if (window.ShareEventsModal) window.ShareEventsModal.show(selected);
    });

    var selectAllBtn = document.getElementById("club-select-all-btn");
    if (selectAllBtn) {
      selectAllBtn.addEventListener("click", function () {
        var checkboxes = container.querySelectorAll(".share-checkbox");
        for (var i = 0; i < checkboxes.length; i++) checkboxes[i].checked = true;
      });
    }

    var doneBtn = document.getElementById("share-events-done-btn");
    if (doneBtn) {
      doneBtn.addEventListener("click", function () {
        shareMode = false;
        updateShareButtonLabel();
        container.classList.remove("club-upcoming-events--share-mode");
        var checkboxes = container.querySelectorAll(".share-checkbox");
        for (var i = 0; i < checkboxes.length; i++) checkboxes[i].checked = false;
      });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
