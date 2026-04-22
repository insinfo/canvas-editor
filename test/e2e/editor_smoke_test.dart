import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:test/test.dart';

part 'support/editor_e2e_support.dart';
part 'editor_e2e_shell.dart';
part 'editor_e2e_keyboard.dart';
part 'editor_e2e_image.dart';
part 'editor_e2e_table.dart';
part 'editor_e2e_latex_clipboard.dart';
part 'editor_e2e_annotations.dart';
part 'editor_e2e_controls.dart';
part 'editor_e2e_toolbar.dart';
part 'editor_e2e_misc.dart';

void main() {
  group('Canvas editor app E2E', () {
    _registerHarnessLifecycle();
    _registerShellE2ETests();
    _registerKeyboardE2ETests();
    _registerImageE2ETests();
    _registerTableE2ETests();
    _registerMiscE2ETests();
  });
}