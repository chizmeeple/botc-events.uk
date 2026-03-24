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

  function specialMarkerIconForCount(count) {
    if (count <= 1) return SPECIAL_MARKER_ICON;
    return L.divIcon({
      className: "leaflet-div-icon map-marker map-marker--special map-marker--special-multi",
      html:
        '<span class="map-marker__special-inner" aria-hidden="true">★</span>' +
        '<span class="map-marker__special-count" aria-hidden="true">' +
        String(count) +
        "</span>",
      iconSize: [26, 26],
      iconAnchor: [13, 26],
      popupAnchor: [1, -22],
    });
  }

  function coordKey(lat, lng) {
    return lat.toFixed(6) + "," + lng.toFixed(6);
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

        var popupContent = buildClubPopupHtml(club);
        locations.forEach(function (loc) {
          if (!loc.lat || !loc.lng) return;
          var marker = L.marker([loc.lat, loc.lng]).bindPopup(popupContent);
          self.markers.addLayer(marker);
          self.markerMap[club.slug] = marker;
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
        this.map.fitBounds(b, { padding: [30, 30] });
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

      this.userMarker = L.circleMarker([lat, lng], {
        radius: 10,
        fillColor: "#c8702a",
        color: "#fff",
        weight: 2,
        opacity: 1,
        fillOpacity: 0.9,
      })
        .addTo(this.map)
        .bindPopup("You are here");

      // Fit bounds to include user and all visible markers
      var bounds = this._allMarkerBounds();
      if (bounds.isValid()) {
        bounds.extend([lat, lng]);
        this.map.fitBounds(bounds, { padding: [30, 30] });
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
