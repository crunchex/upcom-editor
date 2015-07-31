library updroid_editor;

import 'dart:html';
import 'dart:async';
import 'dart:convert';

import 'package:upcom-api/tab_frontend.dart';
import 'package:ace/proxy.dart';
import 'package:ace/ace.dart' as ace;
import "package:path/path.dart" as pathLib;

part 'templates.dart';

/// [UpDroidEditor] is a wrapper for an embedded Ace Editor. Sets styles
/// for the editor and an additional menu bar with some filesystem operations.
class UpDroidEditor extends TabController {
  static final List<String> names = ['upcom-editor', 'UpDroid Editor', 'Editor'];

  static List<String> getThemes() {
    return ace.Theme.THEMES.where((String s) {
      return s != 'chrome' && s != 'clouds' && s != 'dreamweaver' && s != 'xcode' && s != 'textmate'
      && s != 'github' && s != 'eclipse' && s != 'crimson' && s != 'dawn' && s != 'vibrant_ink'
      && s != 'github' && s != 'eclipse' && s != 'crimson' && s != 'dawn' && s != 'vibrant_ink';
    });
  }

  static List<String> prettyThemeNames() {
    List<String> themes = [];
    getThemes().forEach((String s) => themes.add(s.toLowerCase().replaceAll('_', ' ')));
    return themes;
  }

  static List getMenuConfig() {
    List menu = [
      {'title': 'File', 'items': [
        {'type': 'submenu', 'title': 'New...', 'items':
          ['Blank', 'Publisher', 'Subscriber', 'Basic Launch File']},
        {'type': 'submenu', 'title': 'Examples', 'items':
          ['Hello World Talker', 'Hello World Listener']},
        {'type': 'toggle', 'title': 'Save'},
        {'type': 'toggle', 'title': 'Save As'},
        {'type': 'toggle', 'title': 'Close Tab'}]},
      {'title': 'Settings', 'items': [
        {'type': 'submenu', 'title': 'Theme...', 'items': prettyThemeNames()},
        {'type': 'input', 'title': 'Font Size'}]}
    ];
    return menu;
  }

  static const int _defaultFontSize = 12;

  AnchorElement _blankButton, _launchButton, _talkerButton, _listenerButton, _pubButton, _subButton;
  AnchorElement _saveButton, _saveAsButton;
  InputElement _fontSizeInput;
  ScriptElement _aceJs;

  // Stream Subscriptions.
  List<StreamSubscription> _subs;
  StreamSubscription _fontInputListener;

  ace.Editor _aceEditor;
  var _curModal;
  String _openFilePath, _originalContents;
  bool _exec;

  UpDroidEditor(ScriptElement script) :
  super(UpDroidEditor.names, getMenuConfig(), 'tabs/upcom-editor/editor.css') {
    _aceJs = script;
  }

  void setUpController() {
    _blankButton = view.refMap['blank-button'];
    _pubButton = view.refMap['publisher-button'];
    _subButton = view.refMap['subscriber-button'];
    _launchButton = view.refMap['basic-launch-file-button'];
    _talkerButton = view.refMap['hello-world-talker-button'];
    _listenerButton = view.refMap['hello-world-listener-button'];
    _saveButton = view.refMap['save'];
    _saveAsButton = view.refMap['save-as'];
    _fontSizeInput = view.refMap['font-size'];

    ace.implementation = ACE_PROXY_IMPLEMENTATION;
    ace.BindKey ctrlS = new ace.BindKey(win: "Ctrl-S", mac: "Command-S");
    ace.Command save = new ace.Command('save', ctrlS, (d) => _saveHandler());

    DivElement aceDiv = new DivElement()
    // Necessary to allow our styling (in main.css) to override Ace's.
      ..classes.add('upcom-editor');
    view.content.children.add(aceDiv);

    _aceEditor = ace.edit(aceDiv)
      ..session.mode = new ace.Mode.named(ace.Mode.PYTHON)
      ..fontSize = _defaultFontSize
      ..theme = new ace.Theme.named(ace.Theme.KUROIR)
      ..commands.addCommand(save);

    _fontSizeInput.placeholder = _defaultFontSize.toString();

    _updateOpenFilePath(null);
    _exec = false;
    _resetSavePoint();
  }

  void registerMailbox() {
    mailbox.registerWebSocketEvent(EventType.ON_MESSAGE, 'OPEN_FILE', _openFileHandler);
  }

