import QtQuick
import QtMultimedia

// Kept in a separate file because QtMultimedia is optional in Quickshell.
// OmaYoutubeWidget loads this through a Loader so a missing module cannot
// prevent the plugin itself from being enabled.
Item {
    id: root

    visible: false
    width: 0
    height: 0

    property alias source: mediaPlayer.source
    property alias hasVideo: mediaPlayer.hasVideo
    property alias duration: mediaPlayer.duration
    property alias position: mediaPlayer.position
    property bool isPlaying: false
    property bool isPaused: false
    property var videoOutput: null
    property Component videoOutputComponent: Component {
        VideoOutput {
            fillMode: VideoOutput.PreserveAspectFit
        }
    }

    signal playbackStateUpdated()
    signal mediaError(string message)

    function play() {
        mediaPlayer.play();
    }

    function pause() {
        mediaPlayer.pause();
    }

    function stop() {
        mediaPlayer.stop();
    }

    MediaPlayer {
        id: mediaPlayer
        autoPlay: false
        audioOutput: AudioOutput {}
        videoOutput: root.videoOutput

        onPlaybackStateChanged: {
            root.isPlaying = mediaPlayer.playbackState === MediaPlayer.PlayingState;
            root.isPaused = mediaPlayer.playbackState === MediaPlayer.PausedState;
            root.playbackStateUpdated();
        }
        onErrorOccurred: (error, errorString) => {
            root.mediaError(String(errorString || "Embedded playback failed."));
        }
    }
}
