# Oma YouTube DL — Dank Material Shell port

A DMS bar widget rebuilt from [Aznit11/omayoutube-dl](https://github.com/Aznit11/omayoutube-dl), following the `PluginComponent` / `PopoutComponent` architecture used by Dank Material Shell plugins such as [hthienloc/dms-plugins](https://github.com/hthienloc/dms-plugins).

Search YouTube, preview videos inside the popout when a progressive stream is available, queue video/audio downloads and playlists, and optionally create subtitles with native YouTube captions or Whisper.

## Requirements

- Dank Material Shell **1.6.0 or newer** — verified against the **v1.6.2** stable release and the current **1.7** pre-release (`master`). See [Compatibility](#compatibility).
- `yt-dlp`
- `ffmpeg`
- Qt Multimedia's QML module is optional; it enables embedded playback. If it is missing, the plugin still loads and tries the optional `mpv` audio-preview fallback instead.
- `mpv` and `socat` are optional; they provide the audio-preview fallback and pause control when the embedded stream cannot be played.
- Local Whisper transcription is optional and needs `whisper-cli`, `whisper`, or `whisper-ctranslate2` plus a compatible model.
- OpenAI transcription is optional and needs `curl` and the configured API-key environment variable.

Check the required tools with:

```sh
command -v yt-dlp ffmpeg
```

On Arch, for example:

```sh
sudo pacman -S yt-dlp ffmpeg
# Optional: embedded video playback and mpv fallback controls
sudo pacman -S qt6-multimedia mpv socat
```

Keep `yt-dlp` current; YouTube frequently changes its player and anti-bot checks.

## Install

Clone the repository into DMS's plugin directory (the directory must contain `plugin.json` directly):

```sh
mkdir -p ~/.config/DankMaterialShell/plugins
git clone https://github.com/TR4842/omayoutube-dl-dms.git ~/.config/DankMaterialShell/plugins/omaYoutubeDl
```

Then:

1. Open **DMS Settings → Plugins** and scan for plugins (or run `dms ipc call plugin-scan scan`).
2. Open **Oma YouTube DL** and switch the plugin **on**. DMS only lists a plugin in the bar widget picker after it has been enabled here.
3. Go to **Settings → Bar → Widgets** and add **Oma YouTube DL** to the left, center, or right section.

Restart DMS if the new widget does not appear immediately:

```sh
dms restart
```

### Update

```sh
git -C ~/.config/DankMaterialShell/plugins/omaYoutubeDl pull
dms ipc call plugins reload omaYoutubeDl
```

For local development, run the same `reload` command after editing any file in the plugin directory.

## Compatibility

DMS enables a plugin by compiling its main QML component with `Qt.createComponent()`. Any compile error — a syntax error, an import that is not installed, or a property that your DMS version's widgets do not define — makes the enable toggle snap back off, and a plugin that is not enabled never appears in the bar widget picker.

Because of that, this plugin deliberately sticks to the widget API that exists on the **1.6.x** stable release and feature-detects anything newer:

| API | DMS 1.6.2 | DMS 1.7 (master) | How the plugin handles it |
|---|---|---|---|
| `DankButton.busy` | missing | present | Not used; the Search button swaps its icon while a search runs. |
| `Theme.buttonHeightXS/S/M` | missing | present | Read through `root.buttonHeight*` fallbacks (32 / 40 / 48). |
| `PluginComponent.textSize` | missing | present | Read through `root.pillTextSize`, falls back to `Theme.fontSizeSmall`. |
| `PluginComponent.interactionActive` | missing | present | Read through `root.popoutInteractionActive`. |
| `ToastService.showSuccess` | missing | missing | Never existed; the plugin uses `showInfo`. |
| `QtMultimedia` QML module | optional | optional | Isolated in `OmaYoutubeMediaPlayer.qml` behind a `Loader`, so a missing module only disables embedded preview. |

`tests/model.test.js` asserts that none of the 1.7-only properties are assigned directly, so a future edit cannot silently break 1.6.x again.

## Troubleshooting

**The toggle in Settings → Plugins will not stay on.**
DMS prints the compile error in red directly under the plugin row on that page. It is also in the shell log:

```sh
dms kill; dms run 2>&1 | grep -i -A2 "omaYoutubeDl\|component error"
```

A line like `Cannot assign to non-existent property "xyz"` means your DMS build's widgets differ from the ones this plugin was verified against — please open an issue and paste that line together with your DMS version (shown in **Settings → About**, or `dms version`).

**The plugin is enabled but not in the bar widget list.**
Open **Settings → Bar → Widgets** and add it manually; enabling a plugin does not place it in the bar automatically. If it is still missing, run `dms ipc call plugins reload omaYoutubeDl` or `dms restart`.

**Searches return nothing or fail with a non-zero exit code.**
Update `yt-dlp` first (`yt-dlp -U` or your package manager); YouTube changes its player and anti-bot checks frequently. If YouTube asks you to sign in, set a browser in **Cookies passthrough** in the plugin settings.

**Preview shows "QtMultimedia unavailable".**
Install your distribution's Qt 6 Multimedia QML package (for example `qt6-multimedia` on Arch) and restart DMS. Without it the plugin falls back to an `mpv` audio preview if `mpv` is installed.

**Nothing happens when I press play / pause on the audio preview.**
Pause control for the `mpv` fallback needs `socat` to talk to mpv's IPC socket.

## Use

- **Click the bar pill** to open the popout.
- **Search** with a YouTube query; the filter supports relevance, newest, most viewed, short, and long results.
- Select **Video** or **Audio** and click the download action on a result.
- Paste a direct media URL or playlist URL in the URL field and click **Queue**.
- Click a result's **play** action for an embedded preview. If yt-dlp cannot resolve a progressive stream, the plugin caches a compatible H.264 MP4 for local in-popout playback; if that fails, it tries an `mpv` audio preview.
- The **Downloads** tab shows the active progress, waiting queue, recent completions/failures, and a shortcut to the download folder.
- Click the pill with the **right mouse button** to paste a URL from the clipboard. You can also drop a URL onto the pill.
- The subtitles action on a result or preview runs Whisper. Configure the engine in **DMS Settings → Plugins → Oma YouTube DL**.

The queue and recent-history list are held in memory for the current shell session; downloaded files and subtitle outputs remain on disk.

## Settings

The DMS settings page includes:

- Download directory, default video/audio mode, max video quality, output container, and extracted audio format.
- Single-video vs full-playlist downloads.
- Search result count/filter and optional browser-cookie passthrough to yt-dlp.
- Preferred audio language/dub, native caption languages, and optional subtitle embedding.
- Embedded video preview toggle.
- Whisper engine, language, model, optional custom local command, OpenAI model, and API-key environment variable name.

**Privacy:** browser cookies are read locally and passed to yt-dlp. Local Whisper runs on your machine. OpenAI mode uploads the extracted audio to `https://api.openai.com/v1/audio/transcriptions`; use Local mode if you do not want audio to leave your device. The API key itself is not stored in plugin settings—only the name of the environment variable is.

Custom Whisper command templates run through `bash` and are intentionally powerful. Only use a command you trust. Available placeholders are `{wav}`, `{input}`, `{dir}`, and `{lang}`.

## Optional: build a Vulkan Whisper CLI

The included `setup-whisper-vulkan.sh` builds a user-local `whisper-cli` with Vulkan support and reuses GGML models under `~/.local/share/voxtype/models/` when present:

```sh
~/.config/DankMaterialShell/plugins/omaYoutubeDl/setup-whisper-vulkan.sh
```

It requires `git`, CMake, Ninja, Vulkan headers/runtime, and `glslc`; it does not use `sudo`. The script builds upstream whisper.cpp from its current default branch, so review it before running if you want a pinned/reproducible build.

## IPC

The widget exposes DMS IPC commands:

```sh
dms ipc call omaYoutubeDl toggle
dms ipc call omaYoutubeDl open
dms ipc call omaYoutubeDl close
dms ipc call omaYoutubeDl search "ambient music"
dms ipc call omaYoutubeDl download "https://www.youtube.com/watch?v=VIDEO_ID"
dms ipc call omaYoutubeDl play "https://www.youtube.com/watch?v=VIDEO_ID"
dms ipc call omaYoutubeDl transcribe "https://www.youtube.com/watch?v=VIDEO_ID"
```

## Development / checks

Run the pure-JavaScript helper tests with Node.js:

```sh
node tests/model.test.js
```

The helper module keeps yt-dlp argv construction and shell quoting out of the QML UI. Search output is capped at 1 MiB, limited to 50 parsed entries, and has a 30-second process deadline. The test file also contains the DMS 1.6.x compatibility guards described under [Compatibility](#compatibility).

To type-check the QML against a specific DMS release without a running shell, clone DMS (with its `dank-qml-common` submodule) and point `qmllint` at a directory containing a `qs` symlink to its `quickshell/` folder:

```sh
git clone --depth 1 --branch v1.6.2 https://github.com/AvengeMedia/DankMaterialShell.git /tmp/dms
git -C /tmp/dms submodule update --init --depth 1 dank-qml-common
mkdir -p /tmp/imp && ln -sfn /tmp/dms/quickshell /tmp/imp/qs
qmllint -I /tmp/imp --unqualified disable --compiler disable OmaYoutubeWidget.qml 2>&1 | grep missing-property
```

Quickshell resolves `qs.*` imports by directory, whereas `qmllint` needs a `qmldir` per module; generate simple ones listing each `*.qml` file (and `singleton` for files that start with `pragma Singleton`) in `qs/Common`, `qs/Widgets`, `qs/Services`, `qs/Modules/Plugins`, and `qs/DankCommon/**`. Quickshell's own types (`Process`, `IpcHandler`, …) stay unresolved, which is expected — the useful output is any `missing-property` line pointing at a Dank widget.

## Attribution and license

This DMS port is maintained in [TR4842/omayoutube-dl-dms](https://github.com/TR4842/omayoutube-dl-dms) and is based on the MIT-licensed [OmaYoutube-dl](https://github.com/Aznit11/omayoutube-dl) by Aznit11. It retains the upstream yt-dlp command builders, search parsing, and optional Whisper workflow, and adds the Dank Material Shell manifest, bar pill/popout, PluginService-backed settings, and IPC interface. Both the port copyright and upstream MIT notice are retained in [LICENSE](./LICENSE).

The optional setup script builds the upstream `whisper.cpp` project and remains subject to that project's license.
