library cmdr_editor;

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:isolate';

import 'package:path/path.dart';
import 'package:upcom-api/tab_backend.dart';
import 'package:upcom-api/ros.dart';

class CmdrEditor extends Tab {
  static final List<String> names = ['upcom-editor', 'UpDroid Editor', 'Editor'];

  Directory uproot;

  Workspace _currentWorkspace;
  String _runningNodeName;
  Process _runningNode;
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
    mailbox.registerMessageHandler('RUN_FILE', _runFile);
    mailbox.registerMessageHandler('STOP_FILE', _stopFile);
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
    mailbox.send(new Msg('OPEN_TEXT', um));
  }

  void _runFile(String um) {
    String filePath = um;
    File file = new File(normalize(filePath));

    // Make sure the file has execute permissions.
    Process.run("chmod", ["u+x", file.path]).then((result) {
      if (result.exitCode != 0) throw new Exception(result.stderr);

      // Get the set of current running nodes for comparison later.
      Ros.listRunningNodes().then((List<String> oldList) {
        Set<String> oldSet = new Set.from(oldList);

        // Launch the node by simply executing the script.
        Process.start('$filePath', []).then((Process process) {
          _runningNode = process;

          Timer listTimer;
          listTimer = new Timer.periodic(new Duration(milliseconds: 500), (_) {
            // Get a new set of current running nodes.
            Ros.listRunningNodes().then((List<String> newList) {
              Set<String> newSet = new Set.from(newList);

              // Compare the before-and-after sets to get the name of the new node
              // and send it over.
              Set<String> diff = newSet.difference(oldSet);
              if (diff.isNotEmpty) listTimer.cancel();

              // We can assume the set only has one element, but not sure how
              // to access it without a loop.
              for (String nodeName in diff) {
                _runningNodeName = nodeName;
                Msg m = new Msg('NODE_FROM_EDITOR', nodeName);
                mailbox.relay(_explorerRefName, -1, m);
              }
            });
          });
        });
      });
    });
  }

  void _stopFile(String um) {
    if (_runningNode != null) _runningNode.kill();

    if (_runningNodeName != null) {
      Msg m = new Msg('KILL_NODE_FROM_EDITOR', _runningNodeName);
      mailbox.relay(_explorerRefName, -1, m);
    }
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
//    if (_runningNode != null) _runningNode.kill();
  }
}