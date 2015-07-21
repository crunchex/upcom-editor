library cmdr_editor;

import 'dart:io';
import 'dart:convert';
import 'dart:isolate';

import 'package:upcom-api/ros/ros.dart';
import 'package:upcom-api/tab.dart';
import 'package:upcom-api/updroid_message.dart';
import 'package:upcom-api/server_message.dart';
import 'package:upcom-api/server_helper.dart' as help;

class CmdrEditor extends Tab {
  Directory uproot;

  Workspace _currentWorkspace;

  CmdrEditor(int id, String workspacePath, SendPort sp) :
  super(id, 'UpDroidEditor', sp) {
    uproot = new Directory(workspacePath);
    mailbox.send(new Msg('TAB_READY'));
  }

  void registerMailbox() {
    mailbox.registerMessageHandler('SAVE_FILE', _saveFile);
    mailbox.registerMessageHandler('REQUEST_SELECTED', _requestSelected);
    mailbox.registerMessageHandler('OPEN_FILE', _openFile);
    mailbox.registerMessageHandler('SET_CURRENT_WORKSPACE', _setCurrentWorkspace);
    mailbox.registerMessageHandler('RETURN_SELECTED', _returnSelected);
  }

  void _openFile(String um) {
    var fileToOpen = new File(um);
    fileToOpen.readAsString().then((String contents) {
      mailbox.send(new Msg('OPEN_FILE', um + '[[CONTENTS]]' + contents));
    });
  }

  void _saveFile(String um) {
    List args = JSON.decode(um);
    // args[0] = data, args[1] = path. args[2] = executable option

    var fileToSave = new File(args[1]);

    fileToSave.writeAsString(args[0]);

    if (args[2] == true) {
      Process.run("chmod", ["u+x", fileToSave.path]).then((result) {
        if (result.exitCode != 0) throw new Exception(result.stderr);
      });
    }
  }

  void _requestSelected(String um) {
    Msg newMessage = new Msg('REQUEST_SELECTED', id.toString());
    mailbox.relay(new ServerMessage('UpDroidExplorer', -1, newMessage));
  }

  void _setCurrentWorkspace(String um) {
    _currentWorkspace = new Workspace('${uproot.path}/$um');
  }

  void _returnSelected(String um) {
    mailbox.send(new Msg('REQUEST_SELECTED', um));
  }

  void cleanup() {

  }
}

void main(List args, SendPort interfacesSendPort) {
  Tab.main(interfacesSendPort, args, (id, path, port, args) => new CmdrEditor(id, path, port));
}