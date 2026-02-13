pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.lock as Lock

Item {
	id: root
	clip: true

	required property ShellScreen screen;
	property real slideAmount: 1.0 - Lock.Controller.bkgSlide
	property alias asynchronous: image.asynchronous;
	property string wallpaperPath: "file:///var/home/neg/.cache/greeter-wallpaper";
	property string fallbackSource: Qt.resolvedUrl((root.screen?.name == "DP-1" ?? false) ? "5120x1728.png" : "1920x1296.png")
	property bool triedFallback: false;

	readonly property real remainingSize: image.height - root.height

	Component.onCompleted: {
		console.warn("[greeter-bg] wallpaperPath:", root.wallpaperPath);
		console.warn("[greeter-bg] fallbackSource:", root.fallbackSource);
		console.warn("[greeter-bg] screen:", root.screen?.name ?? "null");
	}

	Image {
		id: image
		width: root.width
		height: root.width * (image.sourceSize.height / Math.max(image.sourceSize.width, 1))
		source: root.wallpaperPath
		y: -(root.slideAmount * root.remainingSize)

		onStatusChanged: {
			console.warn("[greeter-bg] status:", image.status,
				"(0=Null 1=Ready 2=Loading 3=Error)",
				"source:", image.source,
				"sourceSize:", image.sourceSize.width + "x" + image.sourceSize.height);
			if (image.status === Image.Error && !root.triedFallback) {
				console.warn("[greeter-bg] primary failed, trying fallback:", root.fallbackSource);
				root.triedFallback = true;
				image.source = root.fallbackSource;
			}
			if (image.status === Image.Ready) {
				console.warn("[greeter-bg] loaded OK:", image.source,
					image.sourceSize.width + "x" + image.sourceSize.height);
			}
		}
	}
}
