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

	GreeterContext {
		id: context
		testMode: root.testMode

		onLaunch: {
			if (root.testMode) {
				Qt.quit();
			} else {
				lock.locked = false;
				Greetd.launch(["/etc/greetd/session-wrapper"]);
			}
		}
	}

	// Real greeter: session lock (only active when greetd is running)
	WlSessionLock {
		id: lock
		locked: !root.testMode

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

	// Test mode: overlay window for previewing the greeter UI
	PanelWindow {
		id: testWindow
		visible: root.testMode
		color: "darkgreen"

		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
		WlrLayershell.namespace: "greeter:test"

		anchors {
			top: true
			bottom: true
			left: true
			right: true
		}

		BackgroundImage {
			anchors.fill: parent
			screen: testWindow.screen
			slideAmount: 0
		}

		LockContent {
			anchors.fill: parent
			state: context.state
		}
	}
}
