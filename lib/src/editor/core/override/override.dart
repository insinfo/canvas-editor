import 'package:canvas_text_editor/src/dom/dom.dart';

/// Provides hook points that allow consumers to override default behaviours
/// like paste, copy, or drag-and-drop.
class Override {
	Override({this.paste, this.copy, this.drop});

	Object? Function([ClipboardEvent? evt])? paste;
	Object? Function()? copy;
	Object? Function(MouseEvent evt)? drop;
}