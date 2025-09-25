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

3. **Register Notifiers**  
   In `main.dart`, register via `ModelLocator`.  
   ```dart
   void main() {
     final locator = ModelLocator.instance;
     locator.registerScoped<AppModel>(
       () => ModelNotifier(AppModel(0, false)),
     );
     runApp(MyApp());
   }
   ```

4. **Add Methods via Extensions**  
   Extend `ModelNotifier<YourModel>` for logic.  
   ```dart
   extension AppExtensions on ModelNotifier<AppModel> {
     AsyncResult<AppModel, Object> increment() async {
       model = model.copyWith(isLoading: true);
       await Future.delayed(Duration(seconds: 1));
       model = model.copyWith(count: model.count + 1, isLoading: false);
       return Ok(model);
     }
   }
   ```

5. **Use in Widgets**  
   Fetch inside `Watch` builder; access `model` for reactivity.  
   ```dart
   Watch(
     (_) {
       final notifier = ModelLocator.instance.get<AppModel>();
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
- **ModelNotifier<T>**: Final class holding immutable state. Use getter/setter for `model`; notifies on changes.
- **AsyncResult & Result**: Type alias and sealed class for async ops with `Ok`/`Error`.

### Handling Transient States and Errors
Transient states (e.g., loading, computing) are modeled directly in the immutable model class, avoiding conditional hell like exhaustive checks or pattern matching across fragmented states. This keeps logic simple: Update via `copyWith` in extension methods, and the UI reacts uniformly via `Watch`.

ModelNotifiers require an initial state on instantiation, reducing initialization complexity. Avoid optionals/nulls by initializing models in `main.dart`—make async calls there if needed, then pass resolved data to the notifier. This ensures safe access without runtime checks.

For errors, methods return `Result` (Ok/Error). Call from the UI layer to handle flexibly (e.g., toast, dialog), keeping errors separate from transient states—no mashing into one mega-model. This prevents spaghetti code while maintaining separation of concerns.

### Recommended File Structure
Organize your code for clarity: Place model classes (data/state) in a `models/` folder and notifier extensions in a `notifiers/` folder. Example structure:  
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
- Add methods via extensions.
- Register source notifiers before dependents.
- Remove listeners in `dispose` for cross-notifier deps.

**DON'Ts**:
- Subclass `ModelNotifier` (it's final).
- Mutate models directly; always use `copyWith`.
- Declare scoped notifier variables outside `Watch`.
- Create cyclic dependencies between models.
- Forget to handle `Result` in async calls.
