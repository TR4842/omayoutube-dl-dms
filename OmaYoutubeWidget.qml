import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./Model.js" as Model

PluginComponent {
    id: root

    pluginId: "omaYoutubeDl"
    pluginService: PluginService
    layerNamespacePlugin: "oma-youtube-dl"

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string mpvSocket: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/dms-oma-youtube-dl.sock"

    property string activeTab: "search"
    property string searchQuery: ""
    property string urlDraft: ""
    property string statusLine: "Search YouTube or paste a supported media URL."
    property bool statusIsError: false
    property string searchError: ""
    property string dependencySummary: ""
    property bool searching: false
    property string searchAbortReason: ""

    property string nowTitle: ""
    property string nowUrl: ""
    property string nowId: ""
    property string nowThumb: ""
    property bool resolving: false
    property bool cachingVideo: false
    property real cachePct: 0
    property string cacheDetail: ""
    property string cacheFile: ""
    property bool videoActive: false
    property bool audioFallback: false
    property bool previewPlaying: false
    property bool previewPaused: false
    property string playerError: ""
    property var player: null
    property var videoOutputRef: null
    property bool mediaPlayerUnavailable: false
    property string pendingEmbeddedSource: ""
    property string pendingEmbeddedStatus: ""

    property bool downloading: false
    property real activePct: 0
    property string activeTitle: ""
    property string activeUrl: ""
    property string activeMode: "video"
    property string activeDetail: "Idle"

    property bool transcribing: false
    property real transcribePct: 0
    property string transcribeTitle: ""
    property string transcribeUrl: ""
    property string transcribeOutputPath: ""
    property string transcribeDetail: "Idle"

    readonly property int searchMaxBytes: 1048576
    readonly property int searchTimeoutMs: 30000
    readonly property int queuedCount: queueModel.count

    function configuredValue(key, fallback) {
        const value = root.pluginData ? root.pluginData[key] : undefined;
        return value === undefined || value === null || String(value) === "" ? fallback : value;
    }

    readonly property string downloadDir: String(configuredValue("downloadDir", root.homeDir + "/Videos/Omayoutube"))
    readonly property string quality: {
        const value = String(configuredValue("quality", "1080"));
        return ["best", "2160", "1440", "1080", "720", "480", "360"].indexOf(value) >= 0 ? value : "1080";
    }
    readonly property string audioFormat: {
        const value = String(configuredValue("audioFormat", "mp3"));
        return ["mp3", "m4a", "opus", "flac", "wav"].indexOf(value) >= 0 ? value : "mp3";
    }
    readonly property string videoFormat: {
        const value = String(configuredValue("videoFormat", "mp4"));
        return ["mp4", "mkv", "webm", "best"].indexOf(value) >= 0 ? value : "mp4";
    }
    readonly property string downloadMode: String(configuredValue("dlMode", "video")) === "audio" ? "audio" : "video"
    readonly property string playlistMode: String(configuredValue("playlistMode", "single")) === "playlist" ? "playlist" : "single"
    readonly property string maxResults: {
        const value = String(configuredValue("maxResults", "10"));
        return ["5", "10", "15"].indexOf(value) >= 0 ? value : "10";
    }
    readonly property string searchSort: {
        const value = String(configuredValue("searchSort", "relevance"));
        return ["relevance", "date", "views", "short", "long"].indexOf(value) >= 0 ? value : "relevance";
    }
    readonly property string cookiesBrowser: {
        const value = String(configuredValue("cookiesBrowser", "off"));
        return ["off", "chromium", "chrome", "firefox", "brave", "vivaldi", "edge", "opera"].indexOf(value) >= 0 ? value : "off";
    }
    readonly property bool showVideo: root.pluginData && root.pluginData.showVideo !== undefined ? root.pluginData.showVideo === true : true
    readonly property string audioLang: {
        const value = String(configuredValue("audioLang", "original"));
        return ["original", "pt", "original+pt", "pt+en"].indexOf(value) >= 0 ? value : "original";
    }
    readonly property string subLangs: {
        const value = String(configuredValue("subLangs", "off"));
        return ["off", "pt,pt-BR,pt-PT", "pt,pt-BR,pt-PT,en", "all"].indexOf(value) >= 0 ? value : "off";
    }
    readonly property bool embedSubs: root.pluginData && root.pluginData.embedSubs === true
    readonly property string whisperEngine: {
        const value = String(configuredValue("whisperEngine", "local"));
        return ["off", "local", "openai"].indexOf(value) >= 0 ? value : "local";
    }
    readonly property string whisperLang: String(configuredValue("whisperLang", "pt"))
    readonly property string whisperModel: {
        const value = String(configuredValue("whisperModel", "medium"));
        return ["auto", "small", "medium", "large-v3-turbo"].indexOf(value) >= 0 ? value : "medium";
    }
    readonly property string whisperCmd: String(configuredValue("whisperCmd", "auto"))
    readonly property string whisperApiModel: String(configuredValue("whisperApiModel", "whisper-1"))
    readonly property string whisperKeyEnv: String(configuredValue("whisperKeyEnv", "OPENAI_API_KEY"))

    function saveSetting(key, value) {
        const data = Object.assign({}, root.pluginData || {});
        data[key] = value;
        root.pluginData = data;
        if (root.pluginService && root.pluginService.savePluginData)
            root.pluginService.savePluginData(root.pluginId, key, value);
    }

    function setStatus(message, isError) {
        root.statusLine = String(message || "");
        root.statusIsError = isError === true;
        if (isError && typeof ToastService !== "undefined" && ToastService)
            ToastService.showError("Oma YouTube", root.statusLine);
    }

    function isWebUrl(value) {
        const url = String(value || "").trim();
        return url.length > 0 && url.length <= 4096 && /^https?:\/\/\S+$/i.test(url);
    }

    function openPopout() {
        if (!root.interactionActive)
            root.triggerPopout();
    }

    function pasteAndOpen() {
        if (clipboardProc.running)
            clipboardProc.running = false;
        clipboardProc.command = ["sh", "-c", "wl-paste --no-newline 2>/dev/null || xclip -selection clipboard -o 2>/dev/null"];
        clipboardProc.running = true;
    }

    function acceptPastedText(text) {
        const candidate = String(text || "").trim().split(/\r?\n/)[0].trim();
        if (!root.isWebUrl(candidate)) {
            root.setStatus("Clipboard/drop did not contain an http(s) URL.", true);
            root.openPopout();
            return;
        }
        root.urlDraft = candidate;
        root.activeTab = "search";
        root.setStatus("Link ready — queue it when you are ready.", false);
        root.openPopout();
    }

    pillRightClickAction: () => root.pasteAndOpen()

    horizontalBarPill: Component {
        Item {
            width: pillRow.implicitWidth
            height: pillRow.implicitHeight
            implicitWidth: pillRow.implicitWidth
            implicitHeight: pillRow.implicitHeight
            property bool draggingOver: false

            Row {
                id: pillRow
                spacing: Theme.spacingXS
                DankIcon {
                    name: root.downloading ? "downloading" : (root.previewPlaying ? "play_circle" : "smart_display")
                    size: root.iconSize
                    color: parent.parent.draggingOver || root.downloading ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: root.downloading ? Math.round(root.activePct) + "%" : (root.queuedCount > 0 ? "YT " + root.queuedCount : "YT")
                    color: root.downloading || root.queuedCount > 0 ? Theme.primary : Theme.surfaceText
                    font.pixelSize: root.textSize
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: parent.draggingOver = true
                onExited: parent.draggingOver = false
                onDropped: drop => {
                    parent.draggingOver = false;
                    const text = drop.hasUrls && drop.urls.length > 0 ? drop.urls[0].toString() : (drop.hasText ? drop.text : "");
                    root.acceptPastedText(text);
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            width: Math.max(verticalPillColumn.implicitWidth, root.iconSize)
            height: verticalPillColumn.implicitHeight
            implicitWidth: width
            implicitHeight: height
            property bool draggingOver: false

            Column {
                id: verticalPillColumn
                spacing: 2
                anchors.horizontalCenter: parent.horizontalCenter
                DankIcon {
                    name: root.downloading ? "downloading" : (root.previewPlaying ? "play_circle" : "smart_display")
                    size: root.iconSize
                    color: parent.parent.draggingOver || root.downloading ? Theme.primary : Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                StyledText {
                    text: root.downloading ? Math.round(root.activePct) + "%" : (root.queuedCount > 0 ? String(root.queuedCount) : "YT")
                    color: root.downloading || root.queuedCount > 0 ? Theme.primary : Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: parent.draggingOver = true
                onExited: parent.draggingOver = false
                onDropped: drop => {
                    parent.draggingOver = false;
                    const text = drop.hasUrls && drop.urls.length > 0 ? drop.urls[0].toString() : (drop.hasText ? drop.text : "");
                    root.acceptPastedText(text);
                }
            }
        }
    }

    function searchOutputSize() {
        let size = 0;
        try { size += searchStdout.text.length; } catch (error) {}
        try { size += searchStderr.text.length; } catch (error) {}
        return size;
    }

    function abortSearch(reason) {
        if (root.searchAbortReason !== "")
            return;
        root.searchAbortReason = reason;
        searchTimeout.stop();
        if (searchProc.running)
            searchProc.running = false;
        root.searching = false;
        if (reason === "timeout") {
            root.searchError = "Search timed out after 30 seconds. Try again.";
            root.setStatus("Search timed out.", true);
        } else {
            root.searchError = "Search response exceeded the 1 MB safety limit and was stopped.";
            root.setStatus("Search rejected: response too large.", true);
        }
    }

    function enforceSearchLimits() {
        if (root.searching && root.searchAbortReason === "" && root.searchOutputSize() > root.searchMaxBytes)
            root.abortSearch("too-large");
    }

    function startSearch() {
        const query = String(root.searchQuery || "").trim();
        if (!query || searchProc.running)
            return;
        if (query.length > 250) {
            root.searchError = "Keep searches under 250 characters.";
            root.setStatus(root.searchError, true);
            return;
        }

        root.searchQuery = query;
        root.searching = true;
        root.searchAbortReason = "";
        root.searchError = "";
        root.setStatus("Searching YouTube for “" + query + "”…", false);
        resultsModel.clear();

        const args = ["yt-dlp", "--ignore-config", "--flat-playlist", "--playlist-end", root.maxResults, "-J", "--no-warnings"];
        const cookies = Model.cookiesArgs(root.cookiesBrowser);
        for (let i = 0; i < cookies.length; i++)
            args.push(cookies[i]);
        args.push(Model.searchSpec(query, root.maxResults, root.searchSort));
        searchProc.command = args;
        searchProc.running = true;
        searchTimeout.restart();
    }

    function handleSearchDone(output) {
        searchTimeout.stop();
        if (root.searchAbortReason !== "")
            return;
        root.searching = false;

        const items = Model.parseSearchJson(String(output || ""));
        resultsModel.clear();
        for (let i = 0; i < items.length; i++)
            resultsModel.append(items[i]);

        if (items.length === 0) {
            root.searchError = "No results returned. Check the network, update yt-dlp, or try another query.";
            root.setStatus("Search returned no results.", false);
        } else {
            root.searchError = "";
            root.setStatus(items.length + " results for “" + root.searchQuery + "”.", false);
        }
    }

    function sortLabel(value) {
        switch (value) {
        case "date": return "Newest";
        case "views": return "Most viewed";
        case "short": return "Short (<4 min)";
        case "long": return "Long (>20 min)";
        default: return "Relevance";
        }
    }

    function sortValue(label) {
        switch (String(label)) {
        case "Newest": return "date";
        case "Most viewed": return "views";
        case "Short (<4 min)": return "short";
        case "Long (>20 min)": return "long";
        default: return "relevance";
        }
    }

    function setSort(label) {
        root.saveSetting("searchSort", root.sortValue(label));
    }

    function queueDirectUrl(value) {
        const url = String(value || "").trim();
        if (!root.isWebUrl(url)) {
            root.setStatus("Enter a valid http(s) media URL first.", true);
            return false;
        }
        const label = Model.isPlaylistUrl(url) && root.playlistMode === "playlist" ? "Playlist: " + url : url;
        root.queueDownload(label, url);
        root.urlDraft = "";
        return true;
    }

    function queueDownload(title, url) {
        const cleanUrl = String(url || "").trim();
        if (!root.isWebUrl(cleanUrl)) {
            root.setStatus("Cannot queue this item: it is not a valid http(s) URL.", true);
            return;
        }

        queueModel.append({
            title: String(title || cleanUrl).slice(0, 300),
            url: cleanUrl,
            vid: Model.extractId(cleanUrl),
            mode: root.downloadMode,
            quality: root.quality,
            audioFormat: root.audioFormat,
            videoFormat: root.videoFormat,
            audioLang: root.audioLang,
            subLangs: root.subLangs,
            embedSubs: root.embedSubs,
            cookies: root.cookiesBrowser,
            downloadDir: root.downloadDir,
            playlist: root.playlistMode
        });

        root.activeTab = "downloads";
        root.setStatus("Queued “" + String(title || cleanUrl).slice(0, 80) + "”.", false);
        if (!root.downloading)
            Qt.callLater(root.startNextDownload);
    }

    function startNextDownload() {
        if (root.downloading || downloadProc.running || queueModel.count === 0)
            return;
        const job = queueModel.get(0);
        queueModel.remove(0);
        if (!job || !job.url) {
            Qt.callLater(root.startNextDownload);
            return;
        }

        root.activeTitle = String(job.title || job.url);
        root.activeUrl = String(job.url);
        root.activeMode = String(job.mode || "video");
        root.activePct = 0;
        root.activeDetail = "Starting yt-dlp…";
        root.downloading = true;
        root.setStatus("Downloading “" + root.activeTitle + "”.", false);

        const script = Model.buildDownloadScript({
            url: job.url,
            mode: job.mode,
            quality: job.quality,
            audioFormat: job.audioFormat,
            videoFormat: job.videoFormat,
            audioLang: job.audioLang,
            subLangs: job.subLangs,
            embedSubs: job.embedSubs,
            cookies: job.cookies,
            outDir: job.downloadDir,
            playlist: job.playlist,
            home: root.homeDir
        });
        downloadProc.command = ["bash", "-c", script];
        downloadProc.running = true;
    }

    function handleDownloadLine(line) {
        const text = String(line || "").trim();
        if (!text)
            return;
        const progress = Model.parseProgressLine(text);
        if (progress) {
            root.activePct = progress.pct;
            root.activeDetail = text.slice(0, 140);
            return;
        }
        if (text.indexOf("[info]") === 0 || text.indexOf("[youtube]") === 0 || text.indexOf("[download]") === 0
                || text.indexOf("[Merger]") === 0 || text.indexOf("[ExtractAudio]") === 0
                || text.indexOf("ERROR") !== -1 || text.indexOf("WARNING") !== -1) {
            root.activeDetail = text.slice(0, 140);
        }
    }

    function finishDownload(success, message) {
        if (!root.downloading)
            return;
        const title = root.activeTitle;
        const url = root.activeUrl;
        const mode = root.activeMode;
        if (success) {
            root.activePct = 100;
            root.activeDetail = "Download complete.";
            historyModel.insert(0, {
                title: title,
                detail: (mode === "audio" ? "Audio" : "Video") + " • complete",
                url: url,
                path: "",
                kind: "download"
            });
            while (historyModel.count > 30)
                historyModel.remove(historyModel.count - 1);
            root.setStatus("Download complete: “" + title + "”.", false);
            if (typeof ToastService !== "undefined" && ToastService)
                ToastService.showSuccess("Download complete", title);
        } else {
            root.activeDetail = String(message || root.activeDetail || "Download failed.").slice(0, 180);
            root.setStatus("Download failed: “" + title + "”. " + root.activeDetail, true);
            historyModel.insert(0, {
                title: title,
                detail: "Failed • " + root.activeDetail,
                url: url,
                path: "",
                kind: "failed"
            });
        }
        root.downloading = false;
        if (queueModel.count > 0)
            Qt.callLater(root.startNextDownload);
        else if (success)
            Qt.callLater(() => { if (!root.downloading) root.activePct = 0; });
    }

    function cancelDownloads() {
        queueModel.clear();
        if (root.downloading) {
            root.downloading = false;
            downloadProc.running = false;
            root.activePct = 0;
            root.activeDetail = "Cancelled.";
        }
        root.setStatus("Active download and queued items cancelled.", false);
    }

    function removeQueued(index) {
        if (index >= 0 && index < queueModel.count)
            queueModel.remove(index);
    }

    function openDownloadFolder() {
        const directory = Model.expandHome(root.downloadDir, root.homeDir);
        folderProc.command = ["sh", "-c", "mkdir -p " + Model.shellQuote(directory) + " && xdg-open " + Model.shellQuote(directory) + " >/dev/null 2>&1"];
        folderProc.running = true;
    }

    function checkDependencies() {
        if (dependencyProc.running)
            dependencyProc.running = false;
        dependencySummary = "Checking…";
        dependencyProc.command = ["sh", "-c", "for tool in yt-dlp ffmpeg mpv socat curl whisper-cli whisper; do if command -v \"$tool\" >/dev/null 2>&1; then echo \"$tool: found\"; else echo \"$tool: missing\"; fi; done"];
        dependencyProc.running = true;
    }

    function playVideo(title, url, thumbnail) {
        const cleanUrl = String(url || "").trim();
        if (!root.isWebUrl(cleanUrl)) {
            root.setStatus("Cannot preview this item: invalid URL.", true);
            return;
        }
        if (cleanUrl === root.nowUrl && (root.videoActive || root.audioFallback)) {
            root.togglePlayback();
            return;
        }

        root.stopPlayback();
        root.nowTitle = String(title || cleanUrl);
        root.nowUrl = cleanUrl;
        root.nowId = Model.extractId(cleanUrl);
        root.nowThumb = String(thumbnail || (root.nowId ? "https://i.ytimg.com/vi/" + root.nowId + "/mqdefault.jpg" : ""));
        root.playerError = "";
        root.resolving = true;
        root.setStatus("Resolving a playable stream…", false);

        if (root.downloadMode === "audio") {
            root.startAudioFallback();
            return;
        }

        resolveProc.command = ["yt-dlp", "--ignore-config", "-g", "-f", "22/18/17/36/b[vcodec^=avc1][height<=480]/b[height<=480]/w", "--no-warnings"]
            .concat(Model.cookiesArgs(root.cookiesBrowser))
            .concat([cleanUrl]);
        resolveProc.running = true;
    }

    function handleResolveDone(output) {
        if (!root.resolving)
            return;
        root.resolving = false;
        const lines = String(output || "").split("\n");
        let stream = "";
        for (let i = 0; i < lines.length; i++) {
            const candidate = lines[i].trim();
            if (/^https?:\/\//i.test(candidate)) {
                stream = candidate;
                break;
            }
        }
        if (!stream) {
            root.startVideoCache();
            return;
        }
        root.startEmbeddedPlayback(stream, "Playing in the DMS popout: “" + root.nowTitle + "”.");
    }

    function startEmbeddedPlayback(source, successStatus) {
        const mediaSource = String(source || "");
        if (!mediaSource)
            return;

        if (root.mediaPlayerUnavailable) {
            root.pendingEmbeddedSource = "";
            root.pendingEmbeddedStatus = "";
            root.startAudioFallback();
            return;
        }

        if (!root.player) {
            root.pendingEmbeddedSource = mediaSource;
            root.pendingEmbeddedStatus = String(successStatus || "");
            root.videoActive = true;
            root.audioFallback = false;
            root.previewPlaying = false;
            root.previewPaused = false;
            root.setStatus("Preparing embedded video preview…", false);
            return;
        }

        root.pendingEmbeddedSource = "";
        root.pendingEmbeddedStatus = "";
        root.videoActive = true;
        root.audioFallback = false;
        root.playerError = "";
        try {
            root.player.source = mediaSource;
            root.player.play();
            root.setStatus(String(successStatus || "Playing preview."), false);
        } catch (error) {
            root.videoActive = false;
            root.startAudioFallback();
        }
    }

    function handleMediaPlayerUnavailable() {
        root.mediaPlayerUnavailable = true;
        root.playerError = "Embedded preview is unavailable: the QtMultimedia QML module could not be loaded. Install your distro's Qt Multimedia QML package (qt6-multimedia on Arch).";
        if (root.pendingEmbeddedSource !== "")
            root.startAudioFallback();
    }

    function startVideoCache() {
        if (!root.nowUrl)
            return;
        root.cachingVideo = true;
        root.cachePct = 0;
        root.cacheDetail = "Downloading a local preview copy…";
        root.cacheFile = Model.cacheFileFor(root.nowId, root.homeDir);
        root.setStatus("Caching a compatible video for in-popout playback…", false);
        cacheProc.command = ["bash", "-c", Model.buildCacheScript(root.nowUrl, root.cacheFile, root.cookiesBrowser)];
        cacheProc.running = true;
    }

    function handleCacheLine(line) {
        const text = String(line || "").trim();
        if (!text)
            return;
        const progress = Model.parseProgressLine(text);
        if (progress) {
            root.cachePct = progress.pct;
            root.cacheDetail = text.slice(0, 140);
        } else if (text.indexOf("[info]") === 0 || text.indexOf("[Merger]") === 0 || text.indexOf("ERROR") !== -1) {
            root.cacheDetail = text.slice(0, 140);
        }
    }

    function finishVideoCache(success) {
        if (!root.cachingVideo)
            return;
        root.cachingVideo = false;
        if (success) {
            root.startEmbeddedPlayback("file://" + root.cacheFile, "Playing cached preview: “" + root.nowTitle + "”.");
        } else {
            root.cacheDetail = "Video cache failed; trying mpv audio preview.";
            root.startAudioFallback();
        }
    }

    function startAudioFallback() {
        root.pendingEmbeddedSource = "";
        root.pendingEmbeddedStatus = "";
        try {
            if (root.player) {
                root.player.stop();
                root.player.source = "";
            }
        } catch (error) {}
        root.resolving = false;
        root.cachingVideo = false;
        root.videoActive = false;
        root.audioFallback = true;
        root.previewPaused = false;
        root.previewPlaying = true;
        root.playerError = root.mediaPlayerUnavailable
                ? "QtMultimedia is unavailable — trying mpv audio preview."
                : "Video stream unavailable — using mpv audio preview.";
        previewProc.command = ["mpv", "--no-video", "--force-window=no", "--no-terminal", "--input-ipc-server=" + root.mpvSocket, "--ytdl-format=bestaudio/best", root.nowUrl];
        previewProc.running = true;
        root.setStatus(root.playerError, false);
    }

    function togglePlayback() {
        if (root.videoActive) {
            if (!root.player)
                return;
            if (root.player.isPlaying)
                root.player.pause();
            else
                root.player.play();
            return;
        }
        if (root.audioFallback && root.previewPlaying) {
            const message = '{"command":["cycle","pause"]}';
            controlProc.command = ["bash", "-c", "printf '%s\\n' " + Model.shellQuote(message) + " | socat - UNIX-CONNECT:" + Model.shellQuote(root.mpvSocket) + " >/dev/null 2>&1"];
            controlProc.running = true;
            root.previewPaused = !root.previewPaused;
        }
    }

    function stopPlayback() {
        if (resolveProc.running)
            resolveProc.running = false;
        if (cacheProc.running)
            cacheProc.running = false;
        if (previewProc.running)
            previewProc.running = false;
        root.pendingEmbeddedSource = "";
        root.pendingEmbeddedStatus = "";
        try {
            if (root.player) {
                root.player.stop();
                root.player.source = "";
            }
        } catch (error) {}
        root.resolving = false;
        root.cachingVideo = false;
        root.cachePct = 0;
        root.videoActive = false;
        root.audioFallback = false;
        root.previewPlaying = false;
        root.previewPaused = false;
        root.playerError = "";
    }

    function openCurrentExternal() {
        if (root.nowUrl)
            Quickshell.execDetached(["xdg-open", root.nowUrl]);
    }

    function openCurrentMpv() {
        if (root.nowUrl)
            Quickshell.execDetached(["mpv", "--fullscreen", root.nowUrl]);
    }

    function startTranscription(title, url) {
        const cleanUrl = String(url || "").trim();
        if (!root.isWebUrl(cleanUrl)) {
            root.setStatus("Cannot transcribe this item: invalid URL.", true);
            return;
        }
        if (root.transcribing || transcribeProc.running) {
            root.setStatus("A transcription is already running or stopping.", false);
            return;
        }
        if (root.whisperEngine === "off") {
            root.setStatus("Transcription is disabled. Choose Local or OpenAI in DMS plugin settings.", false);
            return;
        }

        root.transcribing = true;
        root.transcribePct = 0;
        root.transcribeTitle = String(title || cleanUrl);
        root.transcribeUrl = cleanUrl;
        root.transcribeOutputPath = "";
        root.transcribeDetail = "Preparing transcription…";
        root.activeTab = "downloads";
        root.setStatus("Transcribing “" + root.transcribeTitle + "”.", false);

        const script = Model.buildTranscribeScript({
            url: cleanUrl,
            id: "",
            outDir: root.downloadDir,
            engine: root.whisperEngine,
            localCmd: root.whisperCmd,
            lang: root.whisperLang,
            model: root.whisperModel,
            apiModel: root.whisperApiModel,
            keyEnv: root.whisperKeyEnv,
            cookies: root.cookiesBrowser,
            cacheDir: Model.cacheDir(root.homeDir),
            home: root.homeDir
        });
        transcribeProc.command = ["bash", "-c", script];
        transcribeProc.running = true;
    }

    function handleTranscribeLine(line) {
        const text = String(line || "").trim();
        if (!text)
            return;
        const downloadProgress = Model.parseProgressLine(text);
        if (downloadProgress) {
            root.transcribePct = downloadProgress.pct;
            root.transcribeDetail = "Downloading audio… " + Math.round(downloadProgress.pct) + "%";
            return;
        }
        const whisperProgress = /progress\s*=\s*(\d+)\s*%/i.exec(text);
        if (whisperProgress) {
            root.transcribePct = Math.max(0, Math.min(100, parseInt(whisperProgress[1], 10)));
            root.transcribeDetail = "Transcribing… " + Math.round(root.transcribePct) + "%";
            return;
        }
        if (text.indexOf("DONE:") === 0) {
            root.transcribePct = 100;
            root.transcribeOutputPath = text.slice(5).trim();
            root.transcribeDetail = "Saved: " + root.transcribeOutputPath;
            return;
        }
        root.transcribeDetail = text.slice(0, 180);
    }

    function cancelTranscription() {
        if (transcribeProc.running)
            transcribeProc.running = false;
        root.transcribing = false;
        root.transcribeDetail = "Cancelled.";
        root.transcribePct = 0;
        root.setStatus("Transcription cancelled.", false);
    }

    function handleTranscriptionExit(exitCode) {
        if (!root.transcribing)
            return;
        root.transcribing = false;
        if (exitCode === 0) {
            root.transcribePct = 100;
            historyModel.insert(0, {
                title: root.transcribeTitle,
                detail: "Subtitles • " + (root.whisperEngine === "openai" ? root.whisperApiModel : "local Whisper"),
                url: root.transcribeUrl,
                path: root.transcribeOutputPath,
                kind: "transcription"
            });
            while (historyModel.count > 30)
                historyModel.remove(historyModel.count - 1);
            root.setStatus("Transcription complete: " + root.transcribeDetail, false);
            if (typeof ToastService !== "undefined" && ToastService)
                ToastService.showSuccess("Transcription complete", root.transcribeTitle);
        } else {
            root.setStatus("Transcription failed (exit " + exitCode + "): " + root.transcribeDetail, true);
        }
    }

    function clearHistory() {
        historyModel.clear();
    }

    function clearQueue() {
        queueModel.clear();
        root.setStatus("Queued items cleared.", false);
    }

    function openUrl(url) {
        const value = String(url || "");
        if (root.isWebUrl(value))
            Quickshell.execDetached(["xdg-open", value]);
    }

    ListModel { id: resultsModel }
    ListModel { id: queueModel }
    ListModel { id: historyModel }

    Timer {
        id: searchTimeout
        interval: root.searchTimeoutMs
        repeat: false
        onTriggered: root.abortSearch("timeout")
    }

    Process {
        id: searchProc
        stdout: StdioCollector {
            id: searchStdout
            waitForEnd: true
            onDataChanged: root.enforceSearchLimits()
            onStreamFinished: {
                if (root.searchAbortReason === "")
                    root.handleSearchDone(String(text || ""));
            }
        }
        stderr: StdioCollector {
            id: searchStderr
            waitForEnd: true
            onDataChanged: root.enforceSearchLimits()
        }
        onExited: (exitCode) => {
            searchTimeout.stop();
            if (root.searchAbortReason !== "")
                return;
            if (exitCode !== 0 && root.searching) {
                root.searching = false;
                root.searchError = "Search failed (exit " + exitCode + "). Check that yt-dlp is installed and up to date.";
                root.setStatus(root.searchError, true);
            } else if (exitCode !== 0 && resultsModel.count === 0) {
                root.searchError = "Search failed (exit " + exitCode + ").";
                root.setStatus(root.searchError, true);
            }
        }
    }

    Process {
        id: resolveProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.handleResolveDone(String(text || ""))
        }
        stderr: StdioCollector { waitForEnd: true }
        onExited: (exitCode) => {
            if (exitCode !== 0 && root.resolving) {
                root.resolving = false;
                root.startAudioFallback();
            }
        }
    }

    Process {
        id: cacheProc
        stdout: SplitParser { onRead: line => root.handleCacheLine(line) }
        stderr: SplitParser { onRead: line => root.handleCacheLine(line) }
        onExited: (exitCode) => root.finishVideoCache(exitCode === 0)
    }

    Process {
        id: downloadProc
        stdout: SplitParser { onRead: line => root.handleDownloadLine(line) }
        stderr: SplitParser { onRead: line => root.handleDownloadLine(line) }
        onExited: (exitCode) => {
            if (root.downloading)
                root.finishDownload(exitCode === 0, root.activeDetail);
            else if (queueModel.count > 0)
                Qt.callLater(root.startNextDownload);
        }
    }

    Process { id: folderProc }
    Process { id: controlProc }

    Process {
        id: previewProc
        onExited: (exitCode) => {
            if (root.audioFallback) {
                root.audioFallback = false;
                root.previewPlaying = false;
                root.previewPaused = false;
                if (exitCode !== 0) {
                    root.playerError = "mpv audio preview failed. Check that mpv and socat are installed.";
                    root.setStatus(root.playerError, true);
                }
            }
        }
    }

    Process {
        id: transcribeProc
        stdout: SplitParser { onRead: line => root.handleTranscribeLine(line) }
        stderr: SplitParser { onRead: line => root.handleTranscribeLine(line) }
        onExited: (exitCode) => root.handleTranscriptionExit(exitCode)
    }

    Process {
        id: dependencyProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.dependencySummary = String(text || "").trim()
        }
        stderr: StdioCollector { waitForEnd: true }
    }

    Process {
        id: clipboardProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.acceptPastedText(String(text || ""))
        }
        stderr: StdioCollector { waitForEnd: true }
    }

    // QtMultimedia is optional in Quickshell. Isolate it behind a Loader so a
    // missing QML module disables embedded preview, not the whole plugin.
    Loader {
        id: mediaPlayerLoader
        active: true
        source: Qt.resolvedUrl("./OmaYoutubeMediaPlayer.qml")
        visible: false
        width: 0
        height: 0

        onLoaded: {
            root.player = item;
            root.mediaPlayerUnavailable = false;
            if (root.videoOutputRef)
                item.videoOutput = root.videoOutputRef;
            if (root.pendingEmbeddedSource !== "")
                root.startEmbeddedPlayback(root.pendingEmbeddedSource, root.pendingEmbeddedStatus);
        }
        onStatusChanged: {
            if (status === Loader.Error && !root.mediaPlayerUnavailable) {
                root.player = null;
                root.handleMediaPlayerUnavailable();
            }
        }
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true

        function onPlaybackStateUpdated() {
            if (!root.player)
                return;
            root.previewPlaying = root.player.isPlaying || root.player.isPaused;
            root.previewPaused = root.player.isPaused;
        }
        function onMediaError(message) {
            root.playerError = String(message || "Embedded playback failed.").slice(0, 180);
            if (root.nowUrl && !root.audioFallback) {
                root.videoActive = false;
                root.startAudioFallback();
            }
        }
    }

    IpcHandler {
        target: "omaYoutubeDl"

        function open(): string {
            root.openPopout();
            return "opened";
        }
        function close(): string {
            root.closePopout();
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
            root.activeTab = "search";
            root.searchQuery = value;
            root.startSearch();
            root.openPopout();
            return "searching";
        }
        function download(url: string): string {
            const value = String(url || "").trim();
            if (!root.isWebUrl(value))
                return "ERROR: expected an http(s) URL";
            root.queueDownload(value, value);
            root.openPopout();
            return "queued";
        }
        function play(url: string): string {
            const value = String(url || "").trim();
            if (!root.isWebUrl(value))
                return "ERROR: expected an http(s) URL";
            root.activeTab = "search";
            root.playVideo(value, value, "");
            root.openPopout();
            return "playing";
        }
        function transcribe(url: string): string {
            const value = String(url || "").trim();
            if (!root.isWebUrl(value))
                return "ERROR: expected an http(s) URL";
            root.startTranscription(value, value);
            root.openPopout();
            return "transcribing";
        }
    }

    Component.onDestruction: root.stopPlayback()

    popoutWidth: 620
    popoutHeight: 700

    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: "Oma YouTube"
            detailsText: "Search, preview, and download media with yt-dlp."
            implicitHeight: popout.headerHeight + popout.detailsHeight + panelBody.implicitHeight + Theme.spacingS

            Column {
                id: panelBody
                width: parent.width
                spacing: Theme.spacingS
                implicitHeight: tabRow.implicitHeight + statusRow.implicitHeight + pageScroller.height + spacing * 2

                Row {
                    id: tabRow
                    width: parent.width
                    spacing: Theme.spacingS

                    DankButton {
                        width: (parent.width - parent.spacing) / 2
                        text: "Search"
                        iconName: "search"
                        buttonHeight: Theme.buttonHeightM
                        backgroundColor: root.activeTab === "search" ? Theme.primary : Theme.surfaceContainerHigh
                        textColor: root.activeTab === "search" ? Theme.onPrimary : Theme.surfaceText
                        onClicked: root.activeTab = "search"
                    }
                    DankButton {
                        width: (parent.width - parent.spacing) / 2
                        text: "Downloads" + (root.downloading ? " · " + Math.round(root.activePct) + "%" : (root.queuedCount > 0 ? " · " + root.queuedCount : ""))
                        iconName: "download"
                        buttonHeight: Theme.buttonHeightM
                        backgroundColor: root.activeTab === "downloads" ? Theme.primary : Theme.surfaceContainerHigh
                        textColor: root.activeTab === "downloads" ? Theme.onPrimary : Theme.surfaceText
                        onClicked: root.activeTab = "downloads"
                    }
                }

                StyledText {
                    id: statusRow
                    width: parent.width
                    text: root.statusLine
                    color: root.statusIsError ? Theme.error : Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }

                ScrollView {
                    id: pageScroller
                    width: parent.width
                    height: 500
                    clip: true
                    contentWidth: width

                    Column {
                        width: pageScroller.width
                        spacing: Theme.spacingM

                        Column {
                            id: searchPage
                            visible: root.activeTab === "search"
                            width: parent.width
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS
                                DankTextField {
                                    id: searchInput
                                    width: parent.width - searchButton.width - parent.spacing
                                    placeholderText: "Search YouTube…"
                                    text: root.searchQuery
                                    onTextEdited: root.searchQuery = text
                                    onAccepted: root.startSearch()
                                }
                                DankButton {
                                    id: searchButton
                                    width: 108
                                    text: root.searching ? "Searching" : "Search"
                                    iconName: "search"
                                    busy: root.searching
                                    enabled: !root.searching
                                    buttonHeight: Theme.buttonHeightM
                                    backgroundColor: Theme.primary
                                    textColor: Theme.onPrimary
                                    onClicked: root.startSearch()
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS
                                StyledText {
                                    width: 48
                                    text: "Sort"
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                DankDropdown {
                                    width: parent.width - 48 - parent.spacing
                                    compactMode: true
                                    options: ["Relevance", "Newest", "Most viewed", "Short (<4 min)", "Long (>20 min)"]
                                    currentValue: root.sortLabel(root.searchSort)
                                    onValueChanged: value => root.setSort(value)
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
                                    buttonHeight: Theme.buttonHeightXS
                                    backgroundColor: root.downloadMode === "video" ? Theme.primary : Theme.surfaceContainerHigh
                                    textColor: root.downloadMode === "video" ? Theme.onPrimary : Theme.surfaceText
                                    onClicked: root.saveSetting("dlMode", "video")
                                }
                                DankButton {
                                    text: "Audio"
                                    iconName: "headphones"
                                    buttonHeight: Theme.buttonHeightXS
                                    backgroundColor: root.downloadMode === "audio" ? Theme.primary : Theme.surfaceContainerHigh
                                    textColor: root.downloadMode === "audio" ? Theme.onPrimary : Theme.surfaceText
                                    onClicked: root.saveSetting("dlMode", "audio")
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS
                                DankTextField {
                                    id: urlInput
                                    width: parent.width - queueUrlButton.width - parent.spacing
                                    placeholderText: "Paste a video or playlist URL…"
                                    text: root.urlDraft
                                    onTextEdited: root.urlDraft = text
                                    onAccepted: root.queueDirectUrl(root.urlDraft)
                                }
                                DankButton {
                                    id: queueUrlButton
                                    width: 108
                                    text: "Queue"
                                    iconName: "playlist_add"
                                    buttonHeight: Theme.buttonHeightM
                                    onClicked: root.queueDirectUrl(root.urlDraft)
                                }
                            }

                            StyledText {
                                width: parent.width
                                visible: root.searchError !== ""
                                text: root.searchError
                                color: Theme.error
                                font.pixelSize: Theme.fontSizeSmall
                                wrapMode: Text.WordWrap
                            }

                            Rectangle {
                                id: playerCard
                                visible: root.nowTitle !== ""
                                width: parent.width
                                height: playerColumn.implicitHeight + Theme.spacingM * 2
                                implicitHeight: height
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: Theme.withAlpha(Theme.primary, 0.45)

                                Column {
                                    id: playerColumn
                                    x: Theme.spacingM
                                    y: Theme.spacingM
                                    width: parent.width - Theme.spacingM * 2
                                    spacing: Theme.spacingS

                                    Row {
                                        width: parent.width
                                        spacing: Theme.spacingS
                                        StyledText {
                                            width: parent.width - playerStopButton.width - parent.spacing
                                            text: root.nowTitle
                                            color: Theme.surfaceText
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        DankActionButton {
                                            id: playerStopButton
                                            iconName: "close"
                                            iconColor: Theme.error
                                            tooltipText: "Stop preview"
                                            onClicked: root.stopPlayback()
                                        }
                                    }

                                    Item {
                                        id: videoBox
                                        width: parent.width
                                        height: root.showVideo ? 168 : 0
                                        visible: root.showVideo
                                        clip: true

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.cornerRadius
                                            color: "#08090b"
                                        }
                                        Image {
                                            anchors.fill: parent
                                            source: root.nowThumb
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                            visible: !root.player || !root.player.hasVideo
                                            opacity: 0.45
                                        }
                                        Loader {
                                            id: embeddedVideoOutputLoader
                                            anchors.fill: parent
                                            sourceComponent: root.player ? root.player.videoOutputComponent : null
                                            visible: root.videoActive && root.player !== null && root.player.hasVideo

                                            onLoaded: {
                                                root.videoOutputRef = item;
                                                if (root.player)
                                                    root.player.videoOutput = item;
                                            }
                                            onItemChanged: {
                                                if (!item && root.videoOutputRef) {
                                                    if (root.player && root.player.videoOutput === root.videoOutputRef)
                                                        root.player.videoOutput = null;
                                                    root.videoOutputRef = null;
                                                }
                                            }
                                        }
                                        StyledText {
                                            anchors.centerIn: parent
                                            text: root.mediaPlayerUnavailable ? (root.audioFallback ? "QtMultimedia unavailable — using mpv audio preview." : root.playerError) : (root.resolving ? "Resolving stream…" : (root.cachingVideo ? "Caching video · " + Math.round(root.cachePct) + "%\n" + root.cacheDetail : (root.playerError !== "" ? root.playerError : (root.audioFallback ? "Audio preview in mpv" : ""))))
                                            color: "white"
                                            font.pixelSize: Theme.fontSizeSmall
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.WordWrap
                                            width: parent.width - Theme.spacingM * 2
                                            visible: root.mediaPlayerUnavailable || root.resolving || root.cachingVideo || ((!root.player || !root.player.hasVideo) && (root.playerError !== "" || root.audioFallback))
                                        }
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: Theme.spacingXS
                                        DankButton {
                                            text: root.previewPaused ? "Resume" : "Play / pause"
                                            iconName: root.previewPaused ? "play_arrow" : "pause"
                                            buttonHeight: Theme.buttonHeightS
                                            enabled: root.videoActive || root.audioFallback
                                            onClicked: root.togglePlayback()
                                        }
                                        DankButton {
                                            text: "Open player"
                                            iconName: "open_in_new"
                                            buttonHeight: Theme.buttonHeightS
                                            onClicked: root.openCurrentExternal()
                                        }
                                        DankButton {
                                            text: "mpv fullscreen"
                                            iconName: "fullscreen"
                                            buttonHeight: Theme.buttonHeightS
                                            onClicked: root.openCurrentMpv()
                                        }
                                        DankActionButton {
                                            iconName: "subtitles"
                                            tooltipText: "Transcribe subtitles"
                                            enabled: root.whisperEngine !== "off" && !root.transcribing
                                            onClicked: root.startTranscription(root.nowTitle, root.nowUrl)
                                        }
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: Theme.spacingS
                                        DankSlider {
                                            id: seekSlider
                                            width: parent.width - seekLabel.implicitWidth - parent.spacing
                                            minimum: 0
                                            maximum: root.player ? Math.max(1, root.player.duration) : 1
                                            value: root.videoActive && root.player ? root.player.position : 0
                                            unit: ""
                                            showValue: false
                                            enabled: root.videoActive && root.player !== null && root.player.duration > 0
                                            onSliderDragFinished: value => {
                                                if (root.videoActive && root.player && root.player.duration > 0)
                                                    root.player.position = value;
                                            }
                                        }
                                        StyledText {
                                            id: seekLabel
                                            text: root.videoActive && root.player ? Model.fmtTime(root.player.position) + " / " + Model.fmtTime(root.player.duration) : (root.audioFallback ? "mpv audio" : "")
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
                                    text: root.searching ? "Searching…" : (resultsModel.count > 0 ? "Search results · " + resultsModel.count : "Results")
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: Theme.spacingXS
                                Repeater {
                                    model: resultsModel
                                    delegate: Rectangle {
                                        required property int index
                                        width: parent.width
                                        height: 84
                                        radius: Theme.cornerRadius
                                        color: resultHover.hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                        border.width: 1
                                        border.color: Theme.withAlpha(Theme.outlineVariant, 0.42)

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingS
                                            spacing: Theme.spacingS

                                            Rectangle {
                                                width: 108
                                                height: 62
                                                radius: Theme.cornerRadius / 2
                                                color: Theme.surfaceContainerLowest
                                                clip: true
                                                anchors.verticalCenter: parent.verticalCenter
                                                Image {
                                                    anchors.fill: parent
                                                    source: model.thumb
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    cache: true
                                                }
                                                StyledText {
                                                    anchors.centerIn: parent
                                                    text: "play_circle"
                                                    color: "white"
                                                    font.pixelSize: Theme.fontSizeXLarge
                                                    visible: false
                                                }
                                            }

                                            Column {
                                                width: Math.max(90, parent.width - 108 - resultActions.implicitWidth - parent.spacing * 2)
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
                                                    text: model.channel + "  ·  " + model.duration
                                                    color: Theme.surfaceVariantText
                                                    font.pixelSize: Theme.fontSizeSmall - 1
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Row {
                                                id: resultActions
                                                spacing: 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                DankActionButton {
                                                    iconName: "play_arrow"
                                                    tooltipText: "Preview"
                                                    iconColor: Theme.primary
                                                    onClicked: root.playVideo(model.title, model.url, model.thumb)
                                                }
                                                DankActionButton {
                                                    iconName: "download"
                                                    tooltipText: "Queue download"
                                                    iconColor: Theme.primary
                                                    onClicked: root.queueDownload(model.title, model.url)
                                                }
                                                DankActionButton {
                                                    iconName: "subtitles"
                                                    tooltipText: "Transcribe subtitles"
                                                    iconColor: root.whisperEngine === "off" ? Theme.surfaceVariantText : Theme.primary
                                                    enabled: root.whisperEngine !== "off" && !root.transcribing
                                                    onClicked: root.startTranscription(model.title, model.url)
                                                }
                                            }
                                        }

                                        HoverHandler { id: resultHover }
                                    }
                                }
                            }
                        }

                        Column {
                            id: downloadsPage
                            visible: root.activeTab === "downloads"
                            width: parent.width
                            spacing: Theme.spacingM

                            Rectangle {
                                visible: root.downloading
                                width: parent.width
                                height: activeDownloadColumn.implicitHeight + Theme.spacingM * 2
                                implicitHeight: height
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: Theme.withAlpha(Theme.primary, 0.45)
                                Column {
                                    id: activeDownloadColumn
                                    x: Theme.spacingM
                                    y: Theme.spacingM
                                    width: parent.width - Theme.spacingM * 2
                                    spacing: Theme.spacingS
                                    Row {
                                        width: parent.width
                                        StyledText {
                                            width: parent.width - cancelDownloadButton.width - Theme.spacingS
                                            text: root.activeTitle
                                            color: Theme.surfaceText
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        DankActionButton {
                                            id: cancelDownloadButton
                                            iconName: "close"
                                            iconColor: Theme.error
                                            tooltipText: "Cancel downloads"
                                            onClicked: root.cancelDownloads()
                                        }
                                    }
                                    Rectangle {
                                        width: parent.width
                                        height: 8
                                        radius: height / 2
                                        color: Theme.withAlpha(Theme.surfaceText, 0.12)
                                        Rectangle {
                                            width: parent.width * Math.max(0, Math.min(1, root.activePct / 100))
                                            height: parent.height
                                            radius: parent.radius
                                            color: Theme.primary
                                        }
                                    }
                                    StyledText {
                                        width: parent.width
                                        text: Math.round(root.activePct) + "%  ·  " + root.activeDetail
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            Rectangle {
                                visible: root.transcribing || root.transcribeDetail !== "Idle"
                                width: parent.width
                                height: transcribeColumn.implicitHeight + Theme.spacingM * 2
                                implicitHeight: height
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: Theme.withAlpha(Theme.primary, 0.45)
                                Column {
                                    id: transcribeColumn
                                    x: Theme.spacingM
                                    y: Theme.spacingM
                                    width: parent.width - Theme.spacingM * 2
                                    spacing: Theme.spacingS
                                    Row {
                                        width: parent.width
                                        StyledText {
                                            width: parent.width - cancelTranscribeButton.width - Theme.spacingS
                                            text: "Subtitles · " + root.transcribeTitle
                                            color: Theme.surfaceText
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        DankActionButton {
                                            id: cancelTranscribeButton
                                            iconName: root.transcribing ? "close" : "check"
                                            iconColor: root.transcribing ? Theme.error : Theme.primary
                                            tooltipText: root.transcribing ? "Cancel transcription" : "Dismiss transcription status"
                                            onClicked: {
                                                if (root.transcribing) {
                                                    root.cancelTranscription();
                                                } else {
                                                    root.transcribeDetail = "Idle";
                                                    root.transcribeTitle = "";
                                                    root.transcribePct = 0;
                                                }
                                            }
                                        }
                                    }
                                    Rectangle {
                                        width: parent.width
                                        height: 8
                                        radius: height / 2
                                        color: Theme.withAlpha(Theme.surfaceText, 0.12)
                                        Rectangle {
                                            width: parent.width * Math.max(0, Math.min(1, root.transcribePct / 100))
                                            height: parent.height
                                            radius: parent.radius
                                            color: Theme.primary
                                        }
                                    }
                                    StyledText {
                                        width: parent.width
                                        text: Math.round(root.transcribePct) + "%  ·  " + root.transcribeDetail
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS
                                StyledText {
                                    width: parent.width - folderButton.width - clearHistoryButton.width - parent.spacing * 2
                                    text: "Queue & history"
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                DankButton {
                                    id: folderButton
                                    text: "Folder"
                                    iconName: "folder_open"
                                    buttonHeight: Theme.buttonHeightXS
                                    onClicked: root.openDownloadFolder()
                                }
                                DankActionButton {
                                    id: clearHistoryButton
                                    iconName: "delete_sweep"
                                    iconColor: Theme.error
                                    tooltipText: "Clear history"
                                    enabled: historyModel.count > 0
                                    onClicked: root.clearHistory()
                                }
                            }

                            StyledText {
                                width: parent.width
                                visible: queueModel.count === 0
                                text: root.downloading ? "No more items waiting." : "Your queue is empty. Queue a result or paste a direct link."
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                                wrapMode: Text.WordWrap
                            }

                            Column {
                                width: parent.width
                                spacing: Theme.spacingXS
                                Repeater {
                                    model: queueModel
                                    delegate: Rectangle {
                                        required property int index
                                        width: parent.width
                                        height: 58
                                        radius: Theme.cornerRadius
                                        color: Theme.surfaceContainerHigh
                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingS
                                            spacing: Theme.spacingS
                                            DankIcon {
                                                name: model.mode === "audio" ? "headphones" : "videocam"
                                                size: Theme.iconSize
                                                color: Theme.primary
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Column {
                                                width: parent.width - Theme.iconSize - removeQueueButton.width - parent.spacing * 2
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
                                                id: removeQueueButton
                                                iconName: "close"
                                                iconColor: Theme.error
                                                tooltipText: "Remove from queue"
                                                anchors.verticalCenter: parent.verticalCenter
                                                onClicked: root.removeQueued(index)
                                            }
                                        }
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS
                                StyledText {
                                    width: parent.width - clearQueueButton.width - parent.spacing
                                    text: "Recent items · " + historyModel.count
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                DankButton {
                                    id: clearQueueButton
                                    text: "Cancel queue"
                                    iconName: "delete_sweep"
                                    buttonHeight: Theme.buttonHeightXS
                                    visible: queueModel.count > 0
                                    textColor: Theme.error
                                    backgroundColor: Theme.withAlpha(Theme.error, 0.12)
                                    onClicked: root.clearQueue()
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: Theme.spacingXS
                                Repeater {
                                    model: historyModel
                                    delegate: Rectangle {
                                        required property int index
                                        width: parent.width
                                        height: 58
                                        radius: Theme.cornerRadius
                                        color: Theme.surfaceContainerHigh
                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingS
                                            spacing: Theme.spacingS
                                            DankIcon {
                                                name: model.kind === "transcription" ? "subtitles" : (model.kind === "failed" ? "error" : "check_circle")
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
                                                tooltipText: model.kind === "transcription" ? "Open transcription output" : "Open download folder"
                                                anchors.verticalCenter: parent.verticalCenter
                                                onClicked: {
                                                    if (model.kind === "transcription" && model.path)
                                                        Quickshell.execDetached(["xdg-open", model.path]);
                                                    else if (model.kind === "transcription")
                                                        root.openUrl(model.url);
                                                    else
                                                        root.openDownloadFolder();
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
                                            buttonHeight: Theme.buttonHeightXS
                                            onClicked: root.checkDependencies()
                                        }
                                    }
                                    StyledText {
                                        width: parent.width
                                        text: root.dependencySummary || "yt-dlp and ffmpeg are required. mpv + socat enable audio fallback controls; Whisper and curl are optional."
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
    }
}
