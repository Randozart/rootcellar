import { WaymoteSession } from "/waymote.js";

// Bare-bones RootCellar client: the stream IS the page. No chrome, no
// stats, no buttons. manual remoteDisplay policy means we never send
// resize requests — the output stays exactly what the sway config pins.
const display = document.querySelector("#display");
const ime = document.querySelector("#ime");
const link = document.querySelector("#link");

const session = new WaymoteSession({
  remoteDisplay: { mode: "manual" },
});

const surface = session.attachSurface({
  canvas: display,
  inputElement: display,
  textInputElement: ime,
  controlOnFocus: true,
  clipboardAutoSync: true,
});

session.on("state", (state) => {
  const up = state.video.state === "connected" && state.input.state !== "disconnected";
  link.classList.toggle("link-down", !up);
  link.textContent = state.video.message || "connecting";
  if (up) {
    display.focus();
  }
});

session.on("error", (error) => {
  console.warn("waymote stream error", error);
});

session.connect();
