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

    property string _title: ""
    property string _artist: ""
    property string _album: ""

    function syncStable(): void {
        const player = root.active;
        root._title = player?.trackTitle ?? "";
        root._artist = player?.trackArtist ?? "";
        root._album = player?.trackAlbum ?? "";
    }

    Timer {
        id: settle
        interval: 150
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
            settle.restart();
        }

        function onTrackTitleChanged(): void {
            settle.restart();
        }

        function onTrackArtistChanged(): void {
            settle.restart();
        }

        function onTrackAlbumChanged(): void {
            settle.restart();
        }

        // Art usually resolves after title/artist (Chromium fetches/writes a temp
        // file asynchronously), so a settle restarted only by text metadata fires
        // before art is available. Restarting on this too lets the single toast wait
        // for both when art arrives inside the settle window, without re-toasting
        // for art alone once title/artist have already settled (see key dedup above).
        function onTrackArtUrlChanged(): void {
            settle.restart();
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
