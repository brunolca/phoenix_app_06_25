// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

// Train Map Hook
const TrainMapHook = {
  mounted() {
    console.log("TrainMapHook: mounted");

    // Check if Leaflet is available
    if (typeof L === "undefined") {
      console.warn("Leaflet not loaded yet, waiting...");
      // Wait for Leaflet to load
      const checkLeaflet = () => {
        if (typeof L !== "undefined") {
          console.log("Leaflet is now available, initializing map");
          this.initializeMap();
        } else {
          setTimeout(checkLeaflet, 100);
        }
      };
      setTimeout(checkLeaflet, 100);
      return;
    }

    this.initializeMap();
  },

  initializeMap() {
    console.log("TrainMapHook: initializing map");

    // Find the actual map container (skip the loading div)
    const mapContainer = document.createElement("div");
    mapContainer.id = "leaflet-map";
    mapContainer.style.cssText =
      "width: 100%; height: 100%; position: absolute; top: 0; left: 0; z-index: 1;";

    // Clear loading content and add map container
    this.el.innerHTML = "";
    this.el.appendChild(mapContainer);

    try {
      // Initialize Leaflet map
      this.map = L.map(mapContainer).setView([46.2276, 2.2137], 6);

      // Add OpenStreetMap tiles
      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: "© OpenStreetMap contributors",
      }).addTo(this.map);

      // Store map reference and initialize markers
      this.trainMarkers = new Map();

      // Force map to resize after initialization
      setTimeout(() => {
        this.map.invalidateSize();
      }, 100);

      console.log("TrainMapHook: map initialized successfully");

      // Store reference globally for external updates
      window.trainMapHook = this;

      // Set up observer for stream updates
      this.setupStreamObserver();

      // Load initial train data
      this.loadInitialTrains();
    } catch (error) {
      console.error("Error initializing map:", error);
      this.el.innerHTML =
        '<div class="p-4 text-red-600">Error loading map: ' +
        error.message +
        "</div>";
    }
  },

  setupStreamObserver() {
    // Find the trains stream container
    const trainsContainer = document.getElementById("trains");
    if (!trainsContainer) {
      console.warn("Trains container not found");
      return;
    }

    // Set up MutationObserver to watch for stream changes
    this.observer = new MutationObserver((mutations) => {
      let hasChanges = false;

      mutations.forEach((mutation) => {
        if (mutation.type === "childList") {
          // Handle added nodes (new trains)
          mutation.addedNodes.forEach((node) => {
            if (node.nodeType === Node.ELEMENT_NODE && node.dataset.train) {
              const train = JSON.parse(node.dataset.train);
              this.updateSingleTrain(train);
              hasChanges = true;
            }
          });

          // Handle removed nodes (trains going offline)
          mutation.removedNodes.forEach((node) => {
            if (node.nodeType === Node.ELEMENT_NODE && node.id) {
              const trainId = parseInt(node.id.replace("trains-", ""));
              this.removeTrainMarker(trainId);
              hasChanges = true;
            }
          });
        } else if (
          mutation.type === "attributes" &&
          mutation.attributeName === "data-train"
        ) {
          // Handle updated train data
          const train = JSON.parse(mutation.target.dataset.train);
          this.updateSingleTrain(train);
          hasChanges = true;
        }
      });

      if (hasChanges) {
        console.log("Stream updated, markers updated");
      }
    });

    // Start observing
    this.observer.observe(trainsContainer, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["data-train"],
    });
  },

  loadInitialTrains() {
    // Load trains from the stream container
    const trainsContainer = document.getElementById("trains");
    if (trainsContainer) {
      const trainElements = trainsContainer.querySelectorAll("[data-train]");
      const trains = Array.from(trainElements).map((el) =>
        JSON.parse(el.dataset.train)
      );
      console.log("Loading initial trains from stream:", trains.length);
      this.updateTrains(trains);
    }
  },

  removeTrainMarker(trainId) {
    const marker = this.trainMarkers.get(trainId);
    if (marker && this.map) {
      this.map.removeLayer(marker);
      this.trainMarkers.delete(trainId);
      console.log("Removed train marker:", trainId);
    }
  },

  destroyed() {
    // Clean up observer when hook is destroyed
    if (this.observer) {
      this.observer.disconnect();
    }
  },

  updateSingleTrain(train) {
    console.log("Updating single train:", train.train_number);
    if (this.map) {
      this.updateTrains([train], true); // true flag for single update
    }
  },

  updateTrains(trains, isSingleUpdate = false) {
    if (!this.map) return;

    console.log(
      "Updating trains:",
      trains.length,
      "Single update:",
      isSingleUpdate
    );

    if (isSingleUpdate) {
      // For single train updates, just update that specific train
      trains.forEach((train) => {
        if (train.latitude && train.longitude) {
          const existingMarker = this.trainMarkers.get(train.id);

          if (existingMarker) {
            // Update existing marker
            const newLatLng = [train.latitude, train.longitude];
            existingMarker.setLatLng(newLatLng);
            const popupContent = this.createPopupContent(train);
            existingMarker.setPopupContent(popupContent);
          } else {
            // Create new marker
            this.createTrainMarker(train);
          }
        }
      });
    } else {
      // For full updates, manage all trains
      const currentTrainIds = new Set(Array.from(this.trainMarkers.keys()));
      const newTrainIds = new Set(trains.map((t) => t.id));

      // Remove trains that are no longer present
      currentTrainIds.forEach((trainId) => {
        if (!newTrainIds.has(trainId)) {
          const marker = this.trainMarkers.get(trainId);
          if (marker) {
            this.map.removeLayer(marker);
            this.trainMarkers.delete(trainId);
          }
        }
      });

      // Add or update trains
      trains.forEach((train) => {
        if (train.latitude && train.longitude) {
          const existingMarker = this.trainMarkers.get(train.id);

          if (existingMarker) {
            // Update existing marker position smoothly
            const newLatLng = [train.latitude, train.longitude];
            const currentLatLng = existingMarker.getLatLng();

            // Only move if position changed significantly (avoid jitter)
            if (
              Math.abs(currentLatLng.lat - newLatLng[0]) > 0.0001 ||
              Math.abs(currentLatLng.lng - newLatLng[1]) > 0.0001
            ) {
              existingMarker.setLatLng(newLatLng);
            }

            // Update popup content
            const popupContent = this.createPopupContent(train);
            existingMarker.setPopupContent(popupContent);
          } else {
            // Create new marker
            this.createTrainMarker(train);
          }
        }
      });
    }
  },

  createTrainMarker(train) {
    const color = this.getTrainColor(train.train_number);

    // Create custom icon
    const trainIcon = L.divIcon({
      className: "train-marker",
      html: `
        <div style="
          background-color: ${color};
          width: 12px;
          height: 12px;
          border-radius: 50%;
          border: 2px solid white;
          box-shadow: 0 0 4px rgba(0,0,0,0.3);
          position: relative;
        ">
          ${
            train.bearing
              ? `<div style="
            position: absolute;
            top: -6px;
            left: 50%;
            transform: translateX(-50%) rotate(${train.bearing}deg);
            width: 0;
            height: 0;
            border-left: 3px solid transparent;
            border-right: 3px solid transparent;
            border-bottom: 6px solid ${color};
          "></div>`
              : ""
          }
        </div>
      `,
      iconSize: [12, 12],
      iconAnchor: [6, 6],
    });

    const marker = L.marker([train.latitude, train.longitude], {
      icon: trainIcon,
    }).addTo(this.map);

    // Add popup
    const popupContent = this.createPopupContent(train);
    marker.bindPopup(popupContent);

    // Store marker reference
    this.trainMarkers.set(train.id, marker);
  },

  createPopupContent(train) {
    return `
      <div class="train-popup">
        <h3 style="margin: 0 0 8px 0; font-weight: bold;">${
          train.train_number
        }</h3>
        <div style="font-size: 12px; line-height: 1.4;">
          <div><strong>Operator:</strong> ${train.operator}</div>
          ${
            train.route_short_name
              ? `<div><strong>Route:</strong> ${train.route_short_name}</div>`
              : ""
          }
          ${
            train.speed_kmh
              ? `<div><strong>Speed:</strong> ${Math.round(
                  train.speed_kmh
                )} km/h</div>`
              : ""
          }
          <div><strong>Status:</strong> ${this.formatDelay(
            train.delay_seconds
          )}</div>
        </div>
      </div>
    `;
  },

  getTrainColor(trainNumber) {
    if (trainNumber.startsWith("TGV")) return "#e74c3c";
    if (trainNumber.startsWith("TER")) return "#3498db";
    if (trainNumber.startsWith("IC")) return "#f39c12";
    return "#95a5a6";
  },

  formatDelay(seconds) {
    if (!seconds || seconds === 0) return "On time";
    if (seconds > 0) return `+${Math.floor(seconds / 60)}min`;
    return `${Math.floor(seconds / 60)}min`;
  },
};

// Handle real-time updates via hook methods
const TrainMapUpdater = {
  updateSingleTrain(train) {
    const mapHook = window.trainMapHook;
    if (mapHook && mapHook.updateSingleTrain) {
      mapHook.updateSingleTrain(train);
    }
  },

  refreshAllTrains(trains) {
    const mapHook = window.trainMapHook;
    if (mapHook && mapHook.updateTrains) {
      mapHook.updateTrains(trains);
    }
  },
};

window.addEventListener("phx:update-train", (event) => {
  TrainMapUpdater.updateSingleTrain(event.detail.train);
});

window.addEventListener("phx:refresh-all-trains", (event) => {
  TrainMapUpdater.refreshAllTrains(event.detail.trains);
});

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { TrainMap: TrainMapHook },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener(
    "phx:live_reload:attached",
    ({ detail: reloader }) => {
      // Enable server log streaming to client.
      // Disable with reloader.disableServerLogs()
      reloader.enableServerLogs();

      // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
      //
      //   * click with "c" key pressed to open at caller location
      //   * click with "d" key pressed to open at function component definition location
      let keyDown;
      window.addEventListener("keydown", (e) => (keyDown = e.key));
      window.addEventListener("keyup", (e) => (keyDown = null));
      window.addEventListener(
        "click",
        (e) => {
          if (keyDown === "c") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtCaller(e.target);
          } else if (keyDown === "d") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtDef(e.target);
          }
        },
        true
      );

      window.liveReloader = reloader;
    }
  );
}
