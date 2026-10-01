import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "./Model.js" as Model

// Runtime logic is kept separate from the PluginComponent and its presentation.
// The DMS plugin host injects pluginId, pluginService, and pluginData into the
// PluginComponent; OmaYoutubeWidget passes those values into this controller.
Item {
    id: root
    width: 0
    height: 0
    visible: false

    property string pluginId: ""
    property var pluginService: null
    property var settingsData: ({})

    property string activeTab: "search"
    property string searchQuery: ""
    property string urlDraft: ""
    property string statusLine: "Search YouTube or paste a media URL."
    property bool statusIsError: false
    property string searchError: ""
    property string dependencySummary: ""
    property bool searching: false
    property bool searchStopping: false
    property string searchAbortReason: ""
    property bool searchStdoutFinished: false
    property bool searchStderrFinished: false
    property bool searchProcessExited: false
    property bool searchFinalized: true
    property int searchExitCode: 0

    property bool popoutOpen: false

    property string nowTitle: ""
    property string nowUrl: ""
    property string nowId: ""
    property string nowThumb: ""
    property bool resolving: false
    property var resolveProcess: null
    property bool cachingVideo: false
    property var cacheProcess: null
    property real cachePct: 0
    property string cacheDetail: ""
    property string cacheFile: ""
    property bool videoActive: false
    property bool audioFallback: false
    property bool previewPlaying: false
    property bool previewPaused: false
    property bool pendingAudioFallbackStart: false
    property int previewGeneration: 0
    property var previewProcess: null
    property string playerError: ""
    property var player: null
    property var videoOutputRef: null
    property bool mediaPlayerUnavailable: false
    property string pendingEmbeddedSource: ""
    property string pendingEmbeddedStatus: ""

    property bool downloading: false
    property bool downloadStopping: false
    property real activePct: 0
    property string activeTitle: ""
    property string activeUrl: ""
    property string activeMode: "video"
    property string activeDetail: "Idle"

    property bool transcribing: false
    property bool transcriptionStopping: false
    property real transcribePct: 0
    property string transcribeTitle: ""
    property string transcribeUrl: ""
    property string transcribeOutputPath: ""
    property string transcribeDetail: "Idle"

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string mpvSocket: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/dms-oma-youtube-dl.sock"
    readonly property int searchMaxBytes: 1048576
    readonly property int searchTimeoutMs: 30000
    readonly property int queuedCount: downloadQueue.count

    property alias resultsModel: searchResults
    property alias queueModel: downloadQueue
    property alias historyModel: recentHistory

    function configuredValue(key, fallback) {
        const value = root.settingsData ? root.settingsData[key] : undefined;
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
    readonly property bool showVideo: settingsData && settingsData.showVideo !== undefined ? settingsData.showVideo === true : true
    readonly property string audioLang: {
        const value = String(configuredValue("audioLang", "original"));
        return ["original", "pt", "original+pt", "pt+en"].indexOf(value) >= 0 ? value : "original";
    }
    readonly property string subLangs: {
        const value = String(configuredValue("subLangs", "off"));
        return ["off", "pt,pt-BR,pt-PT", "pt,pt-BR,pt-PT,en", "all"].indexOf(value) >= 0 ? value : "off";
    }
    readonly property bool embedSubs: settingsData && settingsData.embedSubs === true
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
    readonly property string whisperApiModel: {
        const value = String(configuredValue("whisperApiModel", "whisper-1"));
        return ["whisper-1", "gpt-4o-transcribe", "gpt-4o-mini-transcribe"].indexOf(value) >= 0 ? value : "whisper-1";
    }
    readonly property string whisperKeyEnv: String(configuredValue("whisperKeyEnv", "OPENAI_API_KEY"))

    function saveSetting(key, value) {
        if (root.pluginService && typeof root.pluginService.savePluginData === "function")
            root.pluginService.savePluginData(root.pluginId, key, value);
    }

    function setStatus(message, isError) {
        root.statusLine = String(message || "");
        root.statusIsError = isError === true;
        if (root.statusIsError)
            ToastService.showError("Oma YouTube DL", root.statusLine);
    }

    function notify(title, body) {
        ToastService.showInfo(String(title || "Oma YouTube DL"), String(body || ""));
    }

    function isWebUrl(value) {
        return Model.isHttpUrl(value);
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
            root.setStatus("Clipboard or drop did not contain a valid http(s) URL.", true);
            return false;
        }
        root.urlDraft = candidate;
        root.activeTab = "search";
        root.setStatus("Link ready — queue it when you are ready.", false);
        return true;
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

    function utf8ByteLength(value) {
        const text = String(value || "");
        let bytes = 0;
        for (let i = 0; i < text.length; i++) {
            const code = text.charCodeAt(i);
            if (code <= 0x7f) {
                bytes += 1;
            } else if (code <= 0x7ff) {
                bytes += 2;
            } else if (code >= 0xd800 && code <= 0xdbff && i + 1 < text.length) {
                const next = text.charCodeAt(i + 1);
                if (next >= 0xdc00 && next <= 0xdfff) {
                    bytes += 4;
                    i++;
                } else {
                    bytes += 3;
                }
            } else {
                bytes += 3;
            }
        }
        return bytes;
    }

    function searchOutputSize() {
        return root.utf8ByteLength(searchStdout.text) + root.utf8ByteLength(searchStderr.text);
    }

    function enforceSearchLimits() {
        if (root.searching && root.searchAbortReason === "" && root.searchOutputSize() > root.searchMaxBytes)
            root.abortSearch("too-large");
    }

    function abortSearch(reason) {
        if (!root.searching || root.searchAbortReason !== "")
            return;
        root.searchAbortReason = String(reason || "cancelled");
        root.searchStopping = true;
        root.searching = false;
        searchTimeout.stop();
        if (searchProc.running)
            searchProc.running = false;
        if (root.searchAbortReason === "timeout") {
            root.searchError = "Search timed out after 30 seconds. Try again.";
            root.setStatus("Search timed out.", true);
        } else if (root.searchAbortReason === "too-large") {
            root.searchError = "Search response exceeded the 1 MiB safety limit and was stopped.";
            root.setStatus("Search rejected: response too large.", true);
        }
    }

    function startSearch() {
        const query = String(root.searchQuery || "").trim();
        if (!query) {
            root.setStatus("Enter a search query first.", true);
            return false;
        }
        if (root.searching || root.searchStopping || searchProc.running)
            return false;
        if (query.length > 250) {
            root.searchError = "Keep searches under 250 characters.";
            root.setStatus(root.searchError, true);
            return false;
        }

        root.searchQuery = query;
        root.searching = true;
        root.searchStopping = false;
        root.searchAbortReason = "";
        root.searchError = "";
        root.searchStdoutFinished = false;
        root.searchStderrFinished = false;
        root.searchProcessExited = false;
        root.searchFinalized = false;
        root.searchExitCode = 0;
        root.setStatus("Searching YouTube for “" + query + "”…", false);
        searchResults.clear();

        const args = ["yt-dlp", "--ignore-config", "--flat-playlist", "--playlist-end", root.maxResults, "-J", "--no-warnings"];
        const cookies = Model.cookiesArgs(root.cookiesBrowser);
        for (let i = 0; i < cookies.length; i++)
            args.push(cookies[i]);
        args.push(Model.searchSpec(query, root.maxResults, root.searchSort));
        searchProc.command = args;
        searchProc.running = true;
        searchTimeout.restart();
        return true;
    }

    function finalizeSearch() {
        if (root.searchFinalized || !root.searchProcessExited || !root.searchStdoutFinished || !root.searchStderrFinished)
            return;
        root.searchFinalized = true;
        root.searching = false;
        root.searchStopping = false;
        searchTimeout.stop();
        if (root.searchAbortReason !== "")
            return;

        if (root.searchExitCode !== 0) {
            const detail = String(searchStderr.text || "").trim().split(/\r?\n/).pop() || "Check that yt-dlp is installed and up to date.";
            root.searchError = "Search failed: " + detail.slice(0, 180);
            root.setStatus(root.searchError, true);
            return;
        }

        const items = Model.parseSearchJson(String(searchStdout.text || ""));
        searchResults.clear();
        for (let i = 0; i < items.length; i++)
            searchResults.append(items[i]);

        if (items.length === 0) {
            root.searchError = "No results returned. Check the network, update yt-dlp, or try another query.";
            root.setStatus("Search returned no results.", false);
        } else {
            root.searchError = "";
            root.setStatus(items.length + " results for “" + root.searchQuery + "”.", false);
        }
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

    function queueDownload(title, url, modeOverride) {
        const cleanUrl = String(url || "").trim();
        if (!root.isWebUrl(cleanUrl)) {
            root.setStatus("Cannot queue this item: it is not a valid http(s) URL.", true);
            return false;
        }

        const mode = modeOverride === "audio" || modeOverride === "video" ? modeOverride : root.downloadMode;
        downloadQueue.append({
            title: String(title || cleanUrl).slice(0, 300),
            url: cleanUrl,
            mode: mode,
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
        return true;
    }

    function startNextDownload() {
        if (root.downloading || root.downloadStopping || downloadProc.running || downloadQueue.count === 0)
            return;
        const job = downloadQueue.get(0);
        downloadQueue.remove(0);
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
            root.activeDetail = text.slice(0, 160);
        } else if (text.indexOf("ERROR") !== -1 || text.indexOf("WARNING") !== -1
                   || text.indexOf("[info]") === 0 || text.indexOf("[youtube]") === 0
                   || text.indexOf("[download]") === 0 || text.indexOf("[Merger]") === 0
                   || text.indexOf("[ExtractAudio]") === 0) {
            root.activeDetail = text.slice(0, 160);
        }
    }

    function finishDownload(success, message) {
        if (!root.downloading)
            return;
        const title = root.activeTitle;
        const url = root.activeUrl;
        const mode = root.activeMode;
        root.downloading = false;
        if (success) {
            root.activePct = 100;
            root.activeDetail = "Download complete.";
            root.addHistory({
                title: title,
                detail: (mode === "audio" ? "Audio" : "Video") + " · complete",
                url: url,
                path: "",
                kind: "download"
            });
            root.setStatus("Download complete: “" + title + "”.", false);
            root.notify("Download complete", title);
        } else {
            root.activeDetail = String(message || root.activeDetail || "Download failed.").slice(0, 180);
            root.setStatus("Download failed: “" + title + "”. " + root.activeDetail, true);
            root.addHistory({
                title: title,
                detail: "Failed · " + root.activeDetail,
                url: url,
                path: "",
                kind: "failed"
            });
        }
        if (downloadQueue.count > 0)
            Qt.callLater(root.startNextDownload);
        else if (success)
            Qt.callLater(() => { if (!root.downloading) root.activePct = 0; });
    }

    function cancelDownloads() {
        downloadQueue.clear();
        if (root.downloading) {
            root.downloading = false;
            root.downloadStopping = true;
            if (downloadProc.running)
                downloadProc.running = false;
            root.activePct = 0;
            root.activeDetail = "Cancelled.";
        }
        root.setStatus("Active download and queued items cancelled.", false);
    }

    function removeQueued(index) {
        if (index >= 0 && index < downloadQueue.count)
            downloadQueue.remove(index);
    }

    function clearQueue() {
        downloadQueue.clear();
        root.setStatus("Queued items cleared.", false);
    }

    function openDownloadFolder() {
        const directory = Model.expandHome(root.downloadDir, root.homeDir);
        folderProc.command = ["sh", "-c", "mkdir -p " + Model.shellQuote(directory) + " && xdg-open " + Model.shellQuote(directory) + " >/dev/null 2>&1"];
        folderProc.running = true;
    }

    function checkDependencies() {
        if (dependencyProc.running)
            dependencyProc.running = false;
        root.dependencySummary = "Checking installed tools…";
        dependencyProc.command = ["sh", "-c", "for tool in yt-dlp ffmpeg mpv socat curl whisper-cli whisper whisper-ctranslate2; do if command -v \"$tool\" >/dev/null 2>&1; then printf '%s: found\\n' \"$tool\"; else printf '%s: missing\\n' \"$tool\"; fi; done"];
        dependencyProc.running = true;
    }

    function playVideo(title, url, thumbnail) {
        const cleanUrl = String(url || "").trim();
        if (!root.isWebUrl(cleanUrl)) {
            root.setStatus("Cannot preview this item: invalid URL.", true);
            return false;
        }
        if (cleanUrl === root.nowUrl && (root.videoActive || root.audioFallback)) {
            root.togglePlayback();
            return true;
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
            return true;
        }

        root.previewGeneration++;
        root.startStreamResolve(cleanUrl);
        return true;
    }

    function startStreamResolve(url) {
        const process = streamResolveComponent.createObject(root, {
            sessionToken: root.previewGeneration
        });
        if (!process) {
            root.resolving = false;
            root.startVideoCache();
            return;
        }
        root.resolveProcess = process;
        process.command = ["yt-dlp", "--ignore-config", "-g", "-f", "22/18/17/36/b[vcodec^=avc1][height<=480]/b[height<=480]/w", "--no-warnings"]
            .concat(Model.cookiesArgs(root.cookiesBrowser), [url]);
        process.running = true;
    }

    function handleResolveDone(sessionToken, output) {
        if (sessionToken !== root.previewGeneration || !root.resolving)
            return;
        root.resolving = false;
        const lines = String(output || "").split("\n");
        let stream = "";
        for (let i = 0; i < lines.length; i++) {
            const candidate = lines[i].trim();
            if (candidate.indexOf("https://") === 0 || candidate.indexOf("http://") === 0) {
                stream = candidate;
                break;
            }
        }
        if (!stream) {
            if (root.mediaPlayerUnavailable || !root.showVideo)
                root.startAudioFallback();
            else
                root.startVideoCache();
            return;
        }
        root.startEmbeddedPlayback(stream, "Playing preview: “" + root.nowTitle + "”.");
    }

    function handleResolveExit(sessionToken, exitCode) {
        if (root.resolveProcess && root.resolveProcess.sessionToken === sessionToken)
            root.resolveProcess = null;
        if (sessionToken === root.previewGeneration && exitCode !== 0 && root.resolving) {
            root.resolving = false;
            root.startVideoCache();
        }
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
            root.setStatus("Preparing embedded preview…", false);
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
            root.previewPlaying = true;
            root.previewPaused = false;
            root.setStatus(String(successStatus || "Playing preview."), false);
        } catch (error) {
            root.videoActive = false;
            root.startAudioFallback();
        }
    }

    function mediaPlayerReady(item) {
        root.player = item;
        root.mediaPlayerUnavailable = false;
        if (root.videoOutputRef)
            item.videoOutput = root.videoOutputRef;
        if (root.pendingEmbeddedSource !== "")
            root.startEmbeddedPlayback(root.pendingEmbeddedSource, root.pendingEmbeddedStatus);
    }

    function mediaPlayerFailed() {
        root.mediaPlayerUnavailable = true;
        root.player = null;
        root.playerError = "Embedded preview is unavailable: install the Qt Multimedia QML module to play video inside DMS.";
        if (root.pendingEmbeddedSource !== "")
            root.startAudioFallback();
    }

    function syncPlaybackState() {
        if (!root.player)
            return;
        root.previewPlaying = root.player.isPlaying || root.player.isPaused;
        root.previewPaused = root.player.isPaused;
    }

    function handleMediaError(message) {
        root.playerError = String(message || "Embedded playback failed.").slice(0, 180);
        if (root.nowUrl && !root.audioFallback) {
            root.videoActive = false;
            root.startAudioFallback();
        }
    }

    function attachVideoOutput(item) {
        root.videoOutputRef = item;
        if (root.player)
            root.player.videoOutput = item;
    }

    function detachVideoOutput() {
        if (root.player && root.player.videoOutput === root.videoOutputRef)
            root.player.videoOutput = null;
        root.videoOutputRef = null;
    }

    function startVideoCache() {
        if (!root.nowUrl)
            return;
        root.previewGeneration++;
        if (root.resolveProcess) {
            const resolve = root.resolveProcess;
            root.resolveProcess = null;
            resolve.running = false;
        }
        if (root.cacheProcess) {
            const oldProcess = root.cacheProcess;
            root.cacheProcess = null;
            oldProcess.running = false;
        }
        root.cachingVideo = true;
        root.cachePct = 0;
        root.cacheDetail = "Downloading a local preview copy…";
        root.cacheFile = Model.cacheFileFor(root.nowId, root.homeDir);
        root.setStatus("Caching a compatible video for in-popout playback…", false);
        const process = previewCacheComponent.createObject(root, {
            sessionToken: root.previewGeneration
        });
        if (!process) {
            root.cachingVideo = false;
            root.startAudioFallback();
            return;
        }
        root.cacheProcess = process;
        process.command = ["bash", "-c", Model.buildCacheScript(root.nowUrl, root.cacheFile, root.cookiesBrowser)];
        process.running = true;
    }

    function handleCacheLine(sessionToken, line) {
        if (sessionToken !== root.previewGeneration || !root.cachingVideo)
            return;
        const text = String(line || "").trim();
        if (!text)
            return;
        const progress = Model.parseProgressLine(text);
        if (progress) {
            root.cachePct = progress.pct;
            root.cacheDetail = text.slice(0, 160);
        } else if (text.indexOf("[info]") === 0 || text.indexOf("[Merger]") === 0 || text.indexOf("ERROR") !== -1) {
            root.cacheDetail = text.slice(0, 160);
        }
    }

    function finishVideoCache(sessionToken, success) {
        if (sessionToken !== root.previewGeneration || !root.cachingVideo)
            return;
        if (root.cacheProcess && root.cacheProcess.sessionToken === sessionToken)
            root.cacheProcess = null;
        root.cachingVideo = false;
        if (success) {
            root.startEmbeddedPlayback(Model.fileUrl(root.cacheFile), "Playing cached preview: “" + root.nowTitle + "”.");
        } else {
            root.cacheDetail = "Video cache failed; trying mpv audio preview.";
            root.startAudioFallback();
        }
    }

    function startAudioFallback() {
        if (!root.nowUrl)
            return;
        root.pendingEmbeddedSource = "";
        root.pendingEmbeddedStatus = "";
        root.resolving = false;
        root.cachingVideo = false;
        root.videoActive = false;
        root.pendingAudioFallbackStart = true;
        root.previewGeneration++;
        if (root.resolveProcess) {
            const resolve = root.resolveProcess;
            root.resolveProcess = null;
            resolve.running = false;
        }
        if (root.cacheProcess) {
            const cache = root.cacheProcess;
            root.cacheProcess = null;
            cache.running = false;
        }
        if (root.previewProcess) {
            const oldProcess = root.previewProcess;
            root.previewProcess = null;
            oldProcess.running = false;
            return;
        }
        root.launchAudioFallback();
    }

    function launchAudioFallback() {
        if (!root.pendingAudioFallbackStart || !root.nowUrl || root.previewProcess)
            return;
        root.pendingAudioFallbackStart = false;
        try {
            if (root.player) {
                root.player.stop();
                root.player.source = "";
            }
        } catch (error) {}
        const process = previewProcessComponent.createObject(root, {
            sessionToken: root.previewGeneration
        });
        if (!process) {
            root.audioFallback = false;
            root.previewPlaying = false;
            root.setStatus("Could not start the mpv preview process.", true);
            return;
        }
        root.previewProcess = process;
        root.audioFallback = true;
        root.previewPaused = false;
        root.previewPlaying = true;
        root.playerError = root.mediaPlayerUnavailable
                ? "Qt Multimedia is unavailable — trying mpv audio preview."
                : "Video stream unavailable — using mpv audio preview.";
        process.command = ["mpv", "--no-video", "--force-window=no", "--no-terminal", "--input-ipc-server=" + root.mpvSocket, "--ytdl-format=bestaudio/best", root.nowUrl];
        process.running = true;
        root.setStatus(root.playerError, false);
    }

    function handleAudioFallbackExited(sessionToken, exitCode) {
        if (root.previewProcess && root.previewProcess.sessionToken === sessionToken)
            root.previewProcess = null;
        if (sessionToken === root.previewGeneration) {
            root.audioFallback = false;
            root.previewPlaying = false;
            root.previewPaused = false;
            if (exitCode !== 0) {
                root.playerError = "mpv audio preview failed. Check that mpv is installed.";
                root.setStatus(root.playerError, true);
            }
        }
        if (root.pendingAudioFallbackStart && !root.previewProcess)
            Qt.callLater(root.launchAudioFallback);
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
        root.pendingAudioFallbackStart = false;
        root.previewGeneration++;
        if (root.resolveProcess) {
            const process = root.resolveProcess;
            root.resolveProcess = null;
            process.running = false;
        }
        if (root.cacheProcess) {
            const process = root.cacheProcess;
            root.cacheProcess = null;
            process.running = false;
        }
        if (root.previewProcess) {
            const process = root.previewProcess;
            root.previewProcess = null;
            root.audioFallback = false;
            process.running = false;
        }
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

    function seek(position) {
        if (root.videoActive && root.player && root.player.duration > 0)
            root.player.position = position;
    }

    function startTranscription(title, url) {
        const cleanUrl = String(url || "").trim();
        if (!root.isWebUrl(cleanUrl)) {
            root.setStatus("Cannot transcribe this item: invalid URL.", true);
            return false;
        }
        if (root.transcribing || root.transcriptionStopping || transcribeProc.running) {
            root.setStatus("A transcription is already running or stopping.", false);
            return false;
        }
        if (root.whisperEngine === "off") {
            root.setStatus("Transcription is disabled. Choose Local or OpenAI in plugin settings.", false);
            return false;
        }

        root.transcribing = true;
        root.transcribePct = 0;
        root.transcribeTitle = String(title || cleanUrl);
        root.transcribeUrl = cleanUrl;
        root.transcribeOutputPath = "";
        root.transcribeDetail = "Preparing transcription…";
        root.activeTab = "downloads";
        root.setStatus("Transcribing “" + root.transcribeTitle + "”.", false);

        const videoId = Model.extractId(cleanUrl);
        const outputId = videoId || ("audio-" + Date.now().toString(36));
        const script = Model.buildTranscribeScript({
            url: cleanUrl,
            id: outputId,
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
        return true;
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
        root.transcriptionStopping = true;
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
            root.addHistory({
                title: root.transcribeTitle,
                detail: "Subtitles · " + (root.whisperEngine === "openai" ? root.whisperApiModel : "Local Whisper"),
                url: root.transcribeUrl,
                path: root.transcribeOutputPath,
                kind: "transcription"
            });
            root.setStatus("Transcription complete: " + root.transcribeDetail, false);
            root.notify("Transcription complete", root.transcribeTitle);
        } else {
            root.setStatus("Transcription failed (exit " + exitCode + "): " + root.transcribeDetail, true);
        }
    }

    function addHistory(entry) {
        recentHistory.insert(0, {
            title: String(entry.title || "Untitled").slice(0, 300),
            detail: String(entry.detail || "").slice(0, 300),
            url: String(entry.url || ""),
            path: String(entry.path || ""),
            kind: String(entry.kind || "download")
        });
        while (recentHistory.count > 30)
            recentHistory.remove(recentHistory.count - 1);
        root.persistHistory();
    }

    function restoreHistory() {
        if (!root.pluginService || !root.pluginId || typeof root.pluginService.loadPluginState !== "function")
            return;
        const saved = root.pluginService.loadPluginState(root.pluginId, "history", []);
        if (!Array.isArray(saved))
            return;
        recentHistory.clear();
        for (let i = 0; i < Math.min(saved.length, 30); i++) {
            const entry = saved[i] || {};
            recentHistory.append({
                title: String(entry.title || "Untitled").slice(0, 300),
                detail: String(entry.detail || "").slice(0, 300),
                url: String(entry.url || ""),
                path: String(entry.path || ""),
                kind: String(entry.kind || "download")
            });
        }
    }

    function persistHistory() {
        if (!root.pluginService || !root.pluginId || typeof root.pluginService.savePluginState !== "function")
            return;
        const entries = [];
        for (let i = 0; i < recentHistory.count; i++) {
            const entry = recentHistory.get(i);
            entries.push({
                title: entry.title,
                detail: entry.detail,
                url: entry.url,
                path: entry.path,
                kind: entry.kind
            });
        }
        root.pluginService.savePluginState(root.pluginId, "history", entries);
    }

    function clearHistory() {
        recentHistory.clear();
        root.persistHistory();
    }

    function openUrl(url) {
        const value = String(url || "");
        if (root.isWebUrl(value))
            Quickshell.execDetached(["xdg-open", value]);
    }

    function formatTime(milliseconds) {
        return Model.fmtTime(milliseconds);
    }

    function cleanup() {
        searchTimeout.stop();
        root.searching = false;
        root.searchStopping = true;
        root.searchAbortReason = "cleanup";
        root.searchFinalized = true;
        root.downloading = false;
        root.downloadStopping = true;
        root.transcribing = false;
        root.transcriptionStopping = true;
        downloadQueue.clear();
        if (searchProc.running)
            searchProc.running = false;
        if (downloadProc.running)
            downloadProc.running = false;
        if (transcribeProc.running)
            transcribeProc.running = false;
        if (dependencyProc.running)
            dependencyProc.running = false;
        if (clipboardProc.running)
            clipboardProc.running = false;
        if (folderProc.running)
            folderProc.running = false;
        if (controlProc.running)
            controlProc.running = false;
        root.downloading = false;
        root.transcribing = false;
        root.searching = false;
        root.stopPlayback();
    }

    ListModel { id: searchResults }
    ListModel { id: downloadQueue }
    ListModel { id: recentHistory }

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
                root.searchStdoutFinished = true;
                root.finalizeSearch();
            }
        }
        stderr: StdioCollector {
            id: searchStderr
            waitForEnd: true
            onDataChanged: root.enforceSearchLimits()
            onStreamFinished: {
                root.searchStderrFinished = true;
                root.finalizeSearch();
            }
        }
        onExited: (exitCode) => {
            root.searchProcessExited = true;
            root.searchExitCode = exitCode;
            searchTimeout.stop();
            root.finalizeSearch();
        }
    }

    Component {
        id: streamResolveComponent
        Process {
            id: streamResolveProcess
            property int sessionToken: 0
            property bool stdoutFinished: false
            property bool stderrFinished: false
            property bool processExited: false
            property int processExitCode: 0

            function finishWhenReady() {
                if (!streamResolveProcess.processExited || !streamResolveProcess.stdoutFinished
                        || !streamResolveProcess.stderrFinished)
                    return;
                root.handleResolveExit(streamResolveProcess.sessionToken, streamResolveProcess.processExitCode);
                Qt.callLater(() => streamResolveProcess.destroy());
            }

            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    streamResolveProcess.stdoutFinished = true;
                    root.handleResolveDone(streamResolveProcess.sessionToken, String(text || ""));
                    streamResolveProcess.finishWhenReady();
                }
            }
            stderr: StdioCollector {
                waitForEnd: true
                onStreamFinished: {
                    streamResolveProcess.stderrFinished = true;
                    streamResolveProcess.finishWhenReady();
                }
            }
            onExited: (exitCode) => {
                streamResolveProcess.processExitCode = exitCode;
                streamResolveProcess.processExited = true;
                streamResolveProcess.finishWhenReady();
            }
        }
    }

    Component {
        id: previewCacheComponent
        Process {
            id: previewCacheProcess
            property int sessionToken: 0
            stdout: SplitParser { onRead: line => root.handleCacheLine(previewCacheProcess.sessionToken, line) }
            stderr: SplitParser { onRead: line => root.handleCacheLine(previewCacheProcess.sessionToken, line) }
            onExited: (exitCode) => {
                root.finishVideoCache(previewCacheProcess.sessionToken, exitCode === 0);
                Qt.callLater(() => previewCacheProcess.destroy());
            }
        }
    }

    Process {
        id: downloadProc
        stdout: SplitParser { onRead: line => root.handleDownloadLine(line) }
        stderr: SplitParser { onRead: line => root.handleDownloadLine(line) }
        onExited: (exitCode) => {
            const wasDownloading = root.downloading;
            root.downloadStopping = false;
            if (wasDownloading)
                root.finishDownload(exitCode === 0, root.activeDetail);
            else if (downloadQueue.count > 0)
                Qt.callLater(root.startNextDownload);
        }
    }

    Process { id: folderProc }
    Process { id: controlProc }

    Component {
        id: previewProcessComponent
        Process {
            id: audioFallbackProcess
            property int sessionToken: 0
            onExited: (exitCode) => {
                root.handleAudioFallbackExited(audioFallbackProcess.sessionToken, exitCode);
                audioFallbackProcess.destroy();
            }
        }
    }

    Process {
        id: transcribeProc
        stdout: SplitParser { onRead: line => root.handleTranscribeLine(line) }
        stderr: SplitParser { onRead: line => root.handleTranscribeLine(line) }
        onExited: (exitCode) => {
            root.transcriptionStopping = false;
            root.handleTranscriptionExit(exitCode);
        }
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

    Component.onCompleted: root.restoreHistory()
    onPluginServiceChanged: root.restoreHistory()
    onPluginIdChanged: root.restoreHistory()
    Component.onDestruction: root.cleanup()
}
