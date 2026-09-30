import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "badr-emil.rustdesk"
  ipcTarget: "badr-emil.rustdesk"

  property string state: "loading"
  property string rustdeskId: ""
  property string service: ""
  property string message: "Checking RustDesk…"
  property var peers: []
  property int peerIndex: 0
  property bool cursorActive: false

  readonly property string pluginPath: decodeURIComponent(
    Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")
  )
  readonly property int refreshInterval: Math.max(5, Number(setting("refreshIntervalSec", 10)) || 10) * 1000
  readonly property bool hideWhenIdle: setting("hideWhenIdle", false) === true
  readonly property bool installed: state !== "missing" && state !== "loading"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string heroStatusText: {
    if (state === "missing") return "Not installed"
    if (state === "connected") return "Remote session active"
    if (state === "idle") return "Ready"
    if (state === "stopped") return "Not running"
    if (state === "error") return "Unavailable"
    return "Checking"
  }

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
    if (opened && !peersProcess.running) peersProcess.running = true
  }

  function applyStatus(output) {
    try {
      var result = JSON.parse(String(output).trim())
      state = String(result.state || "error")
      rustdeskId = String(result.id || "")
      service = String(result.service || "")
      message = String(result.message || "RustDesk status unavailable")
    } catch (error) {
      state = "error"
      message = "RustDesk plugin returned an invalid response"
    }
  }

  function applyPeers(output) {
    try {
      var list = JSON.parse(String(output).trim())
      peers = list instanceof Array ? list : []
    } catch (error) {
      peers = []
    }
    peerIndex = Math.max(0, Math.min(peerIndex, peers.length - 1))
  }

  function formatId(id) {
    var value = String(id || "")
    return /^\d{9,}$/.test(value) ? value.replace(/(\d{3})(?=\d)/g, "$1 ") : value
  }

  function cleanId(id) {
    return String(id || "").replace(/\s+/g, "")
  }

  function validId(id) {
    return /^[A-Za-z0-9@._:-]+$/.test(cleanId(id))
  }

  function peerTitle(peer) {
    if (!peer) return ""
    return String(peer.alias || peer.hostname || formatId(peer.id))
  }

  function peerSubtitle(peer) {
    if (!peer) return ""
    var parts = [formatId(peer.id)]
    if (peer.username) parts.push(peer.username)
    if (peer.platform) parts.push(peer.platform)
    return parts.join(" · ")
  }

  function platformIcon(platform) {
    var value = String(platform || "").toLowerCase()
    if (value.indexOf("windows") >= 0) return "󰖳"
    if (value.indexOf("mac") >= 0) return "󰀵"
    if (value.indexOf("android") >= 0) return "󰀲"
    if (value.indexOf("linux") >= 0) return "󰌽"
    return "󰍹"
  }

  function connect(id, mode) {
    var target = cleanId(id)
    if (!validId(target)) return
    var flag = mode === "files" ? "--file-transfer" : "--connect"
    Quickshell.execDetached(["uwsm-app", "--", "rustdesk", flag, target])
    close()
  }

  function connectFromField() {
    if (validId(idField.text)) {
      connect(idField.text, "control")
      idField.text = ""
    }
  }

  function launch() {
    Quickshell.execDetached(["omarchy-launch-or-focus", "rustdesk"])
    close()
  }

  function copyId() {
    Quickshell.execDetached([root.pluginPath + "scripts/copy-id"])
  }

  function install() {
    Quickshell.execDetached([
      "omarchy-launch-floating-terminal-with-presentation",
      "yay -S --needed rustdesk-bin"
    ])
    close()
  }

  function moveCursor(dy) {
    if (peers.length === 0) return
    if (!cursorActive) {
      cursorActive = true
      return
    }
    peerIndex = Math.max(0, Math.min(peers.length - 1, peerIndex + dy))
  }

  onOpenedChanged: {
    if (opened) {
      cursorActive = false
      peerIndex = 0
      refresh()
    } else {
      idField.text = ""
    }
  }

  visible: !hideWhenIdle || state === "connected"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statusProcess
    command: [root.pluginPath + "scripts/rustdesk-status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.state === "loading") {
        root.state = "error"
        root.message = "Unable to check RustDesk"
      }
    }
  }

  Process {
    id: peersProcess
    command: [root.pluginPath + "scripts/rustdesk-peers"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyPeers(text)
    }
  }

  Timer {
    interval: root.refreshInterval
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    iconComponent: Component {
      Item {
        Text {
          anchors.centerIn: parent
          text: root.state === "missing" ? "" : "󰢹"
          color: root.state === "connected" ? root.urgent : button.foreground
          opacity: root.state === "stopped" ? 0.5 : 1
          font.family: button.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }
    }
    tooltipText: root.opened ? "" : root.message
      + (root.rustdeskId !== "" ? "\nID: " + root.formatId(root.rustdeskId) : "")
      + "\n\nLeft: connect panel · Right: copy ID"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton && root.installed) root.copyId()
      else if (buttonCode === Qt.MiddleButton && root.installed) root.launch()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: idField.activeFocus
      onMoveRequested: function(dx, dy) { root.moveCursor(dy !== 0 ? dy : dx) }
      onActivateRequested: {
        if (root.cursorActive && root.peers.length > 0) root.connect(root.peers[root.peerIndex].id, "control")
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(key) {
        if (/^[0-9]$/.test(key) && root.installed) {
          idField.forceActiveFocus()
          idField.text = idField.text + key
        }
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero: icon · title/status · actions ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: "󰢹"
            color: root.state === "connected" ? root.urgent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroActions.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "RustDesk"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.heroStatusText.toUpperCase()
              color: root.state === "connected" ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Row {
            id: heroActions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)
            visible: root.installed

            PanelActionButton {
              iconText: "󰏌"
              tooltipText: "Open RustDesk"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.launch()
            }

            PanelActionButton {
              iconText: "󰑐"
              tooltipText: "Refresh"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.refresh()
            }
          }
        }

        // ---------- Not installed ----------
        Button {
          visible: root.state === "missing"
          width: parent.width
          iconText: "󰏗"
          text: "Install RustDesk"
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          onClicked: root.install()
        }

        // ---------- Own ID ----------
        CursorSurface {
          visible: root.installed && root.rustdeskId !== ""
          width: parent.width
          foreground: root.foreground
          bordered: true
          implicitHeight: ownIdRow.implicitHeight + Style.spacing.rowPaddingX

          RowLayout {
            id: ownIdRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(1)

              Text {
                text: "YOUR ID"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
              }

              Text {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: root.formatId(root.rustdeskId)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
              }
            }

            PanelActionButton {
              iconText: "󰆏"
              tooltipText: "Copy ID"
              foreground: root.foreground
              fontFamily: root.fontFamily
              Layout.alignment: Qt.AlignVCenter
              onClicked: root.copyId()
            }
          }
        }

        // ---------- Connect to a remote PC ----------
        Column {
          visible: root.installed
          width: parent.width
          spacing: Style.space(10)

          PanelSeparator { foreground: root.foreground }

          PanelSectionHeader {
            text: "CONNECT TO REMOTE PC"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          RowLayout {
            width: parent.width
            spacing: Style.space(6)

            TextField {
              id: idField
              Layout.fillWidth: true
              foreground: root.foreground
              placeholderText: "Partner ID"
              inputMethodHints: Qt.ImhNoPredictiveText
              onAccepted: root.connectFromField()
              Keys.onEscapePressed: function(event) {
                if (text !== "") text = ""
                else root.close()
                event.accepted = true
              }
            }

            PanelActionButton {
              iconText: "󰢹"
              tooltipText: "Remote control"
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: root.validId(idField.text)
              Layout.alignment: Qt.AlignVCenter
              onClicked: root.connectFromField()
            }

            PanelActionButton {
              iconText: "󰉋"
              tooltipText: "File transfer"
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: root.validId(idField.text)
              Layout.alignment: Qt.AlignVCenter
              onClicked: {
                root.connect(idField.text, "files")
                idField.text = ""
              }
            }
          }
        }

        // ---------- Recent sessions ----------
        Column {
          visible: root.installed && root.peers.length > 0
          width: parent.width
          spacing: Style.space(6)

          PanelSectionHeader {
            text: "RECENT"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Repeater {
            model: root.peers
            PeerRow {
              required property var modelData
              required property int index
              width: parent.width
              peer: modelData
              rowIndex: index
            }
          }
        }
      }
    }
  }

  component PeerRow: CursorSurface {
    id: peerRow
    property var peer: null
    property int rowIndex: 0

    hasCursor: root.cursorActive && root.peerIndex === rowIndex
    foreground: root.foreground
    implicitHeight: Math.max(peerContent.implicitHeight, controlButton.implicitHeight) + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: {
        if (containsMouse) {
          root.cursorActive = true
          root.peerIndex = peerRow.rowIndex
        }
      }
      onClicked: root.connect(peerRow.peer.id, "control")
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: root.platformIcon(peerRow.peer ? peerRow.peer.platform : "")
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        id: peerContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: root.peerTitle(peerRow.peer)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: root.peerSubtitle(peerRow.peer)
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      PanelActionButton {
        id: controlButton
        iconText: "󰢹"
        tooltipText: "Remote control"
        foreground: root.foreground
        fontFamily: root.fontFamily
        Layout.alignment: Qt.AlignVCenter
        onClicked: root.connect(peerRow.peer.id, "control")
      }

      PanelActionButton {
        iconText: "󰉋"
        tooltipText: "File transfer"
        foreground: root.foreground
        fontFamily: root.fontFamily
        Layout.alignment: Qt.AlignVCenter
        onClicked: root.connect(peerRow.peer.id, "files")
      }
    }
  }
}
