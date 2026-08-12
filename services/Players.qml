pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Caelestia
import Caelestia.Config
import qs.components.misc

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    readonly property MprisPlayer active: props.manualActive ?? list.find(p => getIdentity(p) === GlobalConfig.services.defaultPlayer) ?? list[0] ?? null
    property alias manualActive: props.manualActive

    // Debounced metadata: Chromium's MPRIS bridge (browser tabs, Electron wrappers like
    // Pear) fires title/artist/album as separate PropertiesChanged signals while a page's
    // MediaSession JS fills them in one at a time, so raw values show mismatched pairs
    // (new title + stale artist) for a frame. Consumers should read these instead of
    // Players.active.trackTitle/trackArtist/trackAlbum directly.
    readonly property string trackTitle: _title
    readonly property string trackArtist: _artist
    readonly property string trackAlbum: _album

    // Upper bound on how long a single burst may hold the debounce open
    readonly property int settleMaxWait: 1000

    property string _title: ""
    property string _artist: ""
    property string _album: ""
    property real _settleStarted: 0

    function syncStable(): void {
        const player = root.active;
        root._title = player?.trackTitle ?? "";
        root._artist = player?.trackArtist ?? "";
        root._album = player?.trackAlbum ?? "";
    }

    // Extends the debounce, but only up to settleMaxWait from the first signal of the
    // burst. A source that changes metadata faster than the interval — a stream that
    // scrolls text through the title, say — would otherwise restart the timer forever
    // and leave both the properties above and the toast stuck on the previous track.
    function bumpSettle(): void {
        if (!settle.running)
            root._settleStarted = Date.now();
        else if (Date.now() - root._settleStarted >= root.settleMaxWait)
            return; // Let the pending timeout through instead of pushing it back again

        settle.restart();
    }

    Timer {
        id: settle

        // Long enough to cover the gap between the text metadata and the art that
        // follows it, since Toast.icon is fixed once the toast exists and cannot be
        // corrected later. Chromium republishes art a few hundred ms behind the
        // title, so a shorter window locks the toast to a missing icon.
        interval: 300
        onTriggered: {
            root.syncStable();
            root.maybeToastNowPlaying();
        }
    }

    // Dedup key for progressive metadata (e.g. mpv-mpris/yt-dlp player fills title then artist later).
    property string lastNowPlayingKey: ""

    function getIdentity(player: MprisPlayer): string {
        if (!player)
            return "";
        const alias = GlobalConfig.services.playerAliases.find(a => a.from === player.identity);
        return alias?.to ?? player.identity;
    }

    function getArtUrl(player: MprisPlayer): string {
        if (!player)
            return "";
        if (player.trackArtUrl)
            return player.trackArtUrl;

        const url = player.metadata["xesam:url"] ?? "";
        if (url.startsWith("https://www.youtube.com/watch")) {
            // Fallback for youtube
            const id = url.match(/[?&]v=([\w-]{11})/)?.[1];
            return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : "";
        }
        return "";
    }

    // Called only after settle fires, i.e. once title/artist have stopped changing for
    // a beat, so the toast never fires on a mismatched intermediate pairing.
    function maybeToastNowPlaying(): void {
        if (!GlobalConfig.utilities.toasts.nowPlaying)
            return;

        const player = root.active;
        if (!player)
            return;

        const title = root._title;
        const artist = root._artist;
        if (!title || !artist)
            return;

        const key = `${getIdentity(player)}\0${player.uniqueId}\0${title}\0${artist}`;
        if (key === lastNowPlayingKey)
            return;

        lastNowPlayingKey = key;
        const artIcon = root.getArtUrl(player) || "music_note";
        Toaster.toast(qsTr("Now Playing"), qsTr("%1 - %2").arg(artist).arg(title), artIcon);
    }

    onActiveChanged: {
        lastNowPlayingKey = "";
        settle.stop();
        syncStable();
        maybeToastNowPlaying();
    }

    Connections {
        function onPostTrackChanged(): void {
            root.bumpSettle();
        }

        function onTrackTitleChanged(): void {
            root.bumpSettle();
        }

        function onTrackArtistChanged(): void {
            root.bumpSettle();
        }

        function onTrackAlbumChanged(): void {
            root.bumpSettle();
        }

        // Art lands after the text on Chromium-based players, which write a fresh
        // temp file per track. Waiting on it too means the icon is read once the art
        // has stopped moving; the key dedup above keeps this from toasting twice.
        function onTrackArtUrlChanged(): void {
            root.bumpSettle();
        }

        target: root.active
    }

    PersistentProperties {
        id: props

        property MprisPlayer manualActive

        reloadableId: "players"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaToggle"
        description: "Toggle media playback"
        onPressed: {
            const active = root.active;
            if (active && active.canTogglePlaying)
                active.togglePlaying();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaPrev"
        description: "Previous track"
        onPressed: {
            const active = root.active;
            if (active && active.canGoPrevious)
                active.previous();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaNext"
        description: "Next track"
        onPressed: {
            const active = root.active;
            if (active && active.canGoNext)
                active.next();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaStop"
        description: "Stop media playback"
        onPressed: root.active?.stop()
    }

    IpcHandler {
        function getActive(prop: string): string {
            const active = root.active;
            return active ? active[prop] ?? "Invalid property" : "No active player";
        }

        function list(): string {
            return root.list.map(p => root.getIdentity(p)).join("\n");
        }

        function play(): void {
            const active = root.active;
            if (active?.canPlay)
                active.play();
        }

        function pause(): void {
            const active = root.active;
            if (active?.canPause)
                active.pause();
        }

        function playPause(): void {
            const active = root.active;
            if (active?.canTogglePlaying)
                active.togglePlaying();
        }

        function previous(): void {
            const active = root.active;
            if (active?.canGoPrevious)
                active.previous();
        }

        function next(): void {
            const active = root.active;
            if (active?.canGoNext)
                active.next();
        }

        function stop(): void {
            root.active?.stop();
        }

        target: "mpris"
    }
}
