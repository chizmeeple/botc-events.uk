(function () {
  "use strict";

  var baseurl = window.GameClub ? window.GameClub.baseurl : "";
  var map;
  var search;
  var debounceTimer;
  var STORAGE_KEY = "gameclub_user_location";

  function init() {
    map = window.GameClubMap.init();

    fetch(baseurl + "/api/clubs.json")
      .then(function (res) {
        return res.json();
      })
      .then(function (clubs) {
        search = window.GameClubSearch.init(clubs);
        restoreFromUrl();
        update();
        bindEvents();
      })
      .catch(function (err) {
        console.error("Failed to load clubs:", err);
      });
  }

  function restoreFromUrl() {
    var params = readUrlParams();
    var searchInput = document.getElementById("search-input");
    var searchInputMobile = document.getElementById("search-input-mobile");
    var distanceFilter = document.getElementById("distance-filter");

    if (params.q) {
      search.setQuery(params.q);
      if (searchInput) searchInput.value = params.q;
      if (searchInputMobile) searchInputMobile.value = params.q;
    }
    if (params.days && params.days.length > 0) {
      search.setDayFilters(params.days);
      // Check matching checkboxes in multi-select
      var checkboxes = document.querySelectorAll("#day-filter input[type='checkbox']");
      for (var i = 0; i < checkboxes.length; i++) {
        if (params.days.indexOf(checkboxes[i].value) !== -1) {
          checkboxes[i].checked = true;
        }
      }
      updateDayFilterLabel();
    }
    if (params.distance) {
      search.setMaxDistance(params.distance);
      if (distanceFilter) distanceFilter.value = params.distance;
    }
  }

  function restoreFromStorage() {
    try {
      var stored = sessionStorage.getItem(STORAGE_KEY);
      if (!stored) return;
      var data = JSON.parse(stored);
      if (!data || typeof data.lat !== "number" || typeof data.lng !== "number") return;

      var distanceFilter = document.getElementById("distance-filter");
      search.setUserLocation(data.lat, data.lng);
      map.showUserLocation(data.lat, data.lng);
      window.GameClubLocation.setActive("My location");
      if (distanceFilter) {
        distanceFilter.disabled = false;
        if (data.distance) {
          distanceFilter.value = data.distance;
          search.setMaxDistance(data.distance);
        }
      }
      update();
    } catch (e) {
      sessionStorage.removeItem(STORAGE_KEY);
    }
  }

  function readUrlParams() {
    var params = new URLSearchParams(window.location.search);
    var daysStr = params.get("days") || "";
    // Backward compat: support old ?day= single param
    if (!daysStr) {
      var singleDay = params.get("day") || "";
      if (singleDay) daysStr = singleDay;
    }
    var days = daysStr ? daysStr.split(",").filter(function (d) { return d; }) : [];
    return {
      q: params.get("q") || "",
      days: days,
      distance: params.get("distance") || ""
    };
  }

  function writeUrlParams() {
    var searchInput = document.getElementById("search-input");
    var distanceFilter = document.getElementById("distance-filter");

    var params = new URLSearchParams();
    var q = searchInput ? searchInput.value.trim() : "";
    var days = search.dayFilters.join(",");
    var distance = distanceFilter ? distanceFilter.value : "";

    if (q) params.set("q", q);
    if (days) params.set("days", days);
    if (distance) params.set("distance", distance);

    var newUrl = window.location.pathname + (params.toString() ? "?" + params.toString() : "");
    history.replaceState(null, "", newUrl);
  }

  function update() {
    var filtered = search.getFiltered();
    map.addClubs(filtered);

    if (
      filtered.length === 1 &&
      search.userLat === null &&
      search.userLng === null
    ) {
      var club = filtered[0];
      var firstLoc = club.locations && club.locations[0];
      if (firstLoc && firstLoc.lat && firstLoc.lng) {
        map.focusOn(firstLoc.lat, firstLoc.lng);
      } else {
        map.fitToMarkers();
      }
    } else {
      map.fitToMarkers();
    }

    renderCards(filtered);
    updateResultCount(filtered.length, search.allClubs.length);
    writeUrlParams();
  }

  function renderCards(clubs) {
    var container = document.getElementById("club-list");
    if (!container) return;

    if (clubs.length === 0) {
      container.innerHTML =
        '<p style="color:#555;text-align:center;padding:2rem 0;">No groups match your search. Try a different filter or search term.</p>';
      return;
    }

    var html = clubs
      .map(function (club) {
        var distanceBadge = "";
        if (club._distance !== undefined) {
          distanceBadge =
            '<span class="club-distance">' +
            club._distance.toFixed(1) +
            " mi</span>";
        }

        var icon = "";
        if (club.image) {
          var imgSrc = club.image.indexOf("://") !== -1
            ? escapeHtml(club.image)
            : baseurl + "/assets/images/clubs/" + encodeURIComponent(club.image);
          icon = '<div class="club-icon-wrap"><img src="' + imgSrc + '" alt="" loading="lazy" onload="window.GameClub.applyImgBg(this)"></div>';
        }

        var firstLoc = club.locations && club.locations[0];
        var locationText = club.based_in || (firstLoc && firstLoc.name) || "";
        var venue = locationText
          ? '<div class="club-venue"><span class="iconify" data-icon="lucide:map-pin" aria-hidden="true"></span>' + escapeHtml(locationText) + "</div>"
          : "";

        var pillsHtml = "";
        if (club.event_days && club.event_days.length > 0) {
          pillsHtml =
            '<div class="club-pills">' +
            club.event_days
              .map(function (day) {
                return '<span class="tag tag--muted">' + escapeHtml(String(day)) + "</span>";
              })
              .join("") +
            "</div>";
        }

        var meta = venue || pillsHtml
          ? '<div class="club-card-meta">' + venue + pillsHtml + "</div>"
          : "";

        return (
          '<a class="club-card" href="' +
          escapeHtml(club.url) +
          '">' +
          '<div class="club-card-body">' +
          icon +
          '<div class="club-card-content">' +
          '<div class="club-card-header">' +
          '<div class="club-name">' +
          escapeHtml(club.name) +
          "</div>" +
          distanceBadge +
          "</div>" +
          meta +
          "</div>" +
          "</div>" +
          "</a>"
        );
      })
      .join("");

    container.innerHTML = html;
    if (window.Iconify && Iconify.scan) Iconify.scan(container);
  }

  function updateResultCount(shown, total) {
    var el = document.getElementById("result-count");
    if (!el) return;

    var text;
    if (shown === total) {
      text = "Showing " + total + " groups";
    } else {
      text = "Showing " + shown + " of " + total + " groups";
    }

    var locationLabel = window.GameClubLocation && window.GameClubLocation.getActiveLabel
      ? window.GameClubLocation.getActiveLabel()
      : null;

    if (locationLabel) {
      text += " \u00b7 sorted by nearest to " + locationLabel;
    }

    el.textContent = text;
  }

  function updateDayFilterLabel() {
    var label = document.querySelector("#day-filter .multi-select-label");
    if (!label) return;
    var days = search.dayFilters;
    if (days.length === 0) {
      label.textContent = "All days";
    } else if (days.length === 1) {
      label.textContent = days[0];
    } else {
      label.textContent = days.length + " days selected";
    }
  }

  function bindEvents() {
    var searchInput = document.getElementById("search-input");
    var searchInputMobile = document.getElementById("search-input-mobile");
    var dayFilterEl = document.getElementById("day-filter");
    var dayToggle = dayFilterEl ? dayFilterEl.querySelector(".multi-select-toggle") : null;
    var dayCheckboxes = dayFilterEl ? dayFilterEl.querySelectorAll("input[type='checkbox']") : [];
    var distanceFilter = document.getElementById("distance-filter");

    // Sync both search inputs
    function onSearchInput(source, other) {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(function () {
        if (other) other.value = source.value;
        search.setQuery(source.value);
        update();
      }, 200);
    }

    if (searchInput) {
      searchInput.addEventListener("input", function () {
        onSearchInput(searchInput, searchInputMobile);
      });
    }
    if (searchInputMobile) {
      searchInputMobile.addEventListener("input", function () {
        onSearchInput(searchInputMobile, searchInput);
      });
    }

    // Day filter multi-select dropdown
    if (dayToggle) {
      dayToggle.addEventListener("click", function (e) {
        e.stopPropagation();
        var isOpen = dayFilterEl.classList.toggle("is-open");
        dayToggle.setAttribute("aria-expanded", isOpen ? "true" : "false");
      });
    }

    for (var i = 0; i < dayCheckboxes.length; i++) {
      dayCheckboxes[i].addEventListener("change", function () {
        search.toggleDayFilter(this.value);
        updateDayFilterLabel();
        update();
      });
    }

    // Close dropdown when clicking outside
    document.addEventListener("click", function (e) {
      if (dayFilterEl && !dayFilterEl.contains(e.target)) {
        dayFilterEl.classList.remove("is-open");
        if (dayToggle) dayToggle.setAttribute("aria-expanded", "false");
      }
    });

    // Distance filter
    if (distanceFilter) {
      distanceFilter.addEventListener("change", function () {
        search.setMaxDistance(distanceFilter.value);
        if (search.userLat !== null && search.userLng !== null) {
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

    // Location autocomplete + geolocation
    window.GameClubLocation.init(
      function (lat, lng, label) {
        // Clear text search when a location is selected via postcode
        search.setQuery("");
        if (searchInput) searchInput.value = "";
        if (searchInputMobile) searchInputMobile.value = "";
        search.setUserLocation(lat, lng);
        map.showUserLocation(lat, lng);
        // Enable distance filter
        if (distanceFilter) distanceFilter.disabled = false;
        if (label === "My location") {
          try {
            sessionStorage.setItem(STORAGE_KEY, JSON.stringify({
              lat: lat,
              lng: lng,
              distance: distanceFilter ? distanceFilter.value : ""
            }));
          } catch (e) {}
        }
        update();
      },
      function () {
        search.clearUserLocation();
        search.setMaxDistance(0);
        map.removeUserLocation();
        // Reset and disable distance filter
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

    restoreFromStorage();
  }

  function escapeHtml(text) {
    if (!text) return "";
    var div = document.createElement("div");
    div.appendChild(document.createTextNode(text));
    return div.innerHTML;
  }

  // Toggle shadow on filter bar when sidebar is scrolled
  function initSidebarScroll() {
    var sidebar = document.getElementById("sidebar");
    if (!sidebar) return;
    sidebar.addEventListener("scroll", function () {
      sidebar.classList.toggle("sidebar--scrolled", sidebar.scrollTop > 0);
    });
  }

  // Start
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () {
      init();
      initSidebarScroll();
    });
  } else {
    init();
    initSidebarScroll();
  }
})();
