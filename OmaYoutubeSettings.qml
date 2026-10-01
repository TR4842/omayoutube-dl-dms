import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// PluginSettings and its setting controls load/save values through DMS's
// PluginService. The widget reads the same keys from its injected pluginData.
PluginSettings {
    id: root
    pluginId: "omaYoutubeDl"

    StyledText {
        width: parent.width
        text: "Oma YouTube DL"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
    }

    StyledText {
        width: parent.width
        text: "Configure yt-dlp downloads, YouTube search, previews, and optional subtitles. Changes save automatically."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        text: "Downloads"
        color: Theme.primary
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
    }

    StringSetting {
        settingKey: "downloadDir"
        label: "Download folder"
        description: "Use an absolute path or a path beginning with ~/"
        placeholder: Quickshell.env("HOME") + "/Videos/Omayoutube"
        defaultValue: Quickshell.env("HOME") + "/Videos/Omayoutube"
    }

    SelectionSetting {
        settingKey: "dlMode"
        label: "Default download type"
        description: "The Search panel also has quick Video and Audio buttons."
        options: [
            { label: "Video", value: "video" },
            { label: "Audio only", value: "audio" }
        ]
        defaultValue: "video"
    }

    SelectionSetting {
        settingKey: "quality"
        label: "Maximum video quality"
        options: [
            { label: "Best available", value: "best" },
            { label: "4K · 2160p", value: "2160" },
            { label: "1440p", value: "1440" },
            { label: "1080p", value: "1080" },
            { label: "720p", value: "720" },
            { label: "480p", value: "480" },
            { label: "360p", value: "360" }
        ]
        defaultValue: "1080"
    }

    SelectionSetting {
        settingKey: "videoFormat"
        label: "Video container"
        options: [
            { label: "MP4", value: "mp4" },
            { label: "MKV", value: "mkv" },
            { label: "WebM", value: "webm" },
            { label: "Keep source container", value: "best" }
        ]
        defaultValue: "mp4"
    }

    SelectionSetting {
        settingKey: "audioFormat"
        label: "Extracted audio format"
        options: [
            { label: "MP3", value: "mp3" },
            { label: "M4A", value: "m4a" },
            { label: "Opus", value: "opus" },
            { label: "FLAC", value: "flac" },
            { label: "WAV", value: "wav" }
        ]
        defaultValue: "mp3"
    }

    SelectionSetting {
        settingKey: "playlistMode"
        label: "Playlist handling"
        description: "Choose whether a playlist URL downloads one item or the full playlist."
        options: [
            { label: "Single video only", value: "single" },
            { label: "Download full playlist", value: "playlist" }
        ]
        defaultValue: "single"
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outlineVariant
        opacity: 0.45
    }

    StyledText {
        width: parent.width
        text: "Search and source options"
        color: Theme.primary
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
    }

    SelectionSetting {
        settingKey: "maxResults"
        label: "Results per search"
        options: [
            { label: "5 results", value: "5" },
            { label: "10 results", value: "10" },
            { label: "15 results", value: "15" }
        ]
        defaultValue: "10"
    }

    SelectionSetting {
        settingKey: "searchSort"
        label: "Default search filter"
        options: [
            { label: "Relevance", value: "relevance" },
            { label: "Newest first", value: "date" },
            { label: "Most viewed", value: "views" },
            { label: "Short videos · under 4 min", value: "short" },
            { label: "Long videos · over 20 min", value: "long" }
        ]
        defaultValue: "relevance"
    }

    SelectionSetting {
        settingKey: "cookiesBrowser"
        label: "YouTube browser cookies"
        description: "Use your local browser cookie store if YouTube asks you to sign in. Cookies stay on this machine and are passed directly to yt-dlp."
        options: [
            { label: "Off", value: "off" },
            { label: "Chromium", value: "chromium" },
            { label: "Chrome", value: "chrome" },
            { label: "Firefox", value: "firefox" },
            { label: "Brave", value: "brave" },
            { label: "Vivaldi", value: "vivaldi" },
            { label: "Edge", value: "edge" },
            { label: "Opera", value: "opera" }
        ]
        defaultValue: "off"
    }

    SelectionSetting {
        settingKey: "audioLang"
        label: "Preferred YouTube audio track"
        description: "A requested dub falls back to the best available track. Multiple tracks are saved in MKV."
        options: [
            { label: "Original / best", value: "original" },
            { label: "Portuguese dub, then original", value: "pt" },
            { label: "Original + Portuguese", value: "original+pt" },
            { label: "Portuguese + English", value: "pt+en" }
        ]
        defaultValue: "original"
    }

    SelectionSetting {
        settingKey: "subLangs"
        label: "Native YouTube captions"
        description: "Fetches creator captions or YouTube auto-captions; this is separate from Whisper transcription."
        options: [
            { label: "Off", value: "off" },
            { label: "Portuguese", value: "pt,pt-BR,pt-PT" },
            { label: "Portuguese + English", value: "pt,pt-BR,pt-PT,en" },
            { label: "All available languages", value: "all" }
        ]
        defaultValue: "off"
    }

    ToggleSetting {
        settingKey: "embedSubs"
        label: "Embed native captions in video"
        description: "Mux captions into MKV instead of writing sidecar subtitle files."
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showVideo"
        label: "Show video preview surface"
        description: "Disable the in-popout video area if you only need audio-style preview controls."
        defaultValue: true
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outlineVariant
        opacity: 0.45
    }

    StyledText {
        width: parent.width
        text: "Whisper transcription"
        color: Theme.primary
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
    }

    SelectionSetting {
        settingKey: "whisperEngine"
        label: "Transcription engine"
        options: [
            { label: "Off", value: "off" },
            { label: "Local Whisper (private)", value: "local" },
            { label: "OpenAI API", value: "openai" }
        ]
        defaultValue: "local"
    }

    SelectionSetting {
        settingKey: "whisperLang"
        label: "Transcription language"
        description: "Select Auto detect or a language code for Whisper."
        options: [
            { label: "Auto detect", value: "auto" },
            { label: "Portuguese", value: "pt" },
            { label: "English", value: "en" },
            { label: "Spanish", value: "es" },
            { label: "French", value: "fr" },
            { label: "German", value: "de" },
            { label: "Italian", value: "it" },
            { label: "Japanese", value: "ja" }
        ]
        defaultValue: "pt"
    }

    SelectionSetting {
        settingKey: "whisperModel"
        label: "Local Whisper model"
        description: "GGML models in ~/.local/share/voxtype/models are detected automatically."
        options: [
            { label: "Auto", value: "auto" },
            { label: "Small · faster", value: "small" },
            { label: "Medium · balanced", value: "medium" },
            { label: "Large v3 Turbo · more accurate", value: "large-v3-turbo" }
        ]
        defaultValue: "medium"
    }

    StringSetting {
        settingKey: "whisperCmd"
        label: "Custom local Whisper command"
        description: "Set auto to detect a CLI. Custom templates run through bash; placeholders: {wav}, {input}, {dir}, {lang}. Only use commands you trust."
        placeholder: "auto"
        defaultValue: "auto"
    }

    SelectionSetting {
        settingKey: "whisperApiModel"
        label: "OpenAI transcription model"
        options: [
            { label: "whisper-1 · SRT timestamps", value: "whisper-1" },
            { label: "gpt-4o-transcribe", value: "gpt-4o-transcribe" },
            { label: "gpt-4o-mini-transcribe", value: "gpt-4o-mini-transcribe" }
        ]
        defaultValue: "whisper-1"
    }

    StringSetting {
        settingKey: "whisperKeyEnv"
        label: "API-key environment variable name"
        description: "Store the key in your environment, not plugin settings. OpenAI mode uploads audio to api.openai.com; Local mode keeps it on your machine."
        placeholder: "OPENAI_API_KEY"
        defaultValue: "OPENAI_API_KEY"
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outlineVariant
        opacity: 0.45
    }

    StyledText {
        width: parent.width
        text: "Required: yt-dlp and ffmpeg. Optional: Qt Multimedia for embedded video, mpv for audio fallback, socat for mpv pause control, and a Whisper CLI for local transcription."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }
}
