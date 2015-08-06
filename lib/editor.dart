library cmdr_editor;

import 'dart:io';
import 'dart:convert';
import 'dart:isolate';

import 'package:upcom-api/tab_backend.dart';
import 'package:upcom-api/ros.dart';

class CmdrEditor extends Tab {
  static final List<String> names = ['upcom-editor', 'UpDroid Editor', 'Editor'];

  Directory uproot;

  Workspace _currentWorkspace;
  final String _explorerRefName = 'upcom-explorer';

  CmdrEditor(SendPort sp, List args) :
  super(CmdrEditor.names, sp, args) {
    uproot = new Directory(args[2]);
  }

  void registerMailbox() {
    mailbox.registerMessageHandler('SAVE_FILE', _saveFile);
    mailbox.registerMessageHandler('REQUEST_SELECTED', _requestSelected);
    mailbox.registerMessageHandler('OPEN_FILE', _openFile);
    mailbox.registerMessageHandler('OPEN_TEXT', _openText);
    mailbox.registerMessageHandler('SET_CURRENT_WORKSPACE', _setCurrentWorkspace);
    mailbox.registerMessageHandler('RETURN_SELECTED', _returnSelected);
  }

  void _openFile(String um) {
    var fileToOpen = new File(um);
    fileToOpen.readAsString().then((String contents) {
      mailbox.send(new Msg('OPEN_FILE', um + '[[CONTENTS]]' + contents));
    });
  }

  void _openText(String um) {
    mailbox.send(new Msg('OPEN_FILE', um + '[[CONTENTS]]' + um));
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
    mailbox.relay(_explorerRefName, -1, newMessage);
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