(function () {
  "use strict";

  var GameClubSearch = {
    allClubs: [],
    searchQuery: "",
    dayFilters: [],
    maxDistance: 0,
    userLat: null,
    userLng: null,

    init: function (clubs) {
      this.allClubs = clubs;
      return this;
    },

    setQuery: function (query) {
      this.searchQuery = query.toLowerCase().trim();
    },

    setDayFilters: function (days) {
      this.dayFilters = days || [];
    },

    toggleDayFilter: function (day) {
      var idx = this.dayFilters.indexOf(day);
      if (idx === -1) {
        this.dayFilters.push(day);
      } else {
        this.dayFilters.splice(idx, 1);
      }
    },

    setMaxDistance: function (miles) {
      this.maxDistance = miles ? parseFloat(miles) : 0;
    },

    setUserLocation: function (lat, lng) {
      this.userLat = lat;
      this.userLng = lng;
    },

    clearUserLocation: function () {
      this.userLat = null;
      this.userLng = null;
      this.allClubs.forEach(function (club) {
        delete club._distance;
      });
    },

    getFiltered: function () {
      var self = this;

      // Compute distances first if location is set (use nearest of club's locations)
      if (self.userLat !== null && self.userLng !== null) {
        self.allClubs.forEach(function (club) {
          var locs = club.locations || [];
          if (locs.length === 0) return;
          var minDist = Infinity;
          for (var i = 0; i < locs.length; i++) {
            var d = self.haversine(
              self.userLat,
              self.userLng,
              locs[i].lat,
              locs[i].lng
            );
            if (d < minDist) minDist = d;
          }
          club._distance = minDist;
        });
      }

      var results = this.allClubs.filter(function (club) {
        // Text search
        if (self.searchQuery) {
          var locNames = (club.locations || []).map(function (l) { return l.name || ""; }).join(" ");
          var haystack = [
            club.name,
            locNames,
            club.description,
          ]
            .filter(Boolean)
            .join(" ")
            .toLowerCase();
          if (haystack.indexOf(self.searchQuery) === -1) return false;
        }

        // Day filter (OR logic: club passes if it matches any selected day)
        // Clubs without days data pass through when filter is active
        if (self.dayFilters.length > 0 && club.days && club.days.length > 0) {
          var matchesDay = false;
          for (var i = 0; i < self.dayFilters.length; i++) {
            if (club.days.indexOf(self.dayFilters[i]) !== -1) {
              matchesDay = true;
              break;
            }
          }
          if (!matchesDay) return false;
        }

        // Distance filter (only when location is set)
        if (self.maxDistance > 0 && club._distance !== undefined) {
          if (club._distance > self.maxDistance) return false;
        }

        return true;
      });

      // Sort by distance if user location is known
      if (self.userLat !== null && self.userLng !== null) {
        results.sort(function (a, b) {
          return a._distance - b._distance;
        });
      }

      return results;
    },

    haversine: function (lat1, lng1, lat2, lng2) {
      var R = 3959; // miles
      var dLat = this.toRad(lat2 - lat1);
      var dLng = this.toRad(lng2 - lng1);
      var a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(this.toRad(lat1)) *
          Math.cos(this.toRad(lat2)) *
          Math.sin(dLng / 2) *
          Math.sin(dLng / 2);
      var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      return R * c;
    },

    toRad: function (deg) {
      return (deg * Math.PI) / 180;
    },
  };

  window.GameClubSearch = GameClubSearch;
})();
