const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const repoRoot = path.join(__dirname, "..");
const read = name => fs.readFileSync(path.join(repoRoot, name), "utf8");
const source = read("Model.js");
const widgetQml = read("OmaYoutubeWidget.qml");
const controllerQml = read("OmaYoutubeController.qml");
const panelQml = read("OmaYoutubePanel.qml");
const settingsQml = read("OmaYoutubeSettings.qml");
const mediaPlayerQml = read("OmaYoutubeMediaPlayer.qml");
const manifest = JSON.parse(read("plugin.json"));
const allQml = [widgetQml, controllerQml, panelQml, settingsQml, mediaPlayerQml].join("\n");

// DMS manifest and documented widget/settings component structure.
for (const key of ["id", "name", "description", "version", "author", "type", "component"]) {
  assert.ok(manifest[key], `plugin.json must define ${key}`);
}
assert.equal(manifest.type, "widget");
assert.ok(manifest.capabilities.includes("dankbar-widget"));
assert.ok(manifest.permissions.includes("settings_read"));
assert.ok(manifest.permissions.includes("settings_write"));
assert.ok(manifest.permissions.includes("process"));
assert.ok(manifest.permissions.includes("network"));
assert.ok(manifest.dependencies.includes("yt-dlp"));
assert.ok(manifest.dependencies.includes("ffmpeg"));
for (const key of ["component", "settings"]) {
  assert.ok(manifest[key].startsWith("./") && !manifest[key].includes(".."), `${key} must be a local plugin file`);
  assert.ok(fs.existsSync(path.join(repoRoot, manifest[key].slice(2))), `${manifest[key]} must exist`);
}
assert.match(widgetQml, /PluginComponent\s*\{/);
assert.match(widgetQml, /layerNamespacePlugin:\s*"oma-youtube-dl"/);
assert.match(panelQml, /PopoutComponent\s*\{/);
assert.match(settingsQml, /PluginSettings\s*\{/);
assert.match(settingsQml, /pluginId:\s*"omaYoutubeDl"/);
assert.doesNotMatch(widgetQml, /^\s*pluginId:\s*"omaYoutubeDl"\s*$/m,
  "the plugin host should inject PluginComponent.pluginId from the manifest");

// Qt Multimedia is optional: its import must never enter the main component,
// controller, popout, or settings component.
assert.doesNotMatch([widgetQml, controllerQml, panelQml, settingsQml].join("\n"), /^import QtMultimedia\s*$/m,
  "the main plugin path must not require QtMultimedia");
assert.match(widgetQml, /source:\s*Qt\.resolvedUrl\("\.\/OmaYoutubeMediaPlayer\.qml"\)/,
  "embedded playback should be isolated behind a Loader");
assert.match(mediaPlayerQml, /^import QtMultimedia\s*$/m,
  "the optional media helper must declare its QtMultimedia dependency");

// Avoid properties that are absent from the documented DMS 1.6 API. Assigning
// one of these to a DMS widget can prevent PluginService from loading it.
assert.doesNotMatch(allQml, /^\s*(?:busy|textSize|interactionActive)\s*:/m);
assert.doesNotMatch(allQml, /Theme\.buttonHeight(?:XS|S|M)\b/);
assert.doesNotMatch(allQml, /root\.(?:textSize|interactionActive)\b/);
assert.doesNotMatch(allQml, /ToastService\.showSuccess/);
assert.match(controllerQml, /onExited:\s*\(exitCode\)\s*=>\s*\{\s*streamResolveProcess\.processExitCode = exitCode;/,
  "the dynamic resolver exit callback should qualify process properties explicitly");
assert.match(controllerQml, /streamResolveProcess\.processExited = true;\s*streamResolveProcess\.finishWhenReady\(\);/);
assert.match(controllerQml, /audioFallbackProcess\.sessionToken, exitCode/,
  "the audio fallback exit callback should read its token from its process instance");

const Model = {};
vm.createContext(Model);
vm.runInContext(source, Model, { filename: "Model.js" });

assert.equal(Model.isHttpUrl("https://www.youtube.com/watch?v=dQw4w9WgXcQ"), true);
assert.equal(Model.isHttpUrl("http://example.test/path?q=a&x=b"), true);
assert.equal(Model.isHttpUrl("file:///tmp/video.mp4"), false);
assert.equal(Model.isHttpUrl("http://?no-host"), false);
assert.equal(Model.isHttpUrl("https://bad host.test/video"), false);
assert.equal(Model.isHttpUrl("https://example.test/\"quoted\""), false);
assert.equal(Model.utf8ByteLength("Aé😀"), 7);
assert.equal(Model.expandHome("~/Videos/file.mp4", "/home/test"), "/home/test/Videos/file.mp4");
assert.equal(Model.expandHome("~other/file", "/home/test"), "~other/file");
assert.equal(Model.fileUrl("/tmp/Oma YouTube#1.mp4"), "file:///tmp/Oma%20YouTube%231.mp4");
assert.equal(Model.cacheFileFor("../../unsafe", "/home/test"), "/home/test/.cache/omayoutube-dl/watch-video.mp4");
assert.equal(Model.isPlaylistUrl("https://youtube.com/watch?v=abc&list=PL123"), true);
assert.equal(Model.isPlaylistUrl("https://youtube.com/watch?v=abc&notlist=PL123"), false);
assert.equal(Model.extractId("https://youtu.be/dQw4w9WgXcQ"), "dQw4w9WgXcQ");
assert.equal(Model.extractId("https://example.test/?v=" + "x".repeat(100)), "");

const parsed = Model.parseSearchJson(JSON.stringify({
  entries: [
    { id: "dQw4w9WgXcQ", title: "Example", channel: "Channel", duration: 212 },
    { id: "bad/id", title: "Rejected" },
    { id: "a_b-123", title: "Short" }
  ]
}));
assert.equal(parsed.length, 2, "only safe video IDs should be accepted");
assert.equal(parsed[0].url, "https://www.youtube.com/watch?v=dQw4w9WgXcQ");
assert.equal(parsed[0].duration, "3:32");
assert.equal(parsed[1].thumb, "https://i.ytimg.com/vi/a_b-123/mqdefault.jpg");
assert.deepEqual(Array.from(Model.parseSearchJson("x")), []);
assert.deepEqual(Array.from(Model.parseSearchJson("x".repeat(Model.SEARCH_MAX_BYTES + 1))), []);
assert.deepEqual(Array.from(Model.parseSearchJson("😀".repeat(262145))), [], "the JSON cap is measured in UTF-8 bytes");

assert.equal(Model.searchSpec("hello world", 10, "relevance"), "ytsearch10:hello world");
assert.equal(Model.searchSpec("cats & dogs", 10, "date"), "https://www.youtube.com/results?search_query=cats%20%26%20dogs&sp=CAI%3D");
assert.equal(Model.searchSpec("x", 999, "relevance"), "ytsearch50:x", "search result counts should be capped");
assert.deepEqual(Array.from(Model.cookiesArgs("not-a-browser")), []);
assert.deepEqual(Array.from(Model.cookiesArgs("firefox")), ["--cookies-from-browser", "firefox"]);

const downloadArgs = Array.from(Model.buildDownloadCommand({
  url: "https://example.test/video?id=1&x=2",
  mode: "video",
  quality: "720",
  audioFormat: "mp3",
  videoFormat: "mp4",
  audioLang: "original",
  subLangs: "off",
  embedSubs: false,
  outDir: "/tmp/Oma YouTube",
  playlist: "single",
  home: "/home/test"
}));
assert.equal(downloadArgs[0], "yt-dlp");
assert.ok(downloadArgs.includes("--ignore-config"));
assert.ok(downloadArgs.includes("--no-playlist"));
assert.ok(downloadArgs.includes("--"), "URLs should follow an option terminator");
assert.ok(downloadArgs.includes("https://example.test/video?id=1&x=2"));
assert.ok(downloadArgs.includes("bv*[height<=720]+ba/b[height<=720]"));

const unsafeOptions = Array.from(Model.buildDownloadCommand({
  url: "https://example.test/video",
  mode: "video",
  quality: "720",
  videoFormat: "mp4; touch /tmp/not-run",
  audioFormat: "--exec",
  audioLang: "unknown",
  subLangs: "--exec",
  outDir: "/tmp/out",
  home: "/home/test"
}));
assert.ok(unsafeOptions.includes("--remux-video"));
assert.ok(unsafeOptions.includes("mp4"), "unsupported containers should fall back to mp4");
assert.ok(!unsafeOptions.includes("mp4; touch /tmp/not-run"));
assert.ok(unsafeOptions.includes("--"));
assert.ok(!unsafeOptions.includes("--write-subs"), "unsupported subtitle filters should be ignored");

const quoted = Model.shellQuote("a'b; $(touch /tmp/pwned)");
assert.equal(quoted, "'a'\\''b; $(touch /tmp/pwned)'", "shell args must remain single-quoted");

const transcribeScript = Model.buildTranscribeScript({
  url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  outDir: "/tmp/out",
  engine: "local",
  localCmd: "auto",
  lang: "../../bad",
  model: "medium",
  cacheDir: "/tmp/cache",
  home: "/home/test"
});
assert.ok(transcribeScript.includes("--ignore-config"));
assert.ok(transcribeScript.includes("'auto'"), "invalid language settings should fall back to auto");
assert.ok(transcribeScript.includes("dQw4w9WgXcQ"));
assert.ok(transcribeScript.includes("'--'"), "transcription downloads should terminate yt-dlp options before the URL");

function assertBashSyntax(script, label) {
  const result = spawnSync("bash", ["-n"], { input: script, encoding: "utf8" });
  assert.equal(result.status, 0, `${label} should be valid bash: ${result.stderr}`);
}

assertBashSyntax(Model.buildDownloadScript({
  url: "https://example.test/watch?v=x&name=a'b",
  mode: "video",
  quality: "720",
  audioFormat: "mp3",
  videoFormat: "mp4",
  audioLang: "original",
  subLangs: "off",
  embedSubs: false,
  outDir: "/tmp/Oma YouTube",
  playlist: "single",
  home: "/home/test"
}), "download script");
assertBashSyntax(transcribeScript, "local transcription script");
assertBashSyntax(Model.buildCacheScript(
  "https://example.test/video?id=x&name=a'b",
  "/tmp/cache/watch-video.mp4",
  "firefox"
), "preview-cache script");
assertBashSyntax(Model.buildTranscribeScript({
  url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  outDir: "/tmp/out",
  engine: "openai",
  lang: "en",
  model: "small",
  apiModel: "whisper-1",
  keyEnv: "OPENAI_API_KEY",
  cacheDir: "/tmp/cache",
  home: "/home/test"
}), "OpenAI transcription script");

console.log("Manifest, DMS component structure, Model.js, and optional-media checks passed.");
