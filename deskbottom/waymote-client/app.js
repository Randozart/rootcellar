import { WaymoteSession } from "/waymote.js";

// Bare-bones RootCellar client: the stream IS the page. No chrome, no
// stats, no buttons — except the toolbar, which dispatches the
// desktop's own keybinds through the SDK's input pipeline. The SDK
// binds plain DOM listeners without an isTrusted filter, so synthetic
// KeyboardEvents ride the same path as real ones; being synthetic,
// Windows never sees the chords and cannot claim them.
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

// A toolbar chord is the desktop's keybind, dispatched as keydown+keyup
// on the canvas. preventDefault on mousedown keeps the canvas focused —
// losing input control mid-button would strand the keyboard.
function chord(key, code, mods) {
  for (const type of ["keydown", "keyup"]) {
    display.dispatchEvent(
      new KeyboardEvent(type, { key, code, bubbles: true, cancelable: true, ...mods }),
    );
  }
}

for (const [id, spec] of [
  ["btn-menu", { key: "d", code: "KeyD", ctrlKey: true, altKey: true }],
  ["btn-pane", { key: "n", code: "KeyN", altKey: true }],
  ["btn-exit", { key: "k", code: "KeyK", ctrlKey: true, altKey: true, shiftKey: true }],
]) {
  const button = document.querySelector(`#${id}`);
  button.addEventListener("mousedown", (e) => e.preventDefault());
  button.addEventListener("click", () => {
    chord(spec.key, spec.code, spec);
    if (id === "btn-exit") {
      // The chord above runs the cellar's kiosk sweep; window.close()
      // is a belt-and-braces attempt for the browsers that honor it.
      window.close();
    }
  });
}

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
