// windowctl — control the sway window WSLg hosts (titled "wlroots - WL-N").
// Cross-compiled to windows/amd64.
//
// Why: the old cellar buttons spawned powershell.exe + Add-Type per click,
// which costs ~2s of powershell.exe startup alone. This is a pure-syscall
// Go binary (no cgo), so GOOS=windows cross-compiles cleanly and each call
// is a few milliseconds.
//
// It finds the window by enumerating top-level windows with
// GetWindow(GW_CHILD)/GW_HWNDNEXT — no callback needed — matching the title
// substring "wlroots" (which survives the "[WARN:COPY MODE]" prefix).
//
// The window has no title bar (WSLg RAIL windows get no Windows caption and
// sway draws no client decorations) and is usually maximized, so it cannot
// be dragged. move-to-monitor / restore are the only way to reposition it.
//go:build windows

package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"syscall"
	"unsafe"
)

const (
	wsMaximize = 0x01000000

	swMinimize = 6
	swMaximize = 3
	swRestore  = 9

	monitorInfoPrimary = 0x1
)

// GWL_STYLE is -16, which cannot be a uintptr constant (signed overflow);
// a runtime int variable converts cleanly.
var gwlStyle = -16

var user32 = syscall.NewLazyDLL("user32.dll")

var (
	procGetDesktopWindow    = user32.NewProc("GetDesktopWindow")
	procGetWindow           = user32.NewProc("GetWindow")
	procGetWindowTextW      = user32.NewProc("GetWindowTextW")
	procShowWindow          = user32.NewProc("ShowWindow")
	procGetWindowLongPtr    = user32.NewProc("GetWindowLongPtrW")
	procEnumDisplayMonitors = user32.NewProc("EnumDisplayMonitors")
	procGetMonitorInfoW     = user32.NewProc("GetMonitorInfoW")
	procGetWindowRect       = user32.NewProc("GetWindowRect")
	procMoveWindow          = user32.NewProc("MoveWindow")
)

type rect struct {
	left, top, right, bottom int32
}

// MONITORINFO: 4 + 16 + 16 + 4 = 40 bytes, naturally aligned.
type monitorInfo struct {
	cbSize    uint32
	rcMonitor rect
	rcWork    rect
	dwFlags   uint32
}

// monitors is filled by monitorEnumProc. Package-level because
// syscall.NewCallback callbacks cannot safely close over Go state.
var monitors []monitorInfo

func monitorEnumProc(hMonitor, hdc, lprc, data uintptr) uintptr {
	var mi monitorInfo
	mi.cbSize = uint32(unsafe.Sizeof(mi))
	procGetMonitorInfoW.Call(hMonitor, uintptr(unsafe.Pointer(&mi)))
	monitors = append(monitors, mi)
	return 1 // continue enumeration
}

func enumMonitors() []monitorInfo {
	monitors = nil
	procEnumDisplayMonitors.Call(0, 0, syscall.NewCallback(monitorEnumProc), 0)
	return monitors
}

func windowText(h uintptr) string {
	buf := make([]uint16, 512)
	procGetWindowTextW.Call(h, uintptr(unsafe.Pointer(&buf[0])), uintptr(len(buf)))
	return syscall.UTF16ToString(buf)
}

func getWindow(h uintptr, cmd uint) uintptr {
	r, _, _ := procGetWindow.Call(h, uintptr(cmd))
	return r
}

func findWindow(substr string) uintptr {
	const (
		gwChild    = 5
		gwHwndNext = 2
	)
	desktop, _, _ := procGetDesktopWindow.Call()
	for h := getWindow(desktop, gwChild); h != 0; h = getWindow(h, gwHwndNext) {
		if strings.Contains(windowText(h), substr) {
			return h
		}
	}
	return 0
}

