import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.components.images
import qs.services

StyledRect {
    id: root

    required property Toast modelData

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: layout.implicitHeight + Tokens.padding.large

    radius: Tokens.rounding.large
    color: {
        if (root.modelData.type === Toast.Success)
            return Colours.palette.m3successContainer;
        if (root.modelData.type === Toast.Warning)
            return Colours.palette.m3secondary;
        if (root.modelData.type === Toast.Error)
            return Colours.palette.m3errorContainer;
        return Colours.palette.m3surface;
    }

    border.width: 1
    border.color: {
        let colour = Colours.palette.m3outlineVariant;
        if (root.modelData.type === Toast.Success)
            colour = Colours.palette.m3success;
        if (root.modelData.type === Toast.Warning)
            colour = Colours.palette.m3secondaryContainer;
        if (root.modelData.type === Toast.Error)
            colour = Colours.palette.m3error;
        return Qt.alpha(colour, 0.3);
    }

    Elevation {
        anchors.fill: parent
        radius: parent.radius
        opacity: parent.opacity
        z: -1
        level: 3
    }

    RowLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        StyledRect {
            id: iconContainer

            readonly property bool isImageUrl: {
                const ic = root.modelData.icon;
                return ic.startsWith("http://") || ic.startsWith("https://") || ic.startsWith("file://");
            }

            radius: Tokens.rounding.large
            color: {
                if (isImageUrl)
                    return "transparent";
                if (root.modelData.type === Toast.Success)
                    return Colours.palette.m3success;
                if (root.modelData.type === Toast.Warning)
                    return Colours.palette.m3secondaryContainer;
                if (root.modelData.type === Toast.Error)
                    return Colours.palette.m3error;
                return Colours.palette.m3surfaceContainerHigh;
            }

            implicitWidth: isImageUrl ? artSize : implicitHeight
            implicitHeight: isImageUrl ? artSize : icon.implicitHeight + Tokens.padding.large

            readonly property real artSize: icon.implicitHeight + Tokens.padding.large

            // Album art thumbnail (shown when icon is a URL). FadeImage keeps the
            // previous frame while the new one loads and crossfades instead of
            // hard-cutting, same as the dashboard cover art (CoverArt.qml).
            FadeImage {
                id: artImage

                anchors.fill: parent
                source: iconContainer.isImageUrl ? root.modelData.icon : ""

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: ShaderEffectSource {
                        sourceItem: Rectangle {
                            width: artImage.width
                            height: artImage.height
                            radius: Tokens.rounding.large
                        }
                    }
                }
            }

            // Fallback icon when image fails to load
            MaterialIcon {
                anchors.centerIn: parent
                text: "music_note"
                visible: iconContainer.isImageUrl && artImage.status !== Image.Ready
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.builders.large.scale(1.2).build()
            }

            // Standard material icon (shown for non-URL icons)
            MaterialIcon {
                id: icon

                anchors.centerIn: parent
                text: root.modelData.icon
                visible: !iconContainer.isImageUrl
                color: {
                    if (root.modelData.type === Toast.Success)
                        return Colours.palette.m3onSuccess;
                    if (root.modelData.type === Toast.Warning)
                        return Colours.palette.m3onSecondaryContainer;
                    if (root.modelData.type === Toast.Error)
                        return Colours.palette.m3onError;
                    return Colours.palette.m3onSurfaceVariant;
                }
                fontStyle: Tokens.font.icon.builders.large.scale(1.2).build()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: title

                Layout.fillWidth: true
                text: root.modelData.title
                color: {
                    if (root.modelData.type === Toast.Success)
                        return Colours.palette.m3onSuccessContainer;
                    if (root.modelData.type === Toast.Warning)
                        return Colours.palette.m3onSecondary;
                    if (root.modelData.type === Toast.Error)
                        return Colours.palette.m3onErrorContainer;
                    return Colours.palette.m3onSurface;
                }
                font: Tokens.font.title.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                textFormat: Text.StyledText
                text: root.modelData.message
                color: {
                    if (root.modelData.type === Toast.Success)
                        return Colours.palette.m3onSuccessContainer;
                    if (root.modelData.type === Toast.Warning)
                        return Colours.palette.m3onSecondary;
                    if (root.modelData.type === Toast.Error)
                        return Colours.palette.m3onErrorContainer;
                    return Colours.palette.m3onSurface;
                }
                opacity: 0.8
                elide: Text.ElideRight
            }
        }
    }

    Behavior on border.color {
        CAnim {}
    }
}
