/****************************************************************************************
**
** Copyright (C) 2013 Jolla Ltd.
** Contact: Martin Jones <martin.jones@jollamobile.com>
** All rights reserved.
** 
** This file is part of Sailfish Silica UI component package.
**
** You may use this file under the terms of BSD license as follows:
**
** Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are met:
**     * Redistributions of source code must retain the above copyright
**       notice, this list of conditions and the following disclaimer.
**     * Redistributions in binary form must reproduce the above copyright
**       notice, this list of conditions and the following disclaimer in the
**       documentation and/or other materials provided with the distribution.
**     * Neither the name of the Jolla Ltd nor the
**       names of its contributors may be used to endorse or promote products
**       derived from this software without specific prior written permission.
** 
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
** ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
** WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
** DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR
** ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
** (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
** LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
** ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
** SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**
****************************************************************************************/

import QtQuick 2.0
import Sailfish.Silica 1.0
import "private/Util.js" as Util
import "private/RemorseItem.js" as RemorseItem
import "private"

MouseArea {
    id: contextMenu

    property bool active
    property bool closeOnActivation: true

    property int _openAnimationDuration: 200
    property Item _highlightedItem
    property Flickable _flickable
    property bool _flickableMoved
    property Item _parentMouseArea
    property bool _closeOnOutsideClick: true
    property bool _hidden
    property bool _open
    property bool _expanded: height == contentColumn.height && height > 0
    property real _expandedPosition
    property Item _page
    property bool _activeAllowed: (!_page || _page.status != PageStatus.Inactive) && Qt.application.active

    signal activated(int index)
    signal closed

    default property alias children: contentColumn.data
    property alias _contentColumn: contentColumn

    x: _page !== null ? mapFromItem(_page, 0, 0).x : 0
    height: _displayHeight
    width: _flickable !== null ? _flickable.width : (parent ? parent.width : 0)
    parent: null
    clip: true
    enabled: active
    anchors.bottom: parent ? parent.bottom : undefined

    onPressed: {
        _flickableMoved = false
        _highlightMenuItem(mouse.y - contentColumn.y)
    }
    onPositionChanged: _updatePosition(mouse.y - contentColumn.y)
    onCanceled: _setHighlightedItem(null)
    onReleased: {
        if (_flickableMoved) {
            // If the flickable has moved during open, the user has made a selection
            // inadvertantly; ignore the activation
            _flickableMoved = false
        } else if (_highlightedItem !== null) {
            _activatedMenuItem(_highlightedItem)
        }
    }
    drag.target: Item {}

    onHeightChanged: {
        if (_highlightedItem) {
            // reposition the highlightBar
            highlightBar.highlight(_highlightedItem, contentColumn)
        }
        if (height == 0 && _hidden) {
            _hidden = false
            parent = null
            _page = null
        }

        if (height == 0) {
            contextMenu.closed()
            _setHighlightedItem(null)
            contextMenu._open = false
        }
    }

    onActiveChanged: {
        if (active) {
            if (_flickable) {
                _flickableContentYAtOpen = _flickable.contentY
            }
            contextMenu._open = true
        }
        if (_parentMouseArea) {
            _parentMouseArea.preventStealing = active
        }
        if (!active) {
            __silica_applicationwindow_instance._undimScreen()
        }

        RemorseItem.activeChanged(contextMenu, active)
    }

    on_ActiveAllowedChanged: {
        if (!_activeAllowed && active) {
            hide()
        }
    }

    function show(item) {
        if (item) {
            parent = item
            if (contentColumn.children.length) {
                _parentMouseArea = _findBackgroundItem(item)
                _flickable = Util.findFlickable(item)
                _flickableMoved = false
                _expandedPosition = -1
                active = true
                _hidden = false
                _page = Util.findPage(contextMenu)
                __silica_applicationwindow_instance._dimScreen([ contextMenu ], parent)
            } else {
                parent = null
                _page = null
            }
        } else {
            console.log("ContextMenu::show() called with an invalid item")
        }
    }
    function hide() {
        active = false
        _hidden = true
        _parentMouseArea = null
    }
    function _parentDestroyed() {
        parent = null
        _page = null
    }

    function _findBackgroundItem(item) {
        if (item.hasOwnProperty("preventStealing") && item.pressed) {
            return item;
        }

        if (!item.hasOwnProperty("children")) {
            return null
        }

        var parent = item
        for (var i=0; i < parent.children.length; i++) {
            var child = parent.children[i]
            if (child.hasOwnProperty("preventStealing") && child.pressed) {
                return child
            }
            var descendant = _findBackgroundItem(child)
            if (descendant) {
                return descendant
            }
        }

        return null
    }

    function _highlightMenuItem(yPos) {
        var xPos = width/2
        var child = contentColumn.childAt(xPos, yPos)
        if (!child) {
            _setHighlightedItem(null)
            return
        }
        var parentItem
        while (child) {
            if (child && child.hasOwnProperty("__silica_menuitem") && child.enabled) {
                _setHighlightedItem(child)
                break
            }
            parentItem = child
            yPos = parentItem.mapToItem(child, xPos, yPos).y
            child = parentItem.childAt(xPos, yPos)
        }
    }

    function _setHighlightedItem(item) {
        if (item === _highlightedItem) {
            return
        }
        if (_highlightedItem) {
            _highlightedItem.down = false
        }
        _highlightedItem = item
        if (_highlightedItem) {
            highlightBar.highlight(_highlightedItem, contentColumn)
            _highlightedItem.down = true
        } else {
            highlightBar.clearHighlight()
        }
    }

    function _activatedMenuItem(item) {
        _foreachMenuItem(function (menuItem, index) {
            if (menuItem === item) {
                menuItem.clicked()
                contextMenu.activated(index)
                if (contextMenu.closeOnActivation) {
                    delayedHiding.restart()
                }
                return false
            }
            return true
        })
    }

    function _updatePosition(y) {
        if (_flickableMoved && _expanded) {
            if (_expandedPosition < 0.0) {
                _expandedPosition = y
            } else if (Math.abs(y - _expandedPosition) > (Theme.itemSizeSmall / 2)) {
                // The user has moved a reasonable amount since the menu opened; re-enable
                _flickableMoved = false
            }
        }
        if (!_flickableMoved) {
            _highlightMenuItem(y)
        }
    }

    function _getDisplayHeight() {
        var total = 0
        for (var i=0; i<children.length; i++) {
            var childItem = children[i]
            if (childItem.visible && childItem.width > 0 && childItem.height > 0) {
                total += childItem.height
            }
        }
        return total
    }

    function _foreachMenuItem(func) {
        var menuItemIndex = 0
        for (var i=0; i<children.length; i++) {
            if (children[i].hasOwnProperty("__silica_menuitem")) {
                if (!func(children[i], menuItemIndex)) {
                    return
                }
                menuItemIndex++
            }
        }
    }

    Connections {
        target: _flickable
        onContentYChanged: _flickableMoved = true
    }

    Connections {
        target: _parentMouseArea
        onPositionChanged: _updatePosition(contentColumn.mapFromItem(_parentMouseArea, mouse.x, mouse.y).y)
        onReleased: contextMenu.released(mouse)
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.highlightBackgroundColor
        opacity: Theme.highlightBackgroundOpacity
        InverseMouseArea {
            anchors.fill: parent
            enabled: active && _closeOnOutsideClick
            stealPress: true
            onPressedOutside: hide()
        }

        // We used to use a Binding to change interactive, but it was affected by
        // https://bugreports.qt-project.org/browse/QTBUG-33444
        states: State {
            when: contextMenu._open && contextMenu._flickable !== null
            PropertyChanges {
                target: contextMenu._flickable
                interactive: false
                contentY: contextMenu._flickableContentY
            }
        }
    }

    HighlightBar {
        id: highlightBar
    }

    Column {
        id: contentColumn
        width: parent.width
        anchors.bottom: parent.bottom
    }

    Timer {
        id: delayedHiding
        interval: 10
        onTriggered: contextMenu.hide()
    }

    property real _displayHeight: active && contentColumn.height > 0 ? _getDisplayHeight() : 0
    Behavior on _displayHeight {
        NumberAnimation {
            duration: contextMenu._openAnimationDuration
            easing.type: Easing.InOutQuad
        }
    }

    property real _flickableContentYAtOpen
    property real _flickableContentY: _flickable ? Math.max(contextMenu.mapToItem(_flickable.contentItem, 0, _displayHeight).y - _flickable.height, _flickableContentYAtOpen) : 0

    Component.onDestruction: {
        if (active) {
            RemorseItem.activeChanged(contextMenu, false)
        }
        // This guarantees that the interactive property of the flickable
        // is restored back to its original state.
        _open = false
    }
}
