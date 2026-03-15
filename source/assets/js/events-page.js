(function () {
  "use strict";

  var baseurl = window.GameClub ? window.GameClub.baseurl : "";
  var STORAGE_KEY = "gameclub_user_location";
  var allEvents = [];
  var dayFilters = [];
  var maxDistance = 0;
  var userLat = null;
  var userLng = null;
  var shareMode = false;

  function getEventsData() {
    var el = document.getElementById("events-data");
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

  function dateKey(iso) {
    if (!iso) return "";
    var d = new Date(iso);
    return d.getFullYear() + "-" + (d.getMonth() + 1 < 10 ? "0" : "") + (d.getMonth() + 1) + "-" + (d.getDate() < 10 ? "0" : "") + d.getDate();
  }

  function dayOfWeek(iso) {
    if (!iso) return "";
    var d = new Date(iso);
    var days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
    return days[d.getDay()];
  }

  function haversine(lat1, lng1, lat2, lng2) {
    var R = 3959;
    var dLat = ((lat2 - lat1) * Math.PI) / 180;
    var dLng = ((lng2 - lng1) * Math.PI) / 180;
    var a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLng / 2) *
        Math.sin(dLng / 2);
    var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  function escapeHtml(text) {
    if (!text) return "";
    var div = document.createElement("div");
    div.appendChild(document.createTextNode(text));
    return div.innerHTML;
  }

  function renderEventCard(occ) {
    var loc = occ.location || {};
    var startStr = formatTime(occ.start_time);
    var endStr = occ.end_time ? formatTime(occ.end_time) : null;
    var datetimeStr = formatDate(occ.start_time) + ", " + startStr;
    if (endStr && endStr !== startStr) datetimeStr += "–" + endStr;
    else datetimeStr += " start";

    var venueBlock = "";
    if (loc.name || loc.address) {
      var venue = "";
      if (loc.name) {
        var dirs = "";
        if (loc.lat && loc.lng) {
          dirs = ' <a href="https://www.google.com/maps/dir/?api=1&destination=' + loc.lat + "," + loc.lng + '" target="_blank" rel="noopener" class="directions-link"><i data-lucide="navigation" style="width: 13px; height: 13px"></i> Directions</a>';
        }
        venue = '<div class="upcoming-event-card__venue">' + escapeHtml(loc.name) + dirs + "</div>";
      }
      var addr = loc.address ? '<div class="upcoming-event-card__address">' + escapeHtml(loc.address) + "</div>" : "";
      venueBlock = '<div class="upcoming-event-card__venue-block">' + venue + addr + "</div>";
    }

    var freq = occ.frequency || dayOfWeek(occ.start_time);
    var cost = occ.cost ? '<span class="upcoming-event-card__cost">' + escapeHtml(occ.cost) + "</span>" : "";
    var signup = occ.signup ? '<a href="' + escapeHtml(occ.signup) + '" target="_blank" rel="noopener" class="upcoming-event-card__signup">Signup</a>' : "";

    var clubUrl = baseurl + "/clubs/" + encodeURIComponent(occ.slug) + "/";
    var groupBlock = '<div class="upcoming-event-card__group"><a href="' + clubUrl + '">' + escapeHtml(occ.club_name) + "</a></div>";

    var logoBlock = "";
    if (occ.image) {
      var imgSrc = occ.image.indexOf("://") !== -1 ? occ.image : baseurl + "/assets/images/clubs/" + encodeURIComponent(occ.image);
      logoBlock = '<div class="upcoming-event-card__logo"><img src="' + escapeHtml(imgSrc) + '" alt="" loading="lazy" onload="if(window.GameClub.applyImgBg)window.GameClub.applyImgBg(this)"></div>';
    }

    var distBadge = "";
    if (occ._distance !== undefined) {
      distBadge = '<span class="upcoming-event-card__distance">' + occ._distance.toFixed(1) + " mi</span>";
    }

    var shareCheckbox = "";
    if (shareMode) {
      shareCheckbox =
        '<div class="upcoming-event-card__share-wrap">' +
        '<input type="checkbox" class="upcoming-event-card__share-checkbox share-checkbox" data-slug="' +
        escapeHtml(occ.slug) +
        '" data-start-time="' +
        escapeHtml(occ.start_time) +
        '" aria-label="Select for share">' +
        "</div>";
    }

    return (
      '<li class="upcoming-event-card" data-slug="' +
      escapeHtml(occ.slug) +
      '" data-start-time="' +
      escapeHtml(occ.start_time) +
      '">' +
      shareCheckbox +
      logoBlock +
      groupBlock +
      '<div class="upcoming-event-card__name">' +
      escapeHtml(occ.eventname) +
      "</div>" +
      '<div class="upcoming-event-card__datetime">' +
      escapeHtml(datetimeStr) +
      "</div>" +
      venueBlock +
      '<div class="upcoming-event-card__footer">' +
      '<span class="upcoming-event-card__footer-pills">' +
      '<span class="tag tag-day">' +
      escapeHtml(freq) +
      "</span>" +
      cost +
      distBadge +
      "</span>" +
      signup +
      "</div>" +
      "</li>"
    );
  }

  function getFiltered() {
    var results = allEvents.slice();

    // Day filter
    if (dayFilters.length > 0) {
      results = results.filter(function (occ) {
        var day = dayOfWeek(occ.start_time);
        return dayFilters.indexOf(day) !== -1;
      });
    }

    // Compute distances if location set
    if (userLat !== null && userLng !== null) {
      results.forEach(function (occ) {
        var loc = occ.location;
        if (loc && loc.lat != null && loc.lng != null) {
          occ._distance = haversine(userLat, userLng, loc.lat, loc.lng);
        }
      });

      // Distance filter
      if (maxDistance > 0) {
        results = results.filter(function (occ) {
          return occ._distance !== undefined && occ._distance <= maxDistance;
        });
      }

      // Sort by distance
      results.sort(function (a, b) {
        var da = a._distance !== undefined ? a._distance : Infinity;
        var db = b._distance !== undefined ? b._distance : Infinity;
        if (da !== db) return da - db;
        return (a.start_time || "").localeCompare(b.start_time || "");
      });
    } else {
      results.sort(function (a, b) {
        return (a.start_time || "").localeCompare(b.start_time || "");
      });
    }

    return results;
  }

  function groupByDate(events) {
    var groups = {};
    events.forEach(function (occ) {
      var key = dateKey(occ.start_time);
      if (!groups[key]) groups[key] = [];
      groups[key].push(occ);
    });
    var keys = Object.keys(groups).sort();
    return keys.map(function (k) {
      return { dateKey: k, dateLabel: formatDate(groups[k][0].start_time), items: groups[k] };
    });
  }

  function render(events) {
    var container = document.getElementById("events-list-container");
    if (!container) return;

    if (events.length === 0) {
      container.innerHTML =
        '<p class="upcoming-events-empty">No events match your filters. Try different days or a larger distance.</p>';
      return;
    }

    var grouped = groupByDate(events);
    var html = "";
    grouped.forEach(function (g) {
      html += '<h2>' + escapeHtml(g.dateLabel) + "</h2>";
      html += '<ul class="upcoming-events-list">';
      g.items.forEach(function (occ) {
        html += renderEventCard(occ);
      });
      html += "</ul>";
    });

    container.innerHTML = html;
    if (window.lucide) lucide.createIcons();
  }

  function updateResultCount(shown, total) {
    var el = document.getElementById("events-result-count");
    if (!el) return;

    var text;
    if (shown === total) {
      text = "Showing " + total + " events";
    } else {
      text = "Showing " + shown + " of " + total + " events";
    }

    var locationLabel = window.GameClubLocation && window.GameClubLocation.getActiveLabel ? window.GameClubLocation.getActiveLabel() : null;
    if (locationLabel) {
      text += " · sorted by nearest to " + locationLabel;
    }

    el.textContent = text;
  }

  function updateDayFilterLabel() {
    var label = document.querySelector("#events-day-filter .multi-select-label");
    if (!label) return;
    if (dayFilters.length === 0) {
      label.textContent = "All days";
    } else if (dayFilters.length === 1) {
      label.textContent = dayFilters[0];
    } else {
      label.textContent = dayFilters.length + " days selected";
    }
  }

  function toggleDayFilter(day) {
    var idx = dayFilters.indexOf(day);
    if (idx === -1) {
      dayFilters.push(day);
    } else {
      dayFilters.splice(idx, 1);
    }
  }

  function update() {
    var filtered = getFiltered();
    render(filtered);
    updateResultCount(filtered.length, allEvents.length);
    var page = document.getElementById("events-page");
    if (page) page.classList.toggle("events-page--share-mode", shareMode);
  }

  function getSelectedOccurrences() {
    var checkboxes = document.querySelectorAll(".share-checkbox:checked");
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

  function restoreFromStorage() {
    try {
      var stored = sessionStorage.getItem(STORAGE_KEY);
      if (!stored) return;
      var data = JSON.parse(stored);
      if (!data || typeof data.lat !== "number" || typeof data.lng !== "number") return;

      userLat = data.lat;
      userLng = data.lng;

      var distanceFilter = document.getElementById("events-distance-filter");
      if (distanceFilter) {
        distanceFilter.disabled = false;
        if (data.distance) {
          distanceFilter.value = data.distance;
          maxDistance = parseFloat(data.distance) || 0;
        }
      }

      if (window.GameClubLocation) window.GameClubLocation.setActive("My location");
      setLocateButtonActive(true);
      update();
    } catch (e) {
      sessionStorage.removeItem(STORAGE_KEY);
    }
  }

  function setLocateButtonActive(active) {
    var btn = document.getElementById("locate-btn");
    if (!btn) return;
    if (active) {
      btn.classList.add("is-active");
      btn.setAttribute("aria-pressed", "true");
    } else {
      btn.classList.remove("is-active");
      btn.setAttribute("aria-pressed", "false");
    }
  }

  function bindEvents() {
    var dayFilterEl = document.getElementById("events-day-filter");
    var dayToggle = dayFilterEl ? dayFilterEl.querySelector(".multi-select-toggle") : null;
    var dayCheckboxes = dayFilterEl ? dayFilterEl.querySelectorAll("input[type='checkbox']") : [];
    var distanceFilter = document.getElementById("events-distance-filter");
    var shareBtn = document.getElementById("share-events-btn");

    if (shareBtn) {
      shareBtn.addEventListener("click", function () {
        if (!shareMode) {
          shareMode = true;
          updateShareButtonLabel();
          update();
          return;
        }
        var selected = getSelectedOccurrences();
        if (selected.length === 0) return;
        if (window.ShareEventsModal) window.ShareEventsModal.show(selected);
      });
    }

    var doneBtn = document.getElementById("share-events-done-btn");
    if (doneBtn) {
      doneBtn.addEventListener("click", function () {
        shareMode = false;
        updateShareButtonLabel();
        update();
      });
    }

    if (dayToggle) {
      dayToggle.addEventListener("click", function (e) {
        e.stopPropagation();
        var isOpen = dayFilterEl.classList.toggle("is-open");
        dayToggle.setAttribute("aria-expanded", isOpen ? "true" : "false");
      });
    }

    for (var i = 0; i < dayCheckboxes.length; i++) {
      dayCheckboxes[i].addEventListener("change", function () {
        toggleDayFilter(this.value);
        updateDayFilterLabel();
        update();
      });
    }

    document.addEventListener("click", function (e) {
      if (dayFilterEl && !dayFilterEl.contains(e.target)) {
        dayFilterEl.classList.remove("is-open");
        if (dayToggle) dayToggle.setAttribute("aria-expanded", "false");
      }
    });

    if (distanceFilter) {
      distanceFilter.addEventListener("change", function () {
        maxDistance = this.value ? parseFloat(this.value) : 0;
        if (userLat !== null && userLng !== null) {
          try {
            var stored = sessionStorage.getItem(STORAGE_KEY);
            if (stored) {
              var data = JSON.parse(stored);
              data.distance = distanceFilter.value;
              sessionStorage.setItem(STORAGE_KEY, JSON.stringify(data));
            }
          } catch (e) {}
        }
        update();
      });
    }

    if (window.GameClubLocation) {
      var locateBtn = document.getElementById("locate-btn");
      if (locateBtn) {
        locateBtn.addEventListener(
          "click",
          function (e) {
            if (userLat !== null && userLng !== null) {
              e.preventDefault();
              e.stopImmediatePropagation();
              if (window.GameClubLocation) window.GameClubLocation.clearLocation();
              return;
            }
          },
          true
        );
      }

      window.GameClubLocation.init(
        function (lat, lng, label) {
          userLat = lat;
          userLng = lng;
          if (distanceFilter) distanceFilter.disabled = false;
          setLocateButtonActive(true);
          if (label === "My location") {
            try {
              sessionStorage.setItem(
                STORAGE_KEY,
                JSON.stringify({
                  lat: lat,
                  lng: lng,
                  distance: distanceFilter ? distanceFilter.value : ""
                })
              );
            } catch (e) {}
          }
          update();
        },
        function () {
          userLat = null;
          userLng = null;
          maxDistance = 0;
          setLocateButtonActive(false);
          if (distanceFilter) {
            distanceFilter.value = "";
            distanceFilter.disabled = true;
          }
          try {
            sessionStorage.removeItem(STORAGE_KEY);
          } catch (e) {}
          update();
        }
      );
    }

    restoreFromStorage();
  }

  function init() {
    allEvents = getEventsData();
    if (allEvents.length === 0) return;

    update();
    bindEvents();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
