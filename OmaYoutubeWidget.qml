import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Keep pluginId, pluginService, and pluginData host-injected as documented
    // by DMS. The controller receives those values instead of shadowing them.
    layerNamespacePlugin: "oma-youtube-dl"

    OmaYoutubeController {
        id: controller
        pluginId: root.pluginId
        pluginService: root.pluginService
        settingsData: root.pluginData
    }

    function openPluginPopout() {
        if (!controller.popoutOpen)
            root.triggerPopout();
    }

    function closePluginPopout() {
        if (controller.popoutOpen)
            root.closePopout();
    }

    function acceptDrop(drop) {
        const text = drop.hasUrls && drop.urls.length > 0
                ? drop.urls[0].toString()
                : (drop.hasText ? drop.text : "");
        controller.acceptPastedText(text);
        root.openPluginPopout();
    }

    pillRightClickAction: () => {
        controller.pasteAndOpen();
        root.openPluginPopout();
    }

    horizontalBarPill: Component {
        Item {
            id: horizontalPill
            width: pillContent.implicitWidth
            height: pillContent.implicitHeight
            implicitWidth: width
            implicitHeight: height
            property bool draggingOver: false

            Row {
                id: pillContent
                spacing: Theme.spacingXS

                DankIcon {
                    name: controller.downloading ? "downloading"
                            : (controller.previewPlaying ? "play_circle" : "smart_display")
                    size: root.iconSize
                    color: horizontalPill.draggingOver || controller.downloading
                            ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: controller.downloading
                            ? Math.round(controller.activePct) + "%"
                            : (controller.queuedCount > 0 ? "YT " + controller.queuedCount : "YT")
                    color: controller.downloading || controller.queuedCount > 0
                            ? Theme.primary : Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: horizontalPill.draggingOver = true
                onExited: horizontalPill.draggingOver = false
                onDropped: drop => {
                    horizontalPill.draggingOver = false;
                    root.acceptDrop(drop);
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            id: verticalPill
            width: Math.max(pillColumn.implicitWidth, root.iconSize)
            height: pillColumn.implicitHeight
            implicitWidth: width
            implicitHeight: height
            property bool draggingOver: false

            Column {
                id: pillColumn
                spacing: 2
                anchors.horizontalCenter: parent.horizontalCenter

                DankIcon {
                    name: controller.downloading ? "downloading"
                            : (controller.previewPlaying ? "play_circle" : "smart_display")
                    size: root.iconSize
                    color: verticalPill.draggingOver || controller.downloading
                            ? Theme.primary : Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: controller.downloading
                            ? Math.round(controller.activePct) + "%"
                            : (controller.queuedCount > 0 ? String(controller.queuedCount) : "YT")
                    color: controller.downloading || controller.queuedCount > 0
                            ? Theme.primary : Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: verticalPill.draggingOver = true
                onExited: verticalPill.draggingOver = false
                onDropped: drop => {
                    verticalPill.draggingOver = false;
                    root.acceptDrop(drop);
                }
            }
        }
    }

    // Qt Multimedia is deliberately optional and isolated behind a Loader.
    // Missing the QML module must not stop DMS from enabling the plugin.
    Loader {
        id: mediaPlayerLoader
        active: true
        source: Qt.resolvedUrl("./OmaYoutubeMediaPlayer.qml")
        visible: false
        width: 0
        height: 0

        onLoaded: controller.mediaPlayerReady(item)
        onStatusChanged: {
            if (status === Loader.Error)
                controller.mediaPlayerFailed();
        }
    }

    Connections {
        target: controller.player
        ignoreUnknownSignals: true

        function onPlaybackStateUpdated() {
            controller.syncPlaybackState();
        }

        function onMediaError(message) {
            controller.handleMediaError(message);
        }
    }

    IpcHandler {
        target: "omaYoutubeDl"

        function open(): string {
            root.openPluginPopout();
            return "opened";
        }

        function close(): string {
            root.closePluginPopout();
            return "closed";
        }

        function toggle(): string {
            root.triggerPopout();
            return "toggled";
        }

        function search(query: string): string {
            const value = String(query || "").trim();
            if (!value)
                return "ERROR: search query is required";
            controller.activeTab = "search";
            controller.searchQuery = value;
            controller.startSearch();
            root.openPluginPopout();
            return "searching";
        }

        function download(url: string): string {
            const value = String(url || "").trim();
            if (!controller.isWebUrl(value))
                return "ERROR: expected an http(s) URL";
            controller.queueDownload(value, value);
            root.openPluginPopout();
            return "queued";
        }

        function play(url: string): string {
            const value = String(url || "").trim();
            if (!controller.isWebUrl(value))
                return "ERROR: expected an http(s) URL";
            controller.activeTab = "search";
            controller.playVideo(value, value, "");
            root.openPluginPopout();
            return "playing";
        }

        function transcribe(url: string): string {
            const value = String(url || "").trim();
            if (!controller.isWebUrl(value))
                return "ERROR: expected an http(s) URL";
            controller.startTranscription(value, value);
            root.openPluginPopout();
            return "transcribing";
        }
    }

    popoutWidth: 620
    popoutHeight: 700

    popoutContent: Component {
        OmaYoutubePanel {
            controller: controller
        }
    }

    Component.onDestruction: controller.cleanup()
}
