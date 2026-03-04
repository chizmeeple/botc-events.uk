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

  var GameClubMap = {
    map: null,
    markers: null,
    markerMap: {},
    userMarker: null,
    tileLayer: null,

    init: function () {
      this.map = L.map("map").setView([53.8, -1.58], 9);

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

      this.map.addLayer(this.markers);

      // Re-render Lucide icons inside popups when they open
      this.map.on("popupopen", function () {
        if (window.lucide) lucide.createIcons();
      });

      return this;
    },

    addClubs: function (clubs) {
      var self = this;
      this.markers.clearLayers();
      this.markerMap = {};

      clubs.forEach(function (club) {
        var locations = club.locations || [];
        if (locations.length === 0) return;

        var popupIcon = "";
        if (club.image) {
          var baseurl = window.GameClub ? window.GameClub.baseurl : "";
          var imgSrc = club.image.indexOf("://") !== -1
            ? self.escapeHtml(club.image)
            : baseurl + "/assets/images/clubs/" + encodeURIComponent(club.image);
          popupIcon = '<div class="popup-icon-wrap"><img src="' + imgSrc + '" alt="" onload="window.GameClub.applyImgBg(this)"></div>';
        }

        var locationText = club.based_in || (locations[0] && locations[0].name) || "";
        var venue = locationText
          ? '<div class="popup-venue"><i data-lucide="map-pin"></i>' + self.escapeHtml(locationText) + '</div>'
          : '';

        var pillsHtml = '';
        if (club.event_days && club.event_days.length > 0) {
          pillsHtml = '<div class="popup-pills">' +
            club.event_days.map(function (day) {
              return '<span class="tag tag--muted">' + self.escapeHtml(String(day)) + '</span>';
            }).join('') +
            '</div>';
        }

        var popupContent =
          '<a class="popup-card" href="' + club.url + '">' +
          '<div class="popup-body">' +
          popupIcon +
          '<div class="popup-content">' +
          '<div class="popup-name">' +
          self.escapeHtml(club.name) +
          "</div>" +
          venue +
          pillsHtml +
          "</div>" +
          "</div>" +
          "</a>";

        locations.forEach(function (loc) {
          if (!loc.lat || !loc.lng) return;
          var marker = L.marker([loc.lat, loc.lng]).bindPopup(popupContent);
          self.markers.addLayer(marker);
          self.markerMap[club.slug] = marker;
        });
      });
    },

    focusOn: function (lat, lng, zoom) {
      if (!this.map) return;
      var targetZoom = typeof zoom === "number" ? zoom : Math.max(this.map.getZoom(), 11);
      this.map.setView([lat, lng], targetZoom);
    },

    fitToMarkers: function () {
      if (this.markers.getLayers().length > 0) {
        this.map.fitBounds(this.markers.getBounds(), { padding: [30, 30] });
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
      var bounds = this.markers.getBounds();
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
