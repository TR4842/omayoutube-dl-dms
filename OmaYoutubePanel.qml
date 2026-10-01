import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PopoutComponent {
    id: root

    property var controller: null

    headerText: "Oma YouTube DL"
    detailsText: "Search, preview, and download media with yt-dlp."
    showCloseButton: true

    function syncPopoutState() {
        if (!root.controller || !root.parentPopout)
            return;
        root.controller.popoutOpen = root.parentPopout.shouldBeVisible === true;
    }

    onParentPopoutChanged: root.syncPopoutState()
    Component.onCompleted: {
        if (root.controller)
            root.controller.popoutOpen = true;
        Qt.callLater(root.syncPopoutState);
    }

    Connections {
        target: root.parentPopout
        ignoreUnknownSignals: true
        function onShouldBeVisibleChanged() {
            root.syncPopoutState();
        }
    }

    Column {
        id: panelBody
        width: parent.width
        spacing: Theme.spacingS
        implicitHeight: tabRow.implicitHeight + statusText.implicitHeight + pageScroller.height + spacing * 2

        Row {
            id: tabRow
            width: parent.width
            spacing: Theme.spacingS

            DankButton {
                width: (parent.width - parent.spacing) / 2
                text: "Search"
                iconName: "search"
                buttonHeight: 44
                backgroundColor: root.controller.activeTab === "search" ? Theme.primary : Theme.surfaceContainerHigh
                textColor: root.controller.activeTab === "search" ? Theme.onPrimary : Theme.surfaceText
                onClicked: root.controller.activeTab = "search"
            }

            DankButton {
                width: (parent.width - parent.spacing) / 2
                text: "Downloads" + (root.controller.downloading
                        ? " · " + Math.round(root.controller.activePct) + "%"
                        : (root.controller.queuedCount > 0 ? " · " + root.controller.queuedCount : ""))
                iconName: "download"
                buttonHeight: 44
                backgroundColor: root.controller.activeTab === "downloads" ? Theme.primary : Theme.surfaceContainerHigh
                textColor: root.controller.activeTab === "downloads" ? Theme.onPrimary : Theme.surfaceText
                onClicked: root.controller.activeTab = "downloads"
            }
        }

        StyledText {
            id: statusText
            width: parent.width
            text: root.controller.statusLine
            color: root.controller.statusIsError ? Theme.error : Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }

        ScrollView {
            id: pageScroller
            width: parent.width
            height: 540
            clip: true
            contentWidth: width

            Column {
                width: pageScroller.width
                spacing: Theme.spacingM

                Column {
                    id: searchPage
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.controller.activeTab === "search"
                    height: visible ? implicitHeight : 0

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        DankTextField {
                            id: searchInput
                            width: parent.width - searchButton.width - parent.spacing
                            placeholderText: "Search YouTube…"
                            text: root.controller.searchQuery
                            onTextEdited: root.controller.searchQuery = text
                            onAccepted: root.controller.startSearch()
                        }

                        DankButton {
                            id: searchButton
                            width: 112
                            text: root.controller.searching ? "Searching…" : "Search"
                            iconName: root.controller.searching ? "hourglass_top" : "search"
                            enabled: !root.controller.searching && !root.controller.searchStopping
                            buttonHeight: 44
                            backgroundColor: Theme.primary
                            textColor: Theme.onPrimary
                            onClicked: root.controller.startSearch()
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            width: 44
                            text: "Sort"
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        DankDropdown {
                            width: parent.width - 44 - parent.spacing
                            compactMode: true
                            options: ["Relevance", "Newest", "Most viewed", "Short (<4 min)", "Long (>20 min)"]
                            currentValue: root.controller.sortLabel(root.controller.searchSort)
                            onValueChanged: value => root.controller.setSort(value)
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingXS

                        StyledText {
                            text: "Download as"
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        DankButton {
                            text: "Video"
                            iconName: "videocam"
                            buttonHeight: 34
                            backgroundColor: root.controller.downloadMode === "video" ? Theme.primary : Theme.surfaceContainerHigh
                            textColor: root.controller.downloadMode === "video" ? Theme.onPrimary : Theme.surfaceText
                            onClicked: root.controller.saveSetting("dlMode", "video")
                        }

                        DankButton {
                            text: "Audio"
                            iconName: "headphones"
                            buttonHeight: 34
                            backgroundColor: root.controller.downloadMode === "audio" ? Theme.primary : Theme.surfaceContainerHigh
                            textColor: root.controller.downloadMode === "audio" ? Theme.onPrimary : Theme.surfaceText
                            onClicked: root.controller.saveSetting("dlMode", "audio")
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        DankTextField {
                            id: urlInput
                            width: parent.width - queueUrlButton.width - parent.spacing
                            placeholderText: "Paste a video or playlist URL…"
                            text: root.controller.urlDraft
                            onTextEdited: root.controller.urlDraft = text
                            onAccepted: root.controller.queueDirectUrl(root.controller.urlDraft)
                        }

                        DankButton {
                            id: queueUrlButton
                            width: 112
                            text: "Queue URL"
                            iconName: "playlist_add"
                            buttonHeight: 44
                            onClicked: root.controller.queueDirectUrl(root.controller.urlDraft)
                        }
                    }

                    StyledText {
                        width: parent.width
                        visible: root.controller.searchError !== ""
                        height: visible ? implicitHeight : 0
                        text: root.controller.searchError
                        color: Theme.error
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        id: previewCard
                        visible: root.controller.nowTitle !== ""
                        width: parent.width
                        height: previewColumn.implicitHeight + Theme.spacingM * 2
                        implicitHeight: height
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.primary, 0.45)

                        Column {
                            id: previewColumn
                            x: Theme.spacingM
                            y: Theme.spacingM
                            width: parent.width - Theme.spacingM * 2
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                StyledText {
                                    width: parent.width - stopPreviewButton.width - parent.spacing
                                    text: root.controller.nowTitle
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                DankActionButton {
                                    id: stopPreviewButton
                                    iconName: "close"
                                    iconColor: Theme.error
                                    tooltipText: "Stop preview"
                                    onClicked: root.controller.stopPlayback()
                                }
                            }

                            Item {
                                id: videoBox
                                width: parent.width
                                height: root.controller.showVideo ? 176 : 0
                                visible: root.controller.showVideo
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.cornerRadius
                                    color: "#08090b"
                                }

                                Image {
                                    anchors.fill: parent
                                    source: root.controller.nowThumb
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    visible: !root.controller.player || !root.controller.player.hasVideo
                                    opacity: 0.45
                                }

                                Loader {
                                    id: videoOutputLoader
                                    anchors.fill: parent
                                    sourceComponent: root.controller.player
                                            ? root.controller.player.videoOutputComponent : null
                                    visible: root.controller.videoActive && root.controller.player !== null
                                            && root.controller.player.hasVideo
                                    onLoaded: root.controller.attachVideoOutput(item)
                                    onItemChanged: {
                                        if (!item)
                                            root.controller.detachVideoOutput();
                                    }
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    width: parent.width - Theme.spacingM * 2
                                    text: root.controller.mediaPlayerUnavailable
                                            ? (root.controller.audioFallback ? "Qt Multimedia unavailable — using mpv audio preview." : root.controller.playerError)
                                            : (root.controller.resolving ? "Resolving stream…"
                                                : (root.controller.cachingVideo
                                                    ? "Caching video · " + Math.round(root.controller.cachePct) + "%\n" + root.controller.cacheDetail
                                                    : (root.controller.playerError !== "" ? root.controller.playerError
                                                        : (root.controller.audioFallback ? "Audio preview is playing in mpv." : ""))))
                                    color: "white"
                                    font.pixelSize: Theme.fontSizeSmall
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    visible: root.controller.mediaPlayerUnavailable || root.controller.resolving
                                            || root.controller.cachingVideo
                                            || ((!root.controller.player || !root.controller.player.hasVideo)
                                                && (root.controller.playerError !== "" || root.controller.audioFallback))
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingXS

                                DankButton {
                                    text: root.controller.previewPaused ? "Resume" : "Play / pause"
                                    iconName: root.controller.previewPaused ? "play_arrow" : "pause"
                                    buttonHeight: 38
                                    enabled: root.controller.videoActive || root.controller.audioFallback
                                    onClicked: root.controller.togglePlayback()
                                }

                                DankButton {
                                    text: "Open player"
                                    iconName: "open_in_new"
                                    buttonHeight: 38
                                    onClicked: root.controller.openCurrentExternal()
                                }

                                DankButton {
                                    text: "mpv"
                                    iconName: "fullscreen"
                                    buttonHeight: 38
                                    onClicked: root.controller.openCurrentMpv()
                                }

                                DankActionButton {
                                    iconName: "subtitles"
                                    tooltipText: "Create subtitles"
                                    enabled: root.controller.whisperEngine !== "off" && !root.controller.transcribing
                                    onClicked: root.controller.startTranscription(root.controller.nowTitle, root.controller.nowUrl)
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                DankSlider {
                                    id: seekSlider
                                    width: parent.width - seekLabel.implicitWidth - parent.spacing
                                    minimum: 0
                                    maximum: root.controller.player
                                            ? Math.max(1, root.controller.player.duration) : 1
                                    value: root.controller.videoActive && root.controller.player
                                            ? root.controller.player.position : 0
                                    unit: ""
                                    showValue: false
                                    enabled: root.controller.videoActive && root.controller.player !== null
                                            && root.controller.player.duration > 0
                                    onSliderDragFinished: value => root.controller.seek(value)
                                }

                                StyledText {
                                    id: seekLabel
                                    text: root.controller.videoActive && root.controller.player
                                            ? root.controller.formatTime(root.controller.player.position) + " / "
                                                + root.controller.formatTime(root.controller.player.duration)
                                            : (root.controller.audioFallback ? "mpv audio" : "")
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width

                        StyledText {
                            width: parent.width
                            text: root.controller.searching ? "Searching…"
                                    : (root.controller.resultsModel.count > 0
                                        ? "Search results · " + root.controller.resultsModel.count : "Results")
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS

                        Repeater {
                            model: root.controller.resultsModel

                            delegate: Rectangle {
                                required property int index
                                width: parent.width
                                height: 92
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: Theme.outlineVariant

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingS
                                    spacing: Theme.spacingS

                                    Image {
                                        id: resultThumbnail
                                        width: 112
                                        height: 68
                                        source: model.thumb
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        width: parent.width - resultThumbnail.width - resultActions.width - parent.spacing * 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 3

                                        StyledText {
                                            width: parent.width
                                            text: model.title
                                            color: Theme.surfaceText
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            width: parent.width
                                            text: model.channel + " · " + model.duration
                                            color: Theme.surfaceVariantText
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Row {
                                        id: resultActions
                                        spacing: 1
                                        anchors.verticalCenter: parent.verticalCenter

                                        DankActionButton {
                                            iconName: "play_arrow"
                                            tooltipText: "Preview"
                                            onClicked: root.controller.playVideo(model.title, model.url, model.thumb)
                                        }

                                        DankActionButton {
                                            iconName: "download"
                                            tooltipText: "Queue download"
                                            onClicked: root.controller.queueDownload(model.title, model.url)
                                        }

                                        DankActionButton {
                                            iconName: "subtitles"
                                            tooltipText: "Create subtitles"
                                            enabled: root.controller.whisperEngine !== "off" && !root.controller.transcribing
                                            onClicked: root.controller.startTranscription(model.title, model.url)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    id: downloadsPage
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.controller.activeTab === "downloads"
                    height: visible ? implicitHeight : 0

                    Rectangle {
                        visible: root.controller.downloading
                        width: parent.width
                        height: activeDownloadColumn.implicitHeight + Theme.spacingM * 2
                        implicitHeight: height
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.primary, 0.4)

                        Column {
                            id: activeDownloadColumn
                            x: Theme.spacingM
                            y: Theme.spacingM
                            width: parent.width - Theme.spacingM * 2
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                Column {
                                    width: parent.width - cancelDownloadsButton.width - parent.spacing
                                    spacing: 2

                                    StyledText {
                                        width: parent.width
                                        text: "Downloading · " + root.controller.activeTitle
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        width: parent.width
                                        text: Math.round(root.controller.activePct) + "% · " + root.controller.activeDetail
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        elide: Text.ElideRight
                                    }
                                }

                                DankActionButton {
                                    id: cancelDownloadsButton
                                    iconName: "cancel"
                                    iconColor: Theme.error
                                    tooltipText: "Cancel active download and queue"
                                    onClicked: root.controller.cancelDownloads()
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 6
                                radius: 3
                                color: Theme.surfaceContainerHighest

                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(100, root.controller.activePct)) / 100
                                    height: parent.height
                                    radius: parent.radius
                                    color: Theme.primary
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: root.controller.transcribing
                        width: parent.width
                        height: transcriptionColumn.implicitHeight + Theme.spacingM * 2
                        implicitHeight: height
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.primary, 0.4)

                        Column {
                            id: transcriptionColumn
                            x: Theme.spacingM
                            y: Theme.spacingM
                            width: parent.width - Theme.spacingM * 2
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                Column {
                                    width: parent.width - cancelTranscriptionButton.width - parent.spacing
                                    spacing: 2

                                    StyledText {
                                        width: parent.width
                                        text: "Creating subtitles · " + root.controller.transcribeTitle
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        width: parent.width
                                        text: Math.round(root.controller.transcribePct) + "% · " + root.controller.transcribeDetail
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        elide: Text.ElideRight
                                    }
                                }

                                DankActionButton {
                                    id: cancelTranscriptionButton
                                    iconName: "cancel"
                                    iconColor: Theme.error
                                    tooltipText: "Cancel transcription"
                                    onClicked: root.controller.cancelTranscription()
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 6
                                radius: 3
                                color: Theme.surfaceContainerHighest

                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(100, root.controller.transcribePct)) / 100
                                    height: parent.height
                                    radius: parent.radius
                                    color: Theme.primary
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            width: parent.width - folderButton.width - cancelQueueButton.width - parent.spacing * 2
                            text: "Queue · " + root.controller.queueModel.count
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        DankButton {
                            id: folderButton
                            text: "Folder"
                            iconName: "folder_open"
                            buttonHeight: 34
                            onClicked: root.controller.openDownloadFolder()
                        }

                        DankButton {
                            id: cancelQueueButton
                            text: "Cancel all"
                            iconName: "delete_sweep"
                            buttonHeight: 34
                            visible: root.controller.downloading || root.controller.queueModel.count > 0
                            textColor: Theme.error
                            backgroundColor: Theme.withAlpha(Theme.error, 0.12)
                            onClicked: root.controller.cancelDownloads()
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS

                        Repeater {
                            model: root.controller.queueModel

                            delegate: Rectangle {
                                required property int index
                                width: parent.width
                                height: 62
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingS
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: model.mode === "audio" ? "headphones" : "movie"
                                        size: Theme.iconSize
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        width: parent.width - Theme.iconSize - removeQueuedButton.width - parent.spacing * 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        StyledText {
                                            width: parent.width
                                            text: model.title
                                            color: Theme.surfaceText
                                            font.pixelSize: Theme.fontSizeSmall
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            width: parent.width
                                            text: (model.mode === "audio" ? "Audio" : "Video") + " · waiting"
                                            color: Theme.surfaceVariantText
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                        }
                                    }

                                    DankActionButton {
                                        id: removeQueuedButton
                                        iconName: "close"
                                        iconColor: Theme.error
                                        tooltipText: "Remove from queue"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: root.controller.removeQueued(index)
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            width: parent.width - clearHistoryButton.width - parent.spacing
                            text: "Recent activity · " + root.controller.historyModel.count
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        DankButton {
                            id: clearHistoryButton
                            text: "Clear"
                            iconName: "delete_sweep"
                            buttonHeight: 34
                            visible: root.controller.historyModel.count > 0
                            onClicked: root.controller.clearHistory()
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS

                        Repeater {
                            model: root.controller.historyModel

                            delegate: Rectangle {
                                required property int index
                                width: parent.width
                                height: 62
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingS
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: model.kind === "transcription" ? "subtitles"
                                                : (model.kind === "failed" ? "error" : "check_circle")
                                        size: Theme.iconSize
                                        color: model.kind === "failed" ? Theme.error : Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        width: parent.width - Theme.iconSize - historyOpenButton.width - parent.spacing * 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        StyledText {
                                            width: parent.width
                                            text: model.title
                                            color: Theme.surfaceText
                                            font.pixelSize: Theme.fontSizeSmall
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            width: parent.width
                                            text: model.detail
                                            color: Theme.surfaceVariantText
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            elide: Text.ElideRight
                                        }
                                    }

                                    DankActionButton {
                                        id: historyOpenButton
                                        iconName: model.kind === "transcription" ? "open_in_new" : "folder_open"
                                        tooltipText: model.kind === "transcription" ? "Open subtitle output" : "Open download folder"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: {
                                            if (model.kind === "transcription" && model.path)
                                                Quickshell.execDetached(["xdg-open", model.path]);
                                            else if (model.kind === "transcription")
                                                root.controller.openUrl(model.url);
                                            else
                                                root.controller.openDownloadFolder();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: dependencyColumn.implicitHeight + Theme.spacingM * 2
                        implicitHeight: height
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        Column {
                            id: dependencyColumn
                            x: Theme.spacingM
                            y: Theme.spacingM
                            width: parent.width - Theme.spacingM * 2
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width

                                StyledText {
                                    width: parent.width - dependencyButton.width - Theme.spacingS
                                    text: "Optional tools"
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                DankButton {
                                    id: dependencyButton
                                    text: "Check"
                                    iconName: "fact_check"
                                    buttonHeight: 34
                                    onClicked: root.controller.checkDependencies()
                                }
                            }

                            StyledText {
                                width: parent.width
                                text: root.controller.dependencySummary
                                        || "yt-dlp and ffmpeg are required. mpv, socat, curl, and Whisper are optional."
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall - 1
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }
}
