import 'dart:async';
import 'package:flutter/material.dart';

/// A dependency injection container for managing [ModelNotifier] instances.
///
/// This singleton class handles registration and retrieval of notifiers,
/// supporting global and scoped lifecycles. Use it to centralize state
/// management in your app.
///
/// 💡 Tip: Register all notifiers in `main.dart` before running the app.
///
/// Example:
/// ```dart
/// void main() {
///   final locator = ModelLocator.instance;
///   locator.registerScoped<AppModel>(
///     () => ModelNotifier(AppModel(0, false)),
///   );
///   runApp(MyApp());
/// }
/// ```
class ModelLocator {
  /// Private constructor for singleton pattern.
  ModelLocator._internal();

  /// The single instance of [ModelLocator].
  static final ModelLocator _instance = ModelLocator._internal();

  /// Factory constructor returning the singleton instance.
  factory ModelLocator() => _instance;

  /// Getter for the singleton instance.
  static ModelLocator get instance => _instance;

  /// Internal map for storing active notifier instances.
  final Map<Type, dynamic> _models = {};

  /// Internal map for lazy builders.
  final Map<Type, dynamic Function()> _lazyBuilders = {};

  /// Internal map tracking scoped registrations.
  final Map<Type, bool> _isScoped = {};

  /// Registers a global notifier instance eagerly.
  ///
  /// The instance persists for the app lifecycle and isn't auto-disposed.
  ///
  /// ⚠️ Warning: Register source notifiers before dependents to avoid errors.
  ///
  /// Example:
  /// ```dart
  /// locator.registerGlobal<AppModel>(ModelNotifier(AppModel(0, false)));
  /// ```
  void registerGlobal<M>(ModelNotifier<M> instance) {
    final type = ModelNotifier<M>;
    if (_models.containsKey(type) || _lazyBuilders.containsKey(type)) {
      throw Exception('Model $type is already registered');
    }
    _models[type] = instance;
  }

  /// Registers a lazy global notifier builder.
  ///
  /// Created on first [get]; persists app-wide.
  ///
  /// 💡 Tip: Use for heavy initializations to optimize startup.
  ///
  /// Example:
  /// ```dart
  /// locator.registerGlobalLazy<AppModel>(() => ModelNotifier(AppModel(0, false)));
  /// ```
  void registerGlobalLazy<M>(ModelNotifier<M> Function() builder) {
    final type = ModelNotifier<M>;
    if (_models.containsKey(type) || _lazyBuilders.containsKey(type)) {
      throw Exception('Model $type is already registered');
    }
    _lazyBuilders[type] = builder;
  }

  /// Registers a scoped notifier builder (always lazy).
  ///
  /// Auto-disposed when no subscribers remain; recreated on next access.
  ///
  /// ⚠️ Warning: For scoped, fetch inside [Watch] to tie lifecycle correctly.
  ///
  /// Example:
  /// ```dart
  /// locator.registerScoped<AppModel>(() => ModelNotifier(AppModel(0, false)));
  /// ```
  void registerScoped<M>(ModelNotifier<M> Function() builder) {
    final type = ModelNotifier<M>;
    if (_models.containsKey(type) || _lazyBuilders.containsKey(type)) {
      throw Exception('Model $type is already registered');
    }
    _lazyBuilders[type] = builder;
    _isScoped[type] = true;
  }

  /// Retrieves the notifier for model type [M].
  ///
  /// Lazily creates if needed; throws if not registered.
  ///
  /// 💡 Tip: Always call inside [Watch] builder for auto-subscription.
  ///
  /// Example:
  /// ```dart
  /// final notifier = locator.get<AppModel>();
  /// ```
  ModelNotifier<M> get<M>() {
    final type = ModelNotifier<M>;
    if (_models.containsKey(type)) {
      return _models[type] as ModelNotifier<M>;
    } else if (_lazyBuilders.containsKey(type)) {
      final instance = _lazyBuilders[type]!() as ModelNotifier<M>;
      _models[type] = instance;
      final isScoped = _isScoped[type] ?? false;
      if (isScoped) {
        instance._setScopedType(type);
      }
      if (!isScoped) {
        _lazyBuilders.remove(type);
      }
      return instance;
    } else {
      throw Exception('Model $type is not registered');
    }
  }

  /// Internal: Removes a notifier by type (for scoped disposal).
  void _remove(Type type) {
    _models.remove(type);
  }

  /// Resets all registrations; useful for testing.
  ///
  /// ⚠️ Warning: Does not dispose existing instances; handle manually if needed.
  ///
  /// Example:
  /// ```dart
  /// locator.reset();
  /// ```
  void reset() {
    _models.clear();
    _lazyBuilders.clear();
    _isScoped.clear();
  }
}

