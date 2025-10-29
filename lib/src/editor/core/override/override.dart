import 'dart:html';

/// Provides hook points that allow consumers to override default behaviours
/// like paste, copy, or drag-and-drop.
class Override {
	Override({this.paste, this.copy, this.drop});

	Object? Function([ClipboardEvent? evt])? paste;
	Object? Function()? copy;
	Object? Function(MouseEvent evt)? drop;
}