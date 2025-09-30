# ModelNotifier: Lightweight MVU-Inspired State Management for Flutter
ModelNotifier is a minimalistic Flutter package for reactive state management, emphasizing immutability, automatic subscriptions, and scoped lifecycles. It integrates dependency injection via `ModelLocator`, reactive widgets with `Watch`, and pure state holders in `ModelNotifier<T>`.

## Getting Started

1. **Add Dependency**  
   Add to `pubspec.yaml`:  
   ```yaml
   dependencies:
     model_notifier: ^0.1.0  # Replace with latest version
   ```  
   Run `flutter pub get`.

2. **Define an Immutable Model**  
   Create a model class with `copyWith` for updates.  
   ```dart
   class AppModel {
     final int count;
     final bool isLoading;
     AppModel(this.count, this.isLoading);
     AppModel copyWith({int? count, bool? isLoading}) =>
         AppModel(count ?? this.count, isLoading ?? this.isLoading);
   }
   ```  
   **HINT**: Think about the state you want, model it, and then write simple functions to deal with that state. Include loading states as part of the model for sane transient handling.

3. **Create a Notifier Implementation**
   Extend `ModelNotifier` for your specific model and add methods directly.
   ```dart
   class AppModelNotifier extends ModelNotifier<AppModel> {
     AppModelNotifier(super.initial);

     Future<void> increment() async {
       model = model.copyWith(isLoading: true);
       await Future.delayed(Duration(seconds: 1));
       model = model.copyWith(count: model.count + 1, isLoading: false);
     }
   }
   ```

4. **Register Notifiers**
   In `main.dart`, register via `ModelLocator`.
   ```dart
   void main() {
     final locator = ModelLocator.instance;
     locator.registerScoped<AppModelNotifier>(
       () => AppModelNotifier(AppModel(0, false)),
     );
     runApp(MyApp());
   }
   ```

4. **Use in Widgets**
   Fetch inside `Watch` builder; access `model` for reactivity.
   ```dart
   Watch(
     (_) {
       final notifier = ModelLocator.instance.get<AppModelNotifier>();
       return Column(
         children: [
           Text('${notifier.model.count}'),
           if (notifier.model.isLoading) CircularProgressIndicator(),
           ElevatedButton(
             onPressed: () async => await notifier.increment(),
             child: Text('Increment'),
           ),
         ],
       );
     },
   )
   ```

## Comprehensive Breakdown

### Core Components
- **ModelLocator**: Singleton DI for registering/retrieving notifiers. Supports global (persistent) and scoped (auto-dispose on unsubscribed) lifecycles.
- **Watch**: Stateful widget that auto-subscribes to accessed notifiers during build, enabling granular rebuilds. Nest for optimization.
- **ModelNotifier<T>**: Abstract class holding immutable state. Extend for specific models. Use getter/setter for `model`; notifies on changes.

### Handling Transient States and Errors
Transient states (e.g., loading, computing) are modeled directly in the immutable model class, avoiding conditional hell like exhaustive checks or pattern matching across fragmented states. This keeps logic simple: Update via `copyWith` in notifier methods, and the UI reacts uniformly via `Watch`.

ModelNotifiers require an initial state on instantiation, reducing initialization complexity. Avoid optionals/nulls by initializing models in `main.dart`—make async calls there if needed, then pass resolved data to the notifier. This ensures safe access without runtime checks.

For errors, handle them directly in your notifier methods using try/catch blocks and update the model state accordingly, or use standard Dart error handling patterns.

### Recommended File Structure
Organize your code for clarity: Place model classes (data/state) in a `models/` folder and notifier implementations in a `notifiers/` folder. Example structure:
```
lib
├── main.dart
├── models
│   ├── theme_state.model.dart
│   ├── todo_state.model.dart
│   └── todo.model.dart
└── notifiers
    ├── theme_state.notifier.dart
    └── todo_state.notifier.dart
```

### Advanced Usage
- **Inter-Model Dependencies**: Use `addListener` manually or a `compute` method for automatic watching.  
  Example `compute`:  
  ```dart
  R compute<R>(R Function() computation) {
    // Setup zone/context for auto-subscription...
  }
  ```
- **Navigation & Scopes**: Scoped notifiers reinitialize on widget recreation; declare inside `Watch`.
- **Testing**: Call `reset()` to clear registrations.

### DO's and DON'Ts
**DO's**:
- Use immutable models with `copyWith`.
- Fetch notifiers inside `Watch` builders.
- Add methods directly to your notifier classes.
- Register source notifiers before dependents.
- Remove listeners in `dispose` for cross-notifier deps.
- Extend `ModelNotifier` for your specific models.

**DON'Ts**:
- Instantiate `ModelNotifier` directly (it's abstract).
- Mutate models directly; always use `copyWith`.
- Declare scoped notifier variables outside `Watch`.
- Create cyclic dependencies between models.
- Forget error handling in async methods.