/// A reactive widget that auto-subscribes to accessed notifiers.
///
/// Rebuilds when subscribed notifiers change; nest for granularity.
///
/// 💡 Tip: Access [model] inside [builder] for automatic reactivity.
///
/// Example:
/// ```dart
/// Watch(
///   (context) {
///     final notifier = locator.get<AppModel>();
///     return Text('${notifier.model.count}');
///   },
/// )
/// ```
class Watch extends StatefulWidget {
  /// Builder function for the child widget.
  ///
  /// Fetch notifiers and access models here.
  final Widget Function(BuildContext context) builder;

  /// Creates a [Watch] with the given [builder].
  const Watch(this.builder, {super.key});

  @override
  State<Watch> createState() => WatchState();
}

/// Internal zone key for context propagation.
final _watchZoneKey = Object();

/// Internal state for [Watch]; manages subscriptions.
///
/// ⚠️ Warning: Do not use directly; it's an implementation detail.
class WatchState extends State<Watch> {
  /// Internal subscribed notifiers.
  final Set<ChangeNotifier> _notifiers = {};

  /// Adds a notifier subscription.
  void addNotifier(ChangeNotifier notifier) {
    if (_notifiers.add(notifier)) {
      notifier.addListener(_update);
    }
  }

  /// Rebuilds if mounted.
  void _update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (var notifier in _notifiers) {
      notifier.removeListener(_update);
      if (notifier is ModelNotifier) {
        notifier._removeWatch(this);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = runZoned<Widget>(
      () => widget.builder(context),
      zoneValues: {_watchZoneKey: this},
    );
    return result;
  }
}

/// State holder for immutable models; notifies on changes.
///
/// 💡 Tip: Use extensions for methods; do not subclass (final class).
///
/// Example:
/// ```dart
/// final notifier = ModelNotifier(AppModel(0, false));
/// notifier.model = notifier.model.copyWith(count: 1);
/// ```
final class ModelNotifier<T> extends ChangeNotifier {
  /// Creates a notifier with initial model; notifies immediately.
  ///
  /// ⚠️ Warning: Provide a fully initialized model to avoid nulls.
  ModelNotifier(this.initial) {
    _model = initial;
    notifyListeners();
  }

  /// The initial model value.
  final T initial;

  /// Internal current model storage.
  late T _model;

  /// Internal subscriber tracking.
  final Set<WatchState> _subscribers = {};

  /// Internal scoped type for disposal.
  Type? _scopedType;

  /// Internal scoped type setter.
  void _setScopedType(Type type) {
    _scopedType = type;
  }

  /// Internal computing notifier context.
  static ModelNotifier? _currentComputingNotifier;

  /// Computes a value, auto-subscribing to accessed notifiers.
  ///
  /// 💡 Tip: Use for derived state in dependencies.
  ///
  /// Example:
  /// ```dart
  /// final derived = compute(() {
  ///   return otherNotifier.model.value * 2;
  /// });
  /// ```
  R compute<R>(R Function() computation) {
    final previous = _currentComputingNotifier;
    _currentComputingNotifier = this;
    final result = computation();
    _currentComputingNotifier = previous;
    return result;
  }

  /// Gets the current model; subscribes if in [Watch].
  T get model {
    final currentWatch = Zone.current[_watchZoneKey] as WatchState?;
    if (currentWatch != null) {
      currentWatch.addNotifier(this);
      _subscribers.add(currentWatch);
    }
    return _model;
  }

  /// Sets new model and notifies.
  ///
  /// ⚠️ Warning: Use immutable copies to avoid side effects.
  set model(T newModel) {
    _model = newModel;
    notifyListeners();
  }

  /// Internal subscriber removal.
  void _removeWatch(WatchState subscriber) {
    _subscribers.remove(subscriber);
    if (_subscribers.isEmpty && !_disposed) {
      dispose();
    }
  }

  /// Internal disposed flag.
  bool _disposed = false;

  /// Disposes; handles scoped removal.
  ///
  /// 💡 Tip: Override for custom cleanup, but call super.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
    if (_scopedType != null) {
      ModelLocator.instance._remove(_scopedType!);
    }
  }
}

/// Alias for async results returning [Result].
///
/// Example:
/// ```dart
/// AsyncResult<int, String> fetch() async => Ok(42);
/// ```
typedef AsyncResult<T, E> = Future<Result<T, E>>;

/// Sealed result type: success ([Ok]) or failure ([Error]).
///
/// 💡 Tip: Use switch for pattern matching.
///
/// Example:
/// ```dart
/// switch (result) {
///   case Ok(:final value): print(value);
///   case Error(:final error): print(error);
/// }
/// ```
sealed class Result<O, E> {}

/// Success result with value.
class Ok<O, E> extends Result<O, E> {
  /// Creates success with [value].
  Ok(this.value);

  /// The success value.
  final O value;
}

/// Failure result with error.
class Error<O, E> extends Result<O, E> {
  /// Creates failure with [error].
  Error(this.error);

  /// The error value.
  final E error;
}