  void registerEventHandlers() {
    _subs = [];

    _subs.add(_blankButton.onClick.listen((e) => _newFileHandler(e, '')));
    _subs.add(_talkerButton.onClick.listen((e) => _newFileHandler(e, RosTemplates.talkerTemplate)));
    _subs.add(_listenerButton.onClick.listen((e) => _newFileHandler(e, RosTemplates.listenerTemplate)));
    _subs.add(_launchButton.onClick.listen((e) => _newFileHandler(e, RosTemplates.launchTemplate)));
    _subs.add(_pubButton.onClick.listen((e) => _newFileHandler(e, RosTemplates.pubTemplate)));
    _subs.add(_subButton.onClick.listen((e) => _newFileHandler(e, RosTemplates.subTemplate)));

    _subs.add(_saveButton.onClick.listen((e) => _saveHandler()));
    _subs.add(_saveAsButton.onClick.listen((e) => _saveAsHandler()));

//    _subs.add(_themeButton.onClick.listen((e) => _invertTheme(e)));
    _subs.add(_fontSizeInput.onClick.listen((e) => _updateFontSize(e)));

    _subs.add(_aceEditor.onChange.listen((e) => _updateUnsavedChangesIndicator()));

    getThemes().forEach((String fontName) {
      String mapName = fontName.toLowerCase().replaceAll('_', '-');
      Element fontButton = view.refMap['$mapName-button'];
      _subs.add(fontButton.onClick.listen((e) => _setTheme(e, fontName)));
    });
  }

  // Mailbox Handlers

  /// Editor receives the open file contents from the server.
  void _openFileHandler(Msg um) {
    List<String> returnedData = um.body.split('[[CONTENTS]]');
    String newPath = returnedData[0];
    String newText = returnedData[1];

    _handleAnyChanges().then((_) {
      _updateOpenFilePath(newPath);
      _setEditorText(newText);
    });
  }

  // Event Handlers

  void _newFileHandler(Event e, String newText) {
    e.preventDefault();

    _handleAnyChanges().then((_) {
      _updateOpenFilePath(null);
      _setEditorText(newText);
    });
  }

  void _saveHandler() {
    if (_noUnsavedChanges()) return;

    if (_openFilePath != null) {
      _saveFile();
      return;
    }

    // _openFilePath is null, so we need to run the Save-As routine.
    _updatePathAndExec().then((bool completeSave) {
      if (completeSave) _saveFile();
    });
  }

  void _saveAsHandler() {
    _updatePathAndExec().then((bool completeSave) {
      if (completeSave) _saveFile();
    });
  }

  void _setTheme(Event e, String themeName) {
    // Stops the button from sending the page to the top (href=#).
    e.preventDefault();
    _aceEditor.theme = new ace.Theme.named(themeName);
  }

  void _updateFontSize(Event e) {
    // Keeps bootjack dropdown from closing
    e.stopPropagation();

    _fontInputListener = _fontSizeInput.onKeyUp.listen((e) {
      if (e.keyCode != KeyCode.ENTER) return;

      try {
        var fontVal = int.parse(_fontSizeInput.value);
        assert(fontVal is int);
        if (fontVal >= 1 && fontVal <= 60) {
          _aceEditor.fontSize = fontVal;
          _fontSizeInput.placeholder = fontVal.toString();
        }
      } finally {
        _fontSizeInput.value = "";
        _aceEditor.focus();
        _fontInputListener.cancel();
      }
    });
  }

  /// Adds an asterisk to the displayed filename if there are any unsaved changes.
  void _updateUnsavedChangesIndicator() {
    bool noUnsavedChanges = _noUnsavedChanges();
    print('noUnsavedChanges: ${noUnsavedChanges.toString()}');
    print('ace text: ${_aceEditor.value} ==  original text: ${_originalContents}');
    if (noUnsavedChanges) {
      if (view.extra.text.contains('*')) view.extra.text = view.extra.text.substring(0, view.extra.text.length - 1);
      return;
    }

    print('adding *');
    if (!view.extra.text.contains('*')) view.extra.text = view.extra.text + '*';
    print('new view.extra.text: ${view.extra.text}');
  }

  // Misc Private Methods

  /// Detects if there are any unsaved changes and if there are, goes through
  /// the modals and handles them.
  Future _handleAnyChanges() async {
    Completer c = new Completer();

    if (_noUnsavedChanges()) {
      c.complete();
    } else {
      bool continueSave = await _presentUnsavedChangesModal();
      if (!continueSave) {
        c.complete();
      } else {
        bool completeSave = await _updatePathAndExec();
        if (completeSave) _saveFile();
        c.complete();
      }
    }

    return c.future;
  }

