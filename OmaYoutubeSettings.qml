import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "omaYoutubeDl"

    StyledText {
        width: parent.width
        text: "Oma YouTube"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
    }
    StyledText {
        width: parent.width
        text: "Search YouTube, preview streams, queue yt-dlp downloads, and optionally create subtitles. Settings save automatically."
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
        description: "Supports an absolute path or ~/…"
        placeholder: Quickshell.env("HOME") + "/Videos/Omayoutube"
        defaultValue: Quickshell.env("HOME") + "/Videos/Omayoutube"
    }

    SelectionSetting {
        settingKey: "dlMode"
        label: "Default download type"
        description: "The Video / Audio buttons in the popout can also switch this quickly."
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
            { label: "Do not remux", value: "best" }
        ]
        defaultValue: "mp4"
    }

    SelectionSetting {
        settingKey: "audioFormat"
        label: "Extracted audio format"
        options: ["mp3", "m4a", "opus", "flac", "wav"]
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

    Rectangle { width: parent.width; height: 1; color: Theme.outlineVariant; opacity: 0.45 }

    StyledText {
        width: parent.width
        text: "Search & source options"
        color: Theme.primary
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
    }

    SelectionSetting {
        settingKey: "maxResults"
        label: "Results per search"
        options: ["5", "10", "15"]
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
        description: "Use your browser's local cookie store if YouTube asks you to sign in or confirm you are not a bot. Cookies are read locally by yt-dlp."
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
        description: "A dub may not exist for every video; yt-dlp falls back to the best available audio. Multi-track downloads use MKV."
        options: [
            { label: "Original / best", value: "original" },
            { label: "Portuguese dub (fallback to original)", value: "pt" },
            { label: "Original + Portuguese", value: "original+pt" },
            { label: "Portuguese + English", value: "pt+en" }
        ]
        defaultValue: "original"
    }

    SelectionSetting {
        settingKey: "subLangs"
        label: "Native captions"
        description: "Downloads YouTube captions or auto-translated captions; does not require Whisper."
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
        label: "Embed native captions"
        description: "When enabled, video and captions are muxed into MKV; otherwise captions are written as sidecar SRT files."
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showVideo"
        label: "Show video in preview card"
        description: "Turn off the embedded video surface if you only want audio-style playback controls."
        defaultValue: true
    }

    Rectangle { width: parent.width; height: 1; color: Theme.outlineVariant; opacity: 0.45 }

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
        description: "Used by local Whisper and as a hint for the audio track download."
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
            { label: "Large v3 Turbo · best accuracy", value: "large-v3-turbo" }
        ]
        defaultValue: "medium"
    }

    StringSetting {
        settingKey: "whisperCmd"
        label: "Custom local Whisper command"
        description: "Use auto to detect whisper-cli / whisper. Custom templates run through bash; placeholders: {wav}, {input}, {dir}, {lang}. Only enter commands you trust."
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
        label: "Environment variable name for API key"
        description: "The key itself is never stored here. Set this environment variable before starting DMS. OpenAI mode uploads the extracted audio to api.openai.com; Local mode keeps it on this machine."
        placeholder: "OPENAI_API_KEY"
        defaultValue: "OPENAI_API_KEY"
    }

    Rectangle { width: parent.width; height: 1; color: Theme.outlineVariant; opacity: 0.45 }

    StyledText {
        width: parent.width
        text: "Requirements: yt-dlp and ffmpeg. mpv + socat enable the audio fallback player controls. whisper-cli (or whisper) is optional and needed only for local transcription."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }
}
