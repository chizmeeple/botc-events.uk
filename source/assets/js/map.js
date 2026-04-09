(function () {
  "use strict";

  var LIGHT_OPTIONS = {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/">CARTO</a>',
    maxZoom: 19,
    subdomains: "abcd",
  };
  var DARK_OPTIONS = {
    attribution: '&copy; <a href="https://stadiamaps.com/" target="_blank">Stadia Maps</a> &copy; <a href="https://openmaptiles.org/" target="_blank">OpenMapTiles</a> &copy; <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a>',
    maxZoom: 20,
  };
  var TILE = {
    light: { url: "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png", options: LIGHT_OPTIONS },
    dark: { url: "https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png", options: DARK_OPTIONS },
  };

  var SPECIAL_MARKER_ICON = L.divIcon({
    className: "leaflet-div-icon map-marker map-marker--special",
    html: '<span class="map-marker__special-inner" aria-hidden="true">★</span>',
    iconSize: [26, 26],
    iconAnchor: [13, 26],
    popupAnchor: [1, -22],
  });

  /** Same image as Leaflet default pin (see L.Icon.Default.mergeOptions in init). */
  var LEAFLET_MARKER_ICON_URL = "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png";

  function specialMarkerIconForCount(count) {
    if (count <= 1) return SPECIAL_MARKER_ICON;
    return L.divIcon({
      className: "leaflet-div-icon map-marker map-marker--special map-marker--special-multi",
      html:
        '<span class="map-marker__special-inner" aria-hidden="true">★</span>' +
        '<span class="map-marker__count-badge" aria-hidden="true">' +
        String(count) +
        "</span>",
      iconSize: [26, 26],
      iconAnchor: [13, 26],
      popupAnchor: [1, -22],
    });
  }

  /** Multiple regular clubs at the same coordinates — default pin + count badge. */
  function clubMarkerIconForCount(count) {
    if (count <= 1) return null;
    return L.divIcon({
      className: "leaflet-div-icon map-marker map-marker--club-multi",
      html:
        '<img class="map-marker__pin" src="' + LEAFLET_MARKER_ICON_URL + '" alt="" width="20" height="33" />' +
        '<span class="map-marker__count-badge" aria-hidden="true">' +
        String(count) +
        "</span>",
      iconSize: [20, 33],
      iconAnchor: [10, 33],
      popupAnchor: [1, -30],
    });
  }

  /** Blue bullseye — distinct from orange ★ special-event markers. */
  var USER_LOCATION_ICON = L.divIcon({
    className: "leaflet-div-icon map-marker map-marker--user-location",
    html: '<span class="map-marker__user-inner" aria-hidden="true"></span>',
    iconSize: [28, 28],
    iconAnchor: [14, 14],
    popupAnchor: [0, -12],
  });

  function coordKey(lat, lng) {
    return lat.toFixed(6) + "," + lng.toFixed(6);
  }

  function isMobileViewport() {
    // Keep this aligned with the CSS breakpoint for the home drawer/sidebar.
    return window.matchMedia && window.matchMedia("(max-width: 991px)").matches;
  }

  function mobileDrawerOverlapPx() {
    if (!isMobileViewport()) return 0;
    var sidebar = document.getElementById("sidebar");
    if (!sidebar) return 0;
    var rect = sidebar.getBoundingClientRect();
    if (!rect || typeof rect.top !== "number") return 0;
    // Sidebar is fixed to bottom; the portion visible is how much covers the map.
    var visible = window.innerHeight - rect.top;
    if (!isFinite(visible)) return 0;
    return Math.max(0, Math.round(visible));
  }

  function fitBoundsOptions() {
    var base = 30;
    return { padding: [base, base] };
  }

  function panUpForMobileDrawer(map) {
    if (!map) return;
    var extraBottom = mobileDrawerOverlapPx();
    if (!extraBottom) return;
    // Move the map down so the "interesting area" appears higher,
    // avoiding the mobile drawer without forcing a zoom-out.
    map.panBy([0, Math.round(extraBottom / 2)], { animate: false });
  }

  var GameClubMap = {
    map: null,
    markers: null,
    /** Club markers only; special events are kept separate so they are never clustered. */
    specialMarkers: null,
    markerMap: {},
    userMarker: null,
    tileLayer: null,

    init: function () {
      this.map = L.map("map").setView([53.8, -1.58], 9);

      // Slightly shrink the default Leaflet pin icon
      L.Icon.Default.mergeOptions({
        iconSize: [20, 33],
        iconAnchor: [10, 33],
        popupAnchor: [1, -30],
      });

      var theme = document.documentElement.getAttribute("data-theme") || "dark";
      var tile = TILE[theme] || TILE.dark;
      this.tileLayer = L.tileLayer(tile.url, tile.options).addTo(this.map);

      document.addEventListener("themechange", function (e) {
        var t = (e.detail && e.detail.theme) || document.documentElement.getAttribute("data-theme") || "dark";
        if (!GameClubMap.map || !GameClubMap.tileLayer) return;
        var next = TILE[t] || TILE.dark;
        GameClubMap.map.removeLayer(GameClubMap.tileLayer);
        GameClubMap.tileLayer = L.tileLayer(next.url, next.options).addTo(GameClubMap.map);
      });

      this.markers = L.markerClusterGroup({
        maxClusterRadius: 40,
        spiderfyOnMaxZoom: true,
        showCoverageOnHover: false,
      });

      this.specialMarkers = L.layerGroup();

      this.map.addLayer(this.markers);
      this.map.addLayer(this.specialMarkers);

      // Re-render Iconify icons inside popups when they open
      this.map.on("popupopen", function () {
        if (window.Iconify && Iconify.scan) Iconify.scan();
      });

      return this;
    },

    addClubs: function (clubs) {
      var self = this;
      this.markers.clearLayers();
      this.specialMarkers.clearLayers();
      this.markerMap = {};

      function buildClubPopupHtml(club) {
        var locations = club.locations || [];
        var popupIcon = "";
        if (club.image) {
          var baseurl = window.GameClub ? window.GameClub.baseurl : "";
          var imgDir = club.kind === "special" ? "special" : "clubs";
          var imgSrc = club.image.indexOf("://") !== -1
            ? self.escapeHtml(club.image)
            : baseurl + "/assets/images/" + imgDir + "/" + encodeURIComponent(club.image);
          popupIcon = '<div class="popup-icon-wrap"><img src="' + imgSrc + '" alt="" onload="window.GameClub.applyImgBg(this)"></div>';
        }

        var kindLabel = club.kind === "special"
          ? '<div class="popup-kind">Special event</div>'
          : "";

        var locationText = club.based_in || (locations[0] && locations[0].name) || "";
        var venue = locationText
          ? '<div class="popup-venue"><span class="iconify" data-icon="lucide:map-pin" aria-hidden="true"></span>' + self.escapeHtml(locationText) + '</div>'
          : '';

        var pillsHtml = '';
        if (club.event_days && club.event_days.length > 0) {
          pillsHtml = '<div class="popup-pills">' +
            club.event_days.map(function (day) {
              return '<span class="tag tag--muted">' + self.escapeHtml(String(day)) + '</span>';
            }).join('') +
            '</div>';
        }

        var popupCardClass = "popup-card" + (club.kind === "special" ? " popup-card--special" : "");
        return (
          '<a class="' + popupCardClass + '" href="' + club.url + '">' +
          '<div class="popup-body">' +
          popupIcon +
          '<div class="popup-content">' +
          kindLabel +
          '<div class="popup-name">' +
          self.escapeHtml(club.name) +
          "</div>" +
          venue +
          pillsHtml +
          "</div>" +
          "</div>" +
          "</a>"
        );
      }

      var specialsByCoord = {};
      var clubsByCoord = {};

      clubs.forEach(function (club) {
        var locations = club.locations || [];
        if (locations.length === 0) return;

        if (club.kind === "special") {
          locations.forEach(function (loc) {
            if (!loc.lat || !loc.lng) return;
            var key = coordKey(loc.lat, loc.lng);
            if (!specialsByCoord[key]) specialsByCoord[key] = [];
            specialsByCoord[key].push({ club: club, loc: loc });
          });
          return;
        }

        locations.forEach(function (loc) {
          if (!loc.lat || !loc.lng) return;
          var key = coordKey(loc.lat, loc.lng);
          if (!clubsByCoord[key]) clubsByCoord[key] = [];
          clubsByCoord[key].push({ club: club, loc: loc });
        });
      });

      Object.keys(clubsByCoord).forEach(function (key) {
        var group = clubsByCoord[key];
        var loc = group[0].loc;
        var count = group.length;
        var icon = clubMarkerIconForCount(count);
        var markerOpts = icon ? { icon: icon } : {};
        var popupContent =
          count === 1
            ? buildClubPopupHtml(group[0].club)
            : '<div class="map-popup-stack">' +
              group
                .map(function (item) {
                  return buildClubPopupHtml(item.club);
                })
                .join("") +
              "</div>";
        var marker = L.marker([loc.lat, loc.lng], markerOpts).bindPopup(popupContent);
        self.markers.addLayer(marker);
        group.forEach(function (item) {
          self.markerMap[item.club.slug] = marker;
        });
      });

      Object.keys(specialsByCoord).forEach(function (key) {
        var group = specialsByCoord[key];
        var loc = group[0].loc;
        var count = group.length;
        var icon = specialMarkerIconForCount(count);
        var popupContent =
          count === 1
            ? buildClubPopupHtml(group[0].club)
            : '<div class="map-popup-stack">' +
              group
                .map(function (item) {
                  return buildClubPopupHtml(item.club);
                })
                .join("") +
              "</div>";
        var marker = L.marker([loc.lat, loc.lng], { icon: icon }).bindPopup(popupContent);
        self.specialMarkers.addLayer(marker);
        group.forEach(function (item) {
          self.markerMap[item.club.slug] = marker;
        });
      });
    },

    focusOn: function (lat, lng, zoom) {
      if (!this.map) return;
      var targetZoom = typeof zoom === "number" ? zoom : Math.max(this.map.getZoom(), 11);
      this.map.setView([lat, lng], targetZoom);
      var extraBottom = mobileDrawerOverlapPx();
      if (extraBottom) {
        // Nudge the target above the mobile drawer.
        this.map.panBy([0, Math.round(extraBottom / 2)], { animate: false });
      }
    },

    /**
     * Bounds for fitting the map. We iterate markers instead of calling
     * MarkerClusterGroup#getBounds(), which can report an incorrect extent
     * (cluster internals) when regular and special markers live in separate layers.
     */
    _allMarkerBounds: function () {
      var bounds = L.latLngBounds();
      this.markers.eachLayer(function (layer) {
        if (layer.getLatLng) bounds.extend(layer.getLatLng());
      });
      this.specialMarkers.eachLayer(function (layer) {
        if (layer.getLatLng) bounds.extend(layer.getLatLng());
      });
      return bounds;
    },

    fitToMarkers: function () {
      var b = this._allMarkerBounds();
      if (b.isValid()) {
        this.map.fitBounds(b, fitBoundsOptions());
        panUpForMobileDrawer(this.map);
      }
    },

    removeUserLocation: function () {
      if (this.userMarker) {
        this.map.removeLayer(this.userMarker);
        this.userMarker = null;
      }
    },

    showUserLocation: function (lat, lng) {
      if (this.userMarker) {
        this.map.removeLayer(this.userMarker);
      }

      this.userMarker = L.marker([lat, lng], { icon: USER_LOCATION_ICON })
        .addTo(this.map)
        .bindPopup("You are here");

      // Fit bounds to include user and all visible markers
      var bounds = this._allMarkerBounds();
      if (bounds.isValid()) {
        bounds.extend([lat, lng]);
        this.map.fitBounds(bounds, fitBoundsOptions());
        panUpForMobileDrawer(this.map);
      } else {
        this.map.setView([lat, lng], 12);
      }
    },

    escapeHtml: function (text) {
      if (!text) return "";
      var div = document.createElement("div");
      div.appendChild(document.createTextNode(text));
      return div.innerHTML;
    },

    invalidateSize: function () {
      if (this.map) {
        this.map.invalidateSize();
      }
    },
  };

  window.GameClubMap = GameClubMap;
})();