  /// Updates the open file path and exec globals based on user input.
  Future<bool> _updatePathAndExec() async {
    Completer c = new Completer();

    String path = await _getSelectedPath();
    if (path == null) {
      window.alert('Please choose one directory from Explorer and retry.');
      c.complete(false);
    } else {
      c.complete(await _presentSaveAsModal(path));
    }

    return c.future;
  }

  /// Queries an open Explorer for a selected directory (for saving to).
  Future<String> _getSelectedPath() async {
    Completer c = new Completer();

    Msg um = await mailbox.waitFor(new Msg('REQUEST_SELECTED', ''));
    List<String> selectedPaths = JSON.decode(um.body);
    if (selectedPaths.length != 1) {
      c.complete(null);
    } else {
      c.complete(pathLib.normalize(selectedPaths[0]));
    }

    return c.future;
  }

  /// Presents the Modal that asks the user what to do with unsaved changes.
  Future<bool> _presentUnsavedChangesModal() {
    Completer c = new Completer();

    if (_curModal != null) {
      _curModal.hide();
      _curModal = null;
    }

    _curModal = new UpDroidUnsavedModal();
    List<StreamSubscription> subs = [];

    subs.add(_curModal.saveButton.onClick.listen((e) {
      subs.forEach((StreamSubscription sub) => sub.cancel());
      _curModal.hide();
      c.complete(true);
    }));

    subs.add(_curModal.discardButton.onClick.listen((e) {
      subs.forEach((StreamSubscription sub) => sub.cancel());
      _curModal.hide();
      c.complete(false);
    }));

    return c.future;
  }

  /// Presents a modal to get a new filename and make-executable option from the user.
  Future<bool> _presentSaveAsModal(path) {
    Completer c = new Completer();

    if (_curModal != null) {
      _curModal.hide();
      _curModal = null;
    }

    _curModal = new UpDroidSavedModal();
    List<StreamSubscription> subs = [];

    subs.add(_curModal.saveButton.onClick.listen((e) {
      if (_curModal.input.value == '') return;

      _updateOpenFilePath(pathLib.normalize(path + '/' + _curModal.input.value));
      _exec = _curModal.makeExec.checked;
      subs.forEach((StreamSubscription sub) => sub.cancel());
      _curModal.hide();
      c.complete(true);
    }));

    subs.add(_curModal.discardButton.onClick.listen((e) {
      subs.forEach((StreamSubscription sub) => sub.cancel());
      _curModal.hide();
      c.complete(false);
    }));

    return c.future;
  }

  /// Saves the file to disk and optionally makes it executable, based on the current values
  /// of the global variables. Also updates the save point and displayed filename.
  void _saveFile() {
    if (_openFilePath == null || _openFilePath == '') return;

    mailbox.ws.send(new Msg('SAVE_FILE', JSON.encode([_aceEditor.value, _openFilePath, _exec])).toString());
    _updateUnsavedChangesIndicator();
    _resetSavePoint();
  }

  /// Sets the Editor's text with [newText], and resets other stuff.
  void _setEditorText(String newText) {
    _aceEditor.setValue(newText, 1);
    _exec = false;
    _resetSavePoint();

    // Set focus to the interactive area so the user can typing immediately.
    _aceEditor.focus();
    _aceEditor.scrollToLine(0);
  }

  /// Compares the Editor's current text with text at the last save point.
  bool _noUnsavedChanges() => _aceEditor.value == _originalContents;

  /// Resets the save point based on the Editor's current text.
  String _resetSavePoint() => _originalContents = _aceEditor.value;

  /// Keeps the displayed filename in sync with the current open file.
  void _updateOpenFilePath(String newPath) {
    _openFilePath = newPath;

    if (_openFilePath == null || _openFilePath == '') {
      view.extra.text = 'untitled';
    } else {
      view.extra.text = pathLib.basename(_openFilePath);
    }

    hoverText = view.extra.text;
  }

  Element get elementToFocus => view.content.children[0].querySelector('.ace_text-input');

  Future<bool> preClose() {
    return _handleAnyChanges().then((_) => true);
  }

  void cleanUp() {
    _subs.forEach((StreamSubscription sub) => sub.cancel());
    if (_fontInputListener != null) _fontInputListener.cancel();
    _aceJs.remove();
  }
}