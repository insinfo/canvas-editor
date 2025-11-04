import '../core/command/command.dart';
import '../core/event/eventbus/event_bus.dart';
import '../core/listener/listener.dart';
import '../core/override/override.dart';
import '../core/register/register.dart';
import 'event_bus.dart';

abstract class IPluginHost {
  Command get command;
  Listener get listener;
  EventBus<EventBusMap> get eventBus;
  Override get override;
  Register get register;
  void Function() get destroy;
  UsePlugin get use;
}

typedef PluginFunction<T> = Object? Function(IPluginHost editor, [T? options]);

typedef UsePlugin = void Function<T>(
  PluginFunction<T> pluginFunction, [
  T? options,
]);
