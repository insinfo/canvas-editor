import '../../index.dart';
import '../../interface/plugin.dart';

class Plugin {
	Plugin(this.editor);

	final Editor editor;

	void use<T>(PluginFunction<T> pluginFunction, [T? options]) {
		pluginFunction(editor, options);
	}
}