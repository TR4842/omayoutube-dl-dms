const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const repoRoot = path.join(__dirname, "..");
const source = fs.readFileSync(path.join(repoRoot, "Model.js"), "utf8");
const widgetQml = fs.readFileSync(path.join(repoRoot, "OmaYoutubeWidget.qml"), "utf8");
const mediaPlayerQml = fs.readFileSync(path.join(repoRoot, "OmaYoutubeMediaPlayer.qml"), "utf8");

assert.doesNotMatch(widgetQml, /^import QtMultimedia\s*$/m,
  "the main plugin component must not depend on optional QtMultimedia");
assert.match(widgetQml, /source:\s*Qt\.resolvedUrl\("\.\/OmaYoutubeMediaPlayer\.qml"\)/,
  "embedded playback should be loaded separately so the plugin can enable without QtMultimedia");
assert.match(mediaPlayerQml, /^import QtMultimedia\s*$/m,
  "the isolated media helper should declare the QtMultimedia dependency it uses");

const Model = {};
vm.createContext(Model);
vm.runInContext(source, Model, { filename: "Model.js" });

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
assert.ok(downloadArgs.includes("https://example.test/video?id=1&x=2"));
assert.ok(downloadArgs.includes("bv*[height<=720]+ba/b[height<=720]"));

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

console.log("Model.js and optional-media loading checks passed.");
