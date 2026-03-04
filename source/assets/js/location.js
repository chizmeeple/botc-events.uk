(function () {
  "use strict";

  // Matches partial UK postcodes: "SW1", "LS6 3", "EC2A 1NT", etc.
  var POSTCODE_RE = /^[A-Z]{1,2}\d/i;

  var GameClubLocation = {
    input: null,
    inputMobile: null,
    suggestions: null,
    suggestionsMobile: null,
    pill: null,
    pillLabel: null,
    clearBtn: null,
    locateBtn: null,
    locateBtnHeader: null,
    debounceTimer: null,
    onLocationSet: null,
    onLocationClear: null,
    activeLabel: null,

    init: function (onLocationSet, onLocationClear) {
      this.onLocationSet = onLocationSet;
      this.onLocationClear = onLocationClear;
      this.input = document.getElementById("search-input");
      this.inputMobile = document.getElementById("search-input-mobile");
      this.suggestions = document.getElementById("location-suggestions");
      this.suggestionsMobile = document.getElementById("location-suggestions-mobile");
      this.pill = document.getElementById("location-pill");
      this.pillLabel = document.getElementById("location-pill-label");
      this.clearBtn = document.getElementById("location-clear");
      this.locateBtn = document.getElementById("locate-btn");
      this.locateBtnHeader = document.getElementById("locate-btn-header");

      if (!this.input && !this.inputMobile) return this;

      this.bindEvents();
      return this;
    },

    bindInputEvents: function (input, suggestionsEl) {
      var self = this;
      if (!input || !suggestionsEl) return;

      input.addEventListener("input", function () {
        clearTimeout(self.debounceTimer);
        var query = input.value.trim();

        if (query.length >= 2 && POSTCODE_RE.test(query)) {
          self.debounceTimer = setTimeout(function () {
            self.fetchSuggestionsFor(query, suggestionsEl, input);
          }, 300);
        } else {
          self.hideSuggestionsEl(suggestionsEl);
        }
      });

      input.addEventListener("keydown", function (e) {
        if (e.key === "Escape") {
          self.hideSuggestionsEl(suggestionsEl);
        }
      });

      document.addEventListener("click", function (e) {
        if (
          suggestionsEl &&
          !input.contains(e.target) &&
          !suggestionsEl.contains(e.target)
        ) {
          self.hideSuggestionsEl(suggestionsEl);
        }
      });
    },

    bindEvents: function () {
      var self = this;

      this.bindInputEvents(this.input, this.suggestions);
      this.bindInputEvents(this.inputMobile, this.suggestionsMobile);

      if (this.clearBtn) {
        this.clearBtn.addEventListener("click", function () {
          self.clearLocation();
        });
      }

      if (this.locateBtn) {
        this.locateBtn.addEventListener("click", function () {
          self.geolocate();
        });
      }

      if (this.locateBtnHeader) {
        this.locateBtnHeader.addEventListener("click", function () {
          self.geolocate();
        });
      }
    },

    fetchSuggestionsFor: function (query, suggestionsEl, input) {
      var self = this;

      fetch("https://api.postcodes.io/postcodes/" + encodeURIComponent(query) + "/autocomplete")
        .then(function (res) { return res.json(); })
        .then(function (data) {
          if (data.result && data.result.length > 0) {
            self.showSuggestionsIn(data.result, suggestionsEl, input);
          } else {
            self.hideSuggestionsEl(suggestionsEl);
          }
        })
        .catch(function () {
          self.hideSuggestionsEl(suggestionsEl);
        });
    },

    showSuggestionsIn: function (postcodes, suggestionsEl, input) {
      var self = this;
      suggestionsEl.innerHTML = postcodes
        .map(function (pc) {
          return '<button class="location-suggestion" type="button" data-postcode="' + pc + '">' +
            '<i data-lucide="map-pin" style="width:14px;height:14px;"></i>' +
            pc + '</button>';
        })
        .join("");

      suggestionsEl.classList.add("is-visible");

      if (window.lucide) lucide.createIcons();

      var buttons = suggestionsEl.querySelectorAll(".location-suggestion");
      for (var i = 0; i < buttons.length; i++) {
        buttons[i].addEventListener("click", function () {
          self.selectPostcode(this.getAttribute("data-postcode"));
        });
      }
    },

    hideSuggestionsEl: function (el) {
      if (!el) return;
      el.innerHTML = "";
      el.classList.remove("is-visible");
    },

    hideAllSuggestions: function () {
      this.hideSuggestionsEl(this.suggestions);
      this.hideSuggestionsEl(this.suggestionsMobile);
    },

    selectPostcode: function (postcode) {
      var self = this;
      if (this.input) this.input.value = "";
      if (this.inputMobile) this.inputMobile.value = "";
      this.hideAllSuggestions();

      fetch("https://api.postcodes.io/postcodes/" + encodeURIComponent(postcode))
        .then(function (res) { return res.json(); })
        .then(function (data) {
          if (data.result) {
            self.setActive(postcode);
            if (self.onLocationSet) {
              self.onLocationSet(data.result.latitude, data.result.longitude, postcode);
            }
          }
        })
        .catch(function (err) {
          console.error("Failed to look up postcode:", err);
        });
    },

    setLocateBtnsDisabled: function (disabled) {
      if (this.locateBtn) this.locateBtn.disabled = disabled;
      if (this.locateBtnHeader) this.locateBtnHeader.disabled = disabled;
    },

    geolocate: function () {
      var self = this;

      if (!navigator.geolocation) {
        alert("Geolocation is not supported by your browser.");
        return;
      }

      self.setLocateBtnsDisabled(true);

      navigator.geolocation.getCurrentPosition(
        function (pos) {
          var lat = pos.coords.latitude;
          var lng = pos.coords.longitude;
          self.setActive("My location");
          self.setLocateBtnsDisabled(false);

          if (self.onLocationSet) {
            self.onLocationSet(lat, lng, "My location");
          }
        },
        function () {
          self.setLocateBtnsDisabled(false);
          alert("Unable to retrieve your location.");
        }
      );
    },

    setActive: function (label) {
      this.activeLabel = label;
      if (this.pill) {
        this.pillLabel.textContent = label;
        this.pill.style.display = "";
      }
    },

    clearLocation: function () {
      this.activeLabel = null;
      if (this.pill) {
        this.pill.style.display = "none";
      }
      // Focus whichever input is visible
      var focusTarget = this.input && this.input.offsetParent !== null ? this.input : this.inputMobile;
      if (focusTarget) focusTarget.focus();
      if (this.onLocationClear) {
        this.onLocationClear();
      }
    },

    getActiveLabel: function () {
      return this.activeLabel;
    },
  };

  window.GameClubLocation = GameClubLocation;
})();
