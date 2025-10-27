typedef PluginFunction<T> = dynamic Function(dynamic editor, [T? options]);

typedef UsePlugin = void Function<T>(PluginFunction<T> pluginFunction, [T? options]);
