import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
    id: root

    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

    function injectPanel() {
        var target = panelLoader.item;
        if (!target)
            return ;

        target.bar = root.bar;
        target.settings = root.settings;
        target.anchorItem = button;
        target.hostWidget = root;
    }

    function open() {
        if (panelLoader.item)
            panelLoader.item.openFromHotkey();

    }

    function close() {
        if (panelLoader.item)
            panelLoader.item.close();

    }

    function togglePanel() {
        if (panelLoader.item)
            panelLoader.item.toggle();

    }

    function refresh() {
        if (panelLoader.item)
            panelLoader.item.refresh(true);

    }

    function closeForPopoutSwitch() {
        if (panelLoader.item)
            panelLoader.item.closeForPopoutSwitch();

    }

    moduleName: "underday.snooker-calendar"
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    onBarChanged: injectPanel()
    onSettingsChanged: injectPanel()

    Loader {
        id: panelLoader

        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel();
            Qt.callLater(root.injectPanel);
        }
    }

    WidgetButton {
        id: button

        anchors.fill: parent
        bar: root.bar
        text: panelLoader.item ? panelLoader.item.barLabel : "🎱"
        tooltipText: panelLoader.item ? panelLoader.item.tooltip : "Snooker Calendar"
        horizontalMargin: Style.space(8)
        onPressed: function(mouseButton) {
            if (mouseButton === Qt.MiddleButton)
                root.refresh();
            else
                root.togglePanel();
        }
    }

}