// windowRect returns the window rectangle via GetWindowRect.
func windowRect(hwnd uintptr) (rect, bool) {
	var r rect
	ret, _, _ := procGetWindowRect.Call(hwnd, uintptr(unsafe.Pointer(&r)))
	return r, ret != 0
}

// currentMonitor returns the index of the monitor whose work area
// contains the center of the given window, or -1 if none.
func currentMonitor(hwnd uintptr) int {
	r, ok := windowRect(hwnd)
	if !ok {
		return -1
	}
	cx := (r.left + r.right) / 2
	cy := (r.top + r.bottom) / 2
	ms := enumMonitors()
	for i, m := range ms {
		w := m.rcWork
		if cx >= w.left && cx < w.right && cy >= w.top && cy < w.bottom {
			return i
		}
	}
	return -1
}

func main() {
	action := "maximize"
	if len(os.Args) > 1 {
		action = os.Args[1]
	}

	// list-monitors does not need the window.
	if action == "list-monitors" {
		for i, m := range enumMonitors() {
			primary := ""
			if m.dwFlags&monitorInfoPrimary != 0 {
				primary = " primary"
			}
			fmt.Printf("%d %dx%d @%d,%d%s\n", i,
				m.rcWork.right-m.rcWork.left, m.rcWork.bottom-m.rcWork.top,
				m.rcWork.left, m.rcWork.top, primary)
		}
		return
	}

	hwnd := findWindow("wlroots")
	if hwnd == 0 {
		fmt.Fprintln(os.Stderr, "windowctl: sway window not found")
		os.Exit(1)
	}

	// monitor-of prints the index of the monitor containing the window.
	if action == "monitor-of" {
		i := currentMonitor(hwnd)
		if i < 0 {
			fmt.Fprintln(os.Stderr, "windowctl: window not on any monitor")
			os.Exit(2)
		}
		fmt.Println(i)
		return
	}

	switch action {
	case "minimize":
		procShowWindow.Call(hwnd, swMinimize)
	case "maximize":
		style, _, _ := procGetWindowLongPtr.Call(hwnd, uintptr(gwlStyle))
		if style&wsMaximize != 0 {
			procShowWindow.Call(hwnd, swRestore)
		} else {
			procShowWindow.Call(hwnd, swMaximize)
		}
	case "restore":
		procShowWindow.Call(hwnd, swRestore)
	case "move-to-monitor":
		if len(os.Args) < 3 {
			fmt.Fprintln(os.Stderr, "windowctl: move-to-monitor requires an argument (N, next, or prev)")
			os.Exit(2)
		}
		ms := enumMonitors()
		n := 0
		switch os.Args[2] {
		case "next":
			cur := currentMonitor(hwnd)
			if cur < 0 {
				n = 0
			} else {
				n = (cur + 1) % len(ms)
			}
		case "prev":
			cur := currentMonitor(hwnd)
			if cur < 0 {
				n = 0
			} else {
				n = (cur - 1 + len(ms)) % len(ms)
			}
		default:
			var err error
			n, err = strconv.Atoi(os.Args[2])
			if err != nil {
				fmt.Fprintf(os.Stderr, "windowctl: invalid monitor %q (use N, next, or prev)\n", os.Args[2])
				os.Exit(2)
			}
		}
		if n < 0 || n >= len(ms) {
			fmt.Fprintf(os.Stderr, "windowctl: no monitor %d (have %d)\n", n, len(ms))
			os.Exit(2)
		}
		w := ms[n].rcWork
		// Restore first so the move lands as a windowed rect, then
		// maximize on the target monitor.
		procShowWindow.Call(hwnd, swRestore)
		procMoveWindow.Call(hwnd, uintptr(w.left), uintptr(w.top),
			uintptr(w.right-w.left), uintptr(w.bottom-w.top), 1)
		procShowWindow.Call(hwnd, swMaximize)
	default:
		fmt.Fprintf(os.Stderr, "windowctl: unknown action %q\n", action)
		os.Exit(2)
	}
}