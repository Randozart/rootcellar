// windowctl — find the sway window (WSLg titles it "wlroots - WL-N (...)")
// and apply a ShowWindow action. Cross-compiled to windows/amd64.
//
// Why: the old cellar buttons spawned powershell.exe + Add-Type per click,
// which costs ~2s of powershell.exe startup alone — buttons felt dead or
// glacial. This is a pure-syscall Go binary (no cgo), so GOOS=windows
// cross-compiles cleanly and each click is a few milliseconds.
//
// It enumerates top-level windows with GetWindow(GW_CHILD)/GW_HWNDNEXT —
// no EnumWindows callback needed — and matches the title substring
// "wlroots" (also survives the "[WARN:COPY MODE]" prefix).
//go:build windows

package main

import (
	"fmt"
	"os"
	"strings"
	"syscall"
	"unsafe"
)

const (
	wsMaximize = 0x01000000

	swMinimize = 6
	swMaximize = 3
	swRestore  = 9
)

// GWL_STYLE is -16, which cannot be a uintptr constant (signed overflow);
// a runtime int variable converts cleanly.
var gwlStyle = -16

var (
	user32             = syscall.NewLazyDLL("user32.dll")
	procGetDesktopWindow = user32.NewProc("GetDesktopWindow")
	procGetWindow        = user32.NewProc("GetWindow")
	procGetWindowTextW   = user32.NewProc("GetWindowTextW")
	procShowWindow       = user32.NewProc("ShowWindow")
	procGetWindowLongPtr = user32.NewProc("GetWindowLongPtrW")
)

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

func main() {
	action := "maximize"
	if len(os.Args) > 1 {
		action = os.Args[1]
	}
	hwnd := findWindow("wlroots")
	if hwnd == 0 {
		fmt.Fprintln(os.Stderr, "windowctl: sway window not found")
		os.Exit(1)
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
	default:
		fmt.Fprintf(os.Stderr, "windowctl: unknown action %q\n", action)
		os.Exit(2)
	}
}