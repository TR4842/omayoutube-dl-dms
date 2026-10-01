# Oma YouTube DL

A DankMaterialShell bar widget for searching YouTube, previewing media, managing `yt-dlp` downloads, and creating subtitle files. It is a standalone DMS plugin built with the documented `PluginComponent` / `PopoutComponent` and `PluginSettings` APIs.

- [DMS plugin overview](https://danklinux.com/docs/dankmaterialshell/plugins-overview)
- [DMS plugin development guide](https://danklinux.com/docs/dankmaterialshell/plugin-development)

## Features

- Search YouTube through `yt-dlp`, with relevance, newest, view-count, short, and long filters.
- Queue a search result or a pasted video / playlist URL for video or audio-only downloads.
- Track download progress, cancel the active download, remove queued items, and open the output folder.
- Preview a compatible stream inside the popout. If the stream cannot play, the plugin tries a cached MP4 and then an optional `mpv` audio fallback.
- Fetch native YouTube captions as sidecar files or embed them in video downloads.
- Create subtitles with local Whisper or the OpenAI transcription API.
- Paste a URL from the clipboard with a right-click on the bar pill, or drop an HTTP(S) URL onto it.
- Invoke search, download, playback, and transcription through DMS IPC.
- Save recent activity with DMS's per-plugin state API; the download queue is kept for the current shell session.

## Requirements

- DankMaterialShell **1.6.0 or newer**
- `yt-dlp` and `ffmpeg` (required)
- `bash` (used to run safely quoted yt-dlp / transcription scripts)

Optional features:

- Qt Multimedia's QML module enables embedded video playback. Without it, the plugin still loads and can try the `mpv` audio-preview fallback.
- `mpv` enables the audio fallback; `socat` enables pause / resume for that fallback.
- A local Whisper CLI (`whisper-cli`, `whisper`, or `whisper-ctranslate2`) and a compatible model enable private, on-device transcription.
- `curl` is required only for OpenAI transcription.

Check required dependencies with:

```sh
command -v yt-dlp ffmpeg
```

For Arch Linux, for example:

```sh
sudo pacman -S yt-dlp ffmpeg
# Optional: embedded media and mpv controls
sudo pacman -S qt6-multimedia mpv socat
```

Keep `yt-dlp` up to date; YouTube frequently changes its player and anti-bot checks.

## Install

Install the repository as a plugin directory (it must contain `plugin.json` directly):

```sh
mkdir -p ~/.config/DankMaterialShell/plugins
git clone https://github.com/TR4842/omayoutube-dl-dms.git \
  ~/.config/DankMaterialShell/plugins/omaYoutubeDl
```

Then:

1. Open **Settings → Plugins** and click **Scan for Plugins**.
2. Enable **Oma YouTube DL**.
3. Open **Settings → Bar → Widgets** and add it to the left, center, or right section.
4. Restart DMS if it does not appear: `dms restart`.

To update an existing clone:

```sh
git -C ~/.config/DankMaterialShell/plugins/omaYoutubeDl pull
dms ipc call plugins reload omaYoutubeDl
```

## Use

- Click the **YT** bar pill to open the popout.
- Search for a video and use the result actions to preview, queue a download, or create subtitles.
- Choose the default download type from **Video** / **Audio** in the Search tab.
- Paste a video or playlist URL in the URL field and choose **Queue URL**. Playlist behavior is configurable in settings.
- Use the **Downloads** tab to monitor work, cancel the active item, manage the queue, open the destination folder, and revisit recent activity.
- Right-click the bar pill to read a URL from the clipboard. Dropping an HTTP(S) URL onto the pill also fills the URL field.
- Preview playback controls are best-effort because available formats and codec support depend on the source and installed Qt Multimedia / mpv packages.

## Settings

The DMS plugin settings page lets you configure:

- Download directory, default video/audio mode, maximum video quality, output container, audio format, and playlist handling.
- Search count, default sort filter, optional browser-cookie passthrough, and preferred audio track.
- Native caption languages, caption embedding, and whether to show the embedded video preview surface.
- Whisper engine, language, local model / custom command, OpenAI model, and the environment variable name that supplies the API key.

### Privacy and command execution

Browser cookies are read locally and passed to `yt-dlp`. Local Whisper processes audio on your machine. OpenAI mode uploads the extracted audio to `https://api.openai.com/v1/audio/transcriptions`; use Local mode if the audio must stay on-device. The API key itself is not saved in plugin settings—only its environment variable name is stored.

A custom Whisper command template runs through `bash` with your user permissions. Available placeholders are `{wav}`, `{input}`, `{dir}`, and `{lang}`. Only enter a command you trust. DMS plugins also run with the permissions of the desktop session, so review the source before installing.

## DMS plugin structure

The manifest declares a `widget` plugin. `OmaYoutubeWidget.qml` is the `PluginComponent` entry point, `OmaYoutubePanel.qml` supplies its `PopoutComponent`, and `OmaYoutubeSettings.qml` uses DMS's `PluginSettings` and setting controls. The plugin host injects `pluginId`, `pluginService`, and `pluginData`; the runtime controller uses the injected service for settings and plugin state. `OmaYoutubeMediaPlayer.qml` is isolated behind a `Loader` so an absent optional Qt Multimedia module cannot prevent activation.

The manifest declares `settings_read`, `settings_write`, `process`, and `network` permissions and lists `yt-dlp` / `ffmpeg` as dependencies. The panel has an **Optional tools → Check** action for the optional playback and transcription tools.

## IPC

```sh
dms ipc call omaYoutubeDl toggle
dms ipc call omaYoutubeDl open
dms ipc call omaYoutubeDl close
dms ipc call omaYoutubeDl search "ambient music"
dms ipc call omaYoutubeDl download "https://www.youtube.com/watch?v=VIDEO_ID"
dms ipc call omaYoutubeDl play "https://www.youtube.com/watch?v=VIDEO_ID"
dms ipc call omaYoutubeDl transcribe "https://www.youtube.com/watch?v=VIDEO_ID"
```

## Development and checks

For IDE completion and live testing, follow the [DMS plugin development guide](https://danklinux.com/docs/dankmaterialshell/plugin-development#development-environment). Symlink this repository into `~/.config/DankMaterialShell/plugins/omaYoutubeDl`, then reload after edits:

```sh
dms ipc call plugins reload omaYoutubeDl
```

Run the dependency-free helper and manifest checks with Node.js:

```sh
node tests/model.test.js
jq -e . plugin.json >/dev/null
```

The tests cover search parsing, URL validation, command construction and quoting, generated shell syntax, manifest paths / permissions, and the separation of optional Qt Multimedia from the main plugin component. A full QML runtime check requires a DMS / Quickshell development environment.

## Optional: build a Vulkan Whisper CLI

`setup-whisper-vulkan.sh` builds a user-local `whisper-cli` with Vulkan support and reuses GGML models under `~/.local/share/voxtype/models/` when available:

```sh
./setup-whisper-vulkan.sh
```

It does not use `sudo`; it requires Git, CMake, Ninja, Vulkan headers / runtime, and `glslc`. The script clones the current upstream whisper.cpp default branch rather than a pinned revision, so review it before running if reproducibility matters.

## Attribution and license

This DMS plugin is maintained in [TR4842/omayoutube-dl-dms](https://github.com/TR4842/omayoutube-dl-dms) and is based on the MIT-licensed [OmaYoutube-dl](https://github.com/Aznit11/omayoutube-dl) by Aznit11. See [LICENSE](./LICENSE) for the license and upstream notice.
