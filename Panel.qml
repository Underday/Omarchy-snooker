import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "underday.snooker-calendar"
  ipcTarget: "underday.snooker-calendar"
  manageIpc: false

  readonly property color baize: Qt.rgba(0.04, 0.42, 0.24, 0.94)
  readonly property color accent: "#2ea36a"

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  property var schedule: ({ ok: false, error: "Loading the calendar…", current: null, live: [], today: [], later: [], results: [], upcoming: [] })
  property date clock: new Date()
  property string errorText: ""
  property bool refreshing: false
  property bool openedFromHotkey: false
  readonly property int refreshHours: Math.max(3, Math.min(24, Number(setting("refreshHours", 6)) || 6))
  readonly property int liveSeconds: Math.max(20, Math.min(300, Number(setting("liveSeconds", 45)) || 45))
  readonly property string fetchScript: Qt.resolvedUrl("bin/snooker-fetch").toString().replace(/^file:\/\//, "")
  readonly property string liveScript: Qt.resolvedUrl("bin/snooker-live").toString().replace(/^file:\/\//, "")
  readonly property bool hasLive: !!schedule.live && schedule.live.length > 0
  readonly property string barLabel: "🎱"
  readonly property string tooltip: schedule.current ? schedule.current.name : "Snooker Calendar"

  function open() { openedFromHotkey = false; controller.show() }
  function openFromHotkey() { openedFromHotkey = true; controller.show() }
  function close() { controller.hide() }
  function toggle() { if (opened) close(); else openFromHotkey() }
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function") return bar.switchPanelFrom(barIdentity, direction)
    return false
  }
  function refresh(force) {
    if (fetchProcess.running) return
    refreshing = true
    fetchProcess.command = force === true ? [fetchScript, "--force", String(refreshHours)] : [fetchScript, "", String(refreshHours)]
    fetchProcess.running = true
  }
  function refreshLive() {
    if (liveProcess.running || !hasLive) return
    var command = [liveScript]
    for (var i = 0; i < schedule.live.length && i < 8; i++) command.push(schedule.live[i].id)
    liveProcess.command = command
    liveProcess.running = true
  }
  function applySchedule(raw) {
    var parsed = Model.parsePayload(raw, clock)
    if (parsed.ok) {
      schedule = parsed
      errorText = ""
      refreshLive()
    } else {
      errorText = parsed.error
    }
  }
  function applyLive(raw) {
    // Reassign so the bindings that read frame state see the update.
    schedule = Model.mergeLive(schedule, raw)
  }
  function localDay(value) { return Qt.formatDateTime(value, "ddd").toUpperCase() }
  function localTime(value) { return Qt.formatDateTime(value, "HH:mm") }
  function dateRange(tournament) { return Model.dateRange(tournament, function(d, f) { return Qt.formatDate(d, f) }) }
  function setCenterHoverRevealSuppressed(value) {
    if (bar && "centerHoverRevealSuppressed" in bar) bar.centerHoverRevealSuppressed = value
  }

  Component.onCompleted: refresh(false)
  onOpenedChanged: {
    setCenterHoverRevealSuppressed(openedFromHotkey && opened)
    if (opened) { clock = new Date(); refreshLive() }
  }

  Timer {
    interval: root.opened ? 1000 : 60000
    running: true
    repeat: true
    onTriggered: root.clock = new Date()
  }
  Timer {
    interval: root.refreshHours * 60 * 60 * 1000
    running: true
    repeat: true
    onTriggered: root.refresh(false)
  }
  Timer {
    // Live frame state only matters while somebody is looking at it.
    interval: root.liveSeconds * 1000
    running: root.opened && root.hasLive
    repeat: true
    onTriggered: root.refreshLive()
  }

  Process {
    id: fetchProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applySchedule(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim()) root.errorText = String(text).trim()
    }
    onExited: function(exitCode) {
      root.refreshing = false
      if (exitCode !== 0 && !root.schedule.current && !root.errorText) root.errorText = "Calendar unavailable — check your connection"
    }
  }

  Process {
    id: liveProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyLive(text)
    }
    stderr: StdioCollector { waitForEnd: true }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh(true) }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(760))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) { if (text === "r" || text === "R") root.refresh(true) }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: contentColumn
          width: parent.width
          spacing: Style.space(12)

          // ── Tournament hero ───────────────────────────────────────────
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(168)
            radius: Style.cornerRadius
            color: root.baize
            clip: true
            visible: !!root.schedule.current

            // Six pockets on a cloth: a snooker motif without borrowed artwork.
            Item {
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.rightMargin: Style.space(16)
              anchors.topMargin: Style.space(16)
              width: Style.space(96)
              height: Style.space(58)
              opacity: 0.18
              Repeater {
                model: 6
                Rectangle {
                  width: Style.space(16); height: width; radius: width / 2
                  color: "black"
                  x: (index % 3) * (Style.space(40))
                  y: Math.floor(index / 3) * Style.space(42)
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
              anchors.leftMargin: Style.space(18); anchors.rightMargin: Style.space(18); anchors.topMargin: Style.space(14)
              text: "SNOOKER" + (root.schedule.round ? "  /  " + root.schedule.round.toUpperCase() : "")
              color: "white"; font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall; font.bold: true; font.letterSpacing: 1.5
              elide: Text.ElideRight
            }

            Column {
              anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
              anchors.verticalCenterOffset: -Style.space(6)
              anchors.leftMargin: Style.space(18); anchors.rightMargin: Style.space(18)
              spacing: Style.space(3)
              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: root.schedule.current ? root.schedule.current.name.toUpperCase() : ""
                color: "white"; font.family: root.bar.fontFamily; font.pixelSize: Style.font.heading; font.bold: true
                elide: Text.ElideRight
              }
              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: root.schedule.current ? Model.place(root.schedule.current) : ""
                color: Qt.rgba(1, 1, 1, 0.78); font.family: root.bar.fontFamily; font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }
            }

            Text {
              textFormat: Text.PlainText
              anchors.left: parent.left; anchors.bottom: parent.bottom
              anchors.leftMargin: Style.space(18); anchors.bottomMargin: Style.space(14)
              text: root.schedule.running
                    ? (root.hasLive ? "● LIVE" : "UNDER WAY")
                    : Model.countdown(root.schedule.current ? root.schedule.current.start : null, root.clock, false, true)
              color: "white"; font.family: root.bar.fontFamily; font.pixelSize: 26; font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              anchors.right: parent.right; anchors.bottom: parent.bottom
              anchors.rightMargin: Style.space(18); anchors.bottomMargin: Style.space(18)
              text: root.dateRange(root.schedule.current)
              color: Qt.rgba(1, 1, 1, 0.82); font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true
            }
          }

          // ── Live matches ──────────────────────────────────────────────
          Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            visible: root.hasLive
            text: "LIVE"
            color: root.accent; font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1.2
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(5)
            visible: root.hasLive
            Repeater {
              model: root.schedule.live ? root.schedule.live : []
              delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: frameText.text ? Style.space(72) : Style.space(52)
                radius: Style.cornerRadius
                color: Qt.rgba(0.18, 0.64, 0.42, 0.12)
                border.width: 1
                border.color: Qt.rgba(0.18, 0.64, 0.42, 0.45)

                ColumnLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(12); anchors.rightMargin: Style.space(12)
                  anchors.topMargin: Style.space(8); anchors.bottomMargin: Style.space(8)
                  spacing: Style.space(2)

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(8)
                    Text {
                      Layout.fillWidth: true
                      textFormat: Text.PlainText
                      text: modelData.home
                      horizontalAlignment: Text.AlignRight
                      color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body
                      elide: Text.ElideRight
                    }
                    Text {
                      textFormat: Text.PlainText
                      text: modelData.homeScore + " – " + modelData.awayScore
                      color: root.accent; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; font.bold: true
                    }
                    Text {
                      Layout.fillWidth: true
                      textFormat: Text.PlainText
                      text: modelData.away
                      color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body
                      elide: Text.ElideRight
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(8)
                    Text {
                      textFormat: Text.PlainText
                      text: Model.metaLabel(modelData)
                      color: root.accent; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                    }
                    Text {
                      id: frameText
                      Layout.fillWidth: true
                      textFormat: Text.PlainText
                      horizontalAlignment: Text.AlignHCenter
                      text: Model.frameLine(modelData)
                      color: Qt.darker(root.bar.foreground, 1.5); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption
                      elide: Text.ElideLeft
                    }
                    Text {
                      textFormat: Text.PlainText
                      text: modelData.bestOf ? "BEST OF " + modelData.bestOf : ""
                      color: Qt.darker(root.bar.foreground, 1.6); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption
                    }
                  }
                }
              }
            }
          }

          // ── Today's remaining matches ─────────────────────────────────
          Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            visible: root.schedule.today && root.schedule.today.length > 0
            text: "TODAY"
            color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1.2
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)
            visible: root.schedule.today && root.schedule.today.length > 0
            Repeater {
              model: root.schedule.today ? root.schedule.today : []
              delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(38)
                radius: Style.cornerRadius
                color: Qt.rgba(1, 1, 1, 0.035)
                RowLayout {
                  anchors.fill: parent; anchors.leftMargin: Style.space(12); anchors.rightMargin: Style.space(12)
                  spacing: Style.space(10)
                  Text {
                    textFormat: Text.PlainText
                    Layout.preferredWidth: Style.space(48)
                    text: modelData.start ? root.localTime(modelData.start) : "TBD"
                    color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true
                  }
                  Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: modelData.home + "  vs  " + modelData.away
                    color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: Model.startLabel(modelData, root.clock)
                    color: Qt.darker(root.bar.foreground, 1.5); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption
                  }
                }
              }
            }
          }

          // ── Latest results ────────────────────────────────────────────
          Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            visible: root.schedule.results && root.schedule.results.length > 0
            text: "LATEST RESULTS"
            color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1.2
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)
            visible: root.schedule.results && root.schedule.results.length > 0
            Repeater {
              model: root.schedule.results ? root.schedule.results : []
              delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: Style.space(12)
                Layout.rightMargin: Style.space(12)
                spacing: Style.space(8)
                Text {
                  Layout.fillWidth: true
                  textFormat: Text.PlainText
                  horizontalAlignment: Text.AlignRight
                  text: modelData.home
                  color: modelData.homeScore > modelData.awayScore ? root.bar.foreground : Qt.darker(root.bar.foreground, 1.6)
                  font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
                Text {
                  textFormat: Text.PlainText
                  text: modelData.homeScore + "–" + modelData.awayScore
                  color: Qt.darker(root.bar.foreground, 1.3); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                }
                Text {
                  Layout.fillWidth: true
                  textFormat: Text.PlainText
                  text: modelData.away
                  color: modelData.awayScore > modelData.homeScore ? root.bar.foreground : Qt.darker(root.bar.foreground, 1.6)
                  font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }
            }
          }

          // ── Following tournaments ─────────────────────────────────────
          Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            visible: root.schedule.upcoming && root.schedule.upcoming.length > 0
            text: "NEXT ON TOUR"
            color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1.2
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)
            visible: root.schedule.upcoming && root.schedule.upcoming.length > 0
            Repeater {
              model: root.schedule.upcoming ? root.schedule.upcoming : []
              delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(46)
                radius: Style.cornerRadius
                color: Qt.rgba(1, 1, 1, 0.035)
                RowLayout {
                  anchors.fill: parent; anchors.leftMargin: Style.space(12); anchors.rightMargin: Style.space(12)
                  spacing: Style.space(10)
                  ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text {
                      Layout.fillWidth: true; textFormat: Text.PlainText
                      text: modelData.name
                      color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall
                      elide: Text.ElideRight
                    }
                    Text {
                      Layout.fillWidth: true; textFormat: Text.PlainText
                      text: Model.place(modelData) + "  ·  " + root.dateRange(modelData)
                      color: Qt.darker(root.bar.foreground, 1.5); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }
                  Text {
                    textFormat: Text.PlainText
                    Layout.preferredWidth: Style.space(96)
                    horizontalAlignment: Text.AlignRight
                    text: Model.countdown(modelData.start, root.clock, true)
                    color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                  }
                }
              }
            }
          }

          // ── Empty / error state ───────────────────────────────────────
          ColumnLayout {
            Layout.fillWidth: true
            visible: !root.schedule.current
            spacing: Style.space(10)
            Text {
              Layout.alignment: Qt.AlignHCenter; textFormat: Text.PlainText
              text: "🎱"
              color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: 42
            }
            Text {
              Layout.fillWidth: true; textFormat: Text.PlainText; horizontalAlignment: Text.AlignHCenter
              text: root.refreshing ? "Loading the calendar…" : (root.errorText || root.schedule.error)
              color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; wrapMode: Text.WordWrap
            }
          }

          RowLayout {
            Layout.fillWidth: true
            Text {
              textFormat: Text.PlainText
              text: "Times shown locally · Data: World Snooker Tour"
              color: Qt.darker(root.bar.foreground, 1.6); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption
            }
            Item { Layout.fillWidth: true }
            Text {
              textFormat: Text.PlainText
              text: root.refreshing ? "REFRESHING…" : "R  REFRESH"
              color: Qt.darker(root.bar.foreground, 1.45); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
