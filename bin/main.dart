import 'dart:isolate';
import 'package:upcom-api/tab_backend.dart';
import '../lib/editor.dart';

void main(List args, SendPort interfacesSendPort) {
  Tab.main(interfacesSendPort, args, (port, args) => new CmdrEditor(port, args));
}