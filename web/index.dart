import 'dart:html';
import 'editor.dart';

void main() {
  ScriptElement aceJs = new ScriptElement()
    ..type = 'text/javascript'
    ..src = 'tabs/upcom-editor/src-min-noconflict/ace.js';
  document.body.children.add(aceJs);

  aceJs.onLoad.first.then((_) {
    new UpDroidEditor(aceJs);
  });
}