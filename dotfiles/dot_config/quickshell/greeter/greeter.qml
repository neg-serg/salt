pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Greetd
import "background"
import "lock"

ShellRoot {
	id: root

	readonly property bool testMode: !Quickshell.env("GREETD_SOCK")
	// cage kiosk compositor does not support ext-session-lock-v1;
	// use wlr-layer-shell PanelWindow instead (cage supports it since 0.1.5)
	readonly property bool useSessionLock: !testMode && Quickshell.env("GREETER_MODE") !== "cage"

	GreeterContext {
		id: context
		testMode: root.testMode

		onLaunch: {
			if (root.testMode) {
				Qt.quit();
			} else {
				if (root.useSessionLock) lock.locked = false;
				Greetd.launch(["/etc/greetd/session-wrapper"]);
			}
		}
	}

	// Session lock mode: compositors that support ext-session-lock-v1 (e.g. Hyprland)
	WlSessionLock {
		id: lock
		locked: root.useSessionLock

		WlSessionLockSurface {
			id: lockSurface
			color: "darkgreen"

			BackgroundImage {
				id: backgroundImage
				anchors.fill: parent
				screen: lockSurface.screen
				slideAmount: 0
			}

			LockContent {
				anchors.fill: parent
				state: context.state
			}
		}
	}

	// Panel mode: cage kiosk greeter or test preview (wlr-layer-shell)
	PanelWindow {
		id: panelWindow
		visible: !root.useSessionLock
		color: "darkgreen"

		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
		WlrLayershell.namespace: "greeter"

		anchors {
			top: true
			bottom: true
			left: true
			right: true
		}

		BackgroundImage {
			anchors.fill: parent
			screen: panelWindow.screen
			slideAmount: 0
		}

		LockContent {
			anchors.fill: parent
			state: context.state
		}
	}
}
