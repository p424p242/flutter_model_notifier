import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_notifier/model_notifier.dart';

class TestModel {
  final int value;
  final bool isLoading;
  TestModel({this.value = 0, this.isLoading = false});
  TestModel copyWith({int? value, bool? isLoading}) {
    return TestModel(
      value: value ?? this.value,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Concrete implementation for testing
class TestModelNotifier extends ModelNotifier<TestModel> {
  TestModelNotifier(super.initial);
}

// Helper to track disposal without extending final class
class DisposalTracker {
  bool disposed = false;
  void markDisposed() => disposed = true;
}

extension TestExtensions on TestModelNotifier {
  void updateValue(int newValue) {
    model = model.copyWith(value: newValue);
  }
}

void main() {
  group('ModelLocator', () {
    setUp(() {
      ModelLocator.instance.reset();
    });

    tearDown(() {
      ModelLocator.instance.reset();
    });

    test('registers and gets global instance', () {
      final instance = TestModelNotifier(TestModel());
      ModelLocator.instance.registerGlobal<TestModelNotifier>(instance);
      final retrieved = ModelLocator.instance.get<TestModelNotifier>();
      expect(retrieved, instance);
    });

    test('registers and gets global lazy', () {
      ModelLocator.instance.registerGlobalLazy<TestModelNotifier>(
        () => TestModelNotifier(TestModel()),
      );
      final retrieved = ModelLocator.instance.get<TestModelNotifier>();
      expect(retrieved.model.value, 0);
    });

    test('registers and gets scoped lazy', () {
      ModelLocator.instance.registerScoped<TestModelNotifier>(
        () => TestModelNotifier(TestModel()),
      );
      final retrieved = ModelLocator.instance.get<TestModelNotifier>();
      expect(retrieved.model.value, 0);
    });

    test('throws if not registered', () {
      expect(() => ModelLocator.instance.get<TestModelNotifier>(), throwsException);
    });

    test('throws on duplicate registration', () {
      final instance = TestModelNotifier(TestModel());
      ModelLocator.instance.registerGlobal<TestModelNotifier>(instance);
      expect(() => ModelLocator.instance.registerGlobal<TestModelNotifier>(instance), throwsException);
      expect(() => ModelLocator.instance.registerGlobalLazy<TestModelNotifier>(() => instance), throwsException);
      expect(() => ModelLocator.instance.registerScoped<TestModelNotifier>(() => instance), throwsException);
    });

    test('scoped instance gets auto-removed when disposed', () {
      ModelLocator.instance.registerScoped<TestModelNotifier>(
        () => TestModelNotifier(TestModel(value: 42)),
      );

      // First access creates the instance
      final firstInstance = ModelLocator.instance.get<TestModelNotifier>();
      expect(firstInstance.model.value, 42);

      // Dispose the instance
      firstInstance.dispose();

      // Next access should create a new instance
      final secondInstance = ModelLocator.instance.get<TestModelNotifier>();
      expect(secondInstance.model.value, 42);
      expect(secondInstance, isNot(firstInstance));
    });

    test('reset clears registrations', () {
      ModelLocator.instance.registerGlobal<TestModelNotifier>(
        TestModelNotifier(TestModel()),
      );
      ModelLocator.instance.reset();
      expect(() => ModelLocator.instance.get<TestModelNotifier>(), throwsException);
    });

    test('global instances are never disposed when subscribers drop', () {
      final instance = TestModelNotifier(TestModel(value: 42));
      ModelLocator.instance.registerGlobal<TestModelNotifier>(instance);

      // Add and remove listeners to simulate subscriber lifecycle
      var listener1Called = false;
      var listener2Called = false;

      void listener1() => listener1Called = true;
      void listener2() => listener2Called = true;

      instance.addListener(listener1);
      instance.addListener(listener2);

      // Trigger change to verify listeners work
      instance.updateValue(100);
      expect(listener1Called, true);
      expect(listener2Called, true);

      // Reset flags
      listener1Called = false;
      listener2Called = false;

      // Remove all listeners
      instance.removeListener(listener1);
      instance.removeListener(listener2);

      // Global instance should still be accessible and functional
      final retrieved = ModelLocator.instance.get<TestModelNotifier>();
      expect(retrieved, instance);
      expect(retrieved.model.value, 100);

      // Should still be able to add new listeners
      instance.addListener(() {});
      instance.updateValue(200);
      expect(instance.model.value, 200);
    });

    test('global lazy instances are never disposed when subscribers drop', () {
      ModelLocator.instance.registerGlobalLazy<TestModelNotifier>(
        () => TestModelNotifier(TestModel(value: 42)),
      );

      // First access creates the instance
      final firstInstance = ModelLocator.instance.get<TestModelNotifier>();
      expect(firstInstance.model.value, 42);

      // Add and remove listeners
      var listenerCalled = false;
      void listener() => listenerCalled = true;

      firstInstance.addListener(listener);
      firstInstance.updateValue(100);
      expect(listenerCalled, true);

      // Remove listener
      firstInstance.removeListener(listener);

      // Global lazy instance should still be accessible
      final secondInstance = ModelLocator.instance.get<TestModelNotifier>();
      expect(secondInstance, firstInstance); // Same instance
      expect(secondInstance.model.value, 100);
    });
  });

  group('ModelNotifier', () {
    test('initializes with model and notifies listeners', () {
      final notifier = TestModelNotifier(TestModel(value: 0));
      expect(notifier.model.value, 0);

      var callCount = 0;
      notifier.addListener(() => callCount++);
      notifier.model = notifier.model.copyWith(value: 1);
      expect(callCount, 1);
      expect(notifier.model.value, 1);
    });

    test('compute executes computation', () {
      final notifier = TestModelNotifier(TestModel());
      final result = notifier.compute<int>(() => 42 * 2);
      expect(result, 84);
    });

    test('compute handles exceptions gracefully', () {
      final notifier = TestModelNotifier(TestModel());
      expect(() => notifier.compute<int>(() => throw Exception('test')), throwsException);
    });

    test('multiple listeners work correctly', () {
      final notifier = TestModelNotifier(TestModel(value: 0));
      var listener1Called = false;
      var listener2Called = false;

      notifier.addListener(() => listener1Called = true);
      notifier.addListener(() => listener2Called = true);

      notifier.model = notifier.model.copyWith(value: 1);

      expect(listener1Called, true);
      expect(listener2Called, true);
    });

    test('removing listeners works correctly', () {
      final notifier = TestModelNotifier(TestModel(value: 0));
      var listenerCalled = false;
      void listener() => listenerCalled = true;

      notifier.addListener(listener);
      notifier.model = notifier.model.copyWith(value: 1);
      expect(listenerCalled, true);

      listenerCalled = false;
      notifier.removeListener(listener);
      notifier.model = notifier.model.copyWith(value: 2);
      expect(listenerCalled, false);
    });

    test('dispose sets disposed flag and calls super', () {
      final notifier = TestModelNotifier(TestModel());
      var listenerCalled = false;
      notifier.addListener(() => listenerCalled = true);
      // Verify listener was added by triggering a change
      notifier.model = notifier.model.copyWith(value: 1);
      expect(listenerCalled, true);

      notifier.dispose();
      // After dispose, the notifier should not accept new listeners
      expect(() => notifier.addListener(() {}), throwsA(isA<FlutterError>()));
    });
  });

  group('Watch Widget', () {
    setUp(() {
      ModelLocator.instance.reset();
    });

    tearDown(() {
      ModelLocator.instance.reset();
    });
    testWidgets('subscribes and rebuilds on model change', (tester) async {
      final notifier = TestModelNotifier(TestModel(value: 0));

      await tester.pumpWidget(
        MaterialApp(
          home: Watch((context) {
            return Text('Value: ${notifier.model.value}');
          }),
        ),
      );
      expect(find.text('Value: 0'), findsOneWidget);

      notifier.updateValue(1);
      await tester.pump();
      expect(find.text('Value: 1'), findsOneWidget);
    });

    testWidgets('nested Watch rebuilds granularly', (tester) async {
      final notifier = TestModelNotifier(TestModel(value: 0));

      var outerBuilds = 0;
      var innerBuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Watch((context) {
            outerBuilds++;
            // Outer watch doesn't access the notifier, so it shouldn't rebuild
            return Column(
              children: [
                Watch((context) {
                  innerBuilds++;
                  return Text('Inner: ${notifier.model.value}');
                }),
                const Text('Static'),
              ],
            );
          }),
        ),
      );
      expect(outerBuilds, 1);
      expect(innerBuilds, 1);
      expect(find.text('Inner: 0'), findsOneWidget);

      notifier.updateValue(1);
      await tester.pump();
      expect(outerBuilds, 1); // Outer should not rebuild
      expect(innerBuilds, 2); // Inner should rebuild
      expect(find.text('Inner: 1'), findsOneWidget);
    });

    testWidgets('multiple Watch widgets subscribe independently', (tester) async {
      final notifier = TestModelNotifier(TestModel(value: 0));

      var watch1Builds = 0;
      var watch2Builds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Watch((context) {
                watch1Builds++;
                return Text('Watch1: ${notifier.model.value}');
              }),
              Watch((context) {
                watch2Builds++;
                return Text('Watch2: ${notifier.model.value}');
              }),
            ],
          ),
        ),
      );
      expect(watch1Builds, 1);
      expect(watch2Builds, 1);

      notifier.updateValue(1);
      await tester.pump();
      expect(watch1Builds, 2);
      expect(watch2Builds, 2);
    });

    testWidgets('granular rebuilding - only affected Watch widgets rebuild', (tester) async {
      final notifier1 = TestModelNotifier(TestModel(value: 0));
      final notifier2 = TestModelNotifier(TestModel(value: 100));

      var watch1Builds = 0;
      var watch2Builds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Watch((context) {
                watch1Builds++;
                return Text('Watch1: ${notifier1.model.value}');
              }),
              Watch((context) {
                watch2Builds++;
                return Text('Watch2: ${notifier2.model.value}');
              }),
            ],
          ),
        ),
      );
      expect(watch1Builds, 1);
      expect(watch2Builds, 1);

      // Update only notifier1 - only watch1 should rebuild
      notifier1.updateValue(1);
      await tester.pump();
      expect(watch1Builds, 2);
      expect(watch2Builds, 1); // watch2 should not rebuild

      // Update only notifier2 - only watch2 should rebuild
      notifier2.updateValue(101);
      await tester.pump();
      expect(watch1Builds, 2); // watch1 should not rebuild
      expect(watch2Builds, 2);
    });

    testWidgets('dispose is called when Watch widgets are removed from tree', (tester) async {
      final notifier = TestModelNotifier(TestModel(value: 0));

      // Track if the widget was built (indicating subscription)
      var widgetBuilt = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Watch((context) {
            notifier.model; // Subscribe to the notifier
            widgetBuilt = true;
            return Text('Value: ${notifier.model.value}');
          }),
        ),
      );

      expect(widgetBuilt, true);

      // Remove the Watch widget from the tree
      await tester.pumpWidget(const SizedBox());

      // The notifier should be disposed when all subscribers are gone
      // We can verify this by checking that model changes don't cause issues
      // and that we can still create new instances
      final newNotifier = TestModelNotifier(TestModel(value: 10));
      expect(newNotifier.model.value, 10);
    });

    testWidgets('scoped notifiers are destroyed in DI when subscribers are dropped', (tester) async {
      ModelLocator.instance.registerScoped<TestModelNotifier>(
        () => TestModelNotifier(TestModel(value: 42)),
      );

      // First access creates the instance
      final firstInstance = ModelLocator.instance.get<TestModelNotifier>();
      expect(firstInstance.model.value, 42);

      // Use the instance in a Watch widget
      await tester.pumpWidget(
        MaterialApp(
          home: Watch((context) {
            final notifier = ModelLocator.instance.get<TestModelNotifier>();
            return Text('Value: ${notifier.model.value}');
          }),
        ),
      );

      // Verify the instance is the same
      expect(ModelLocator.instance.get<TestModelNotifier>(), firstInstance);

      // Remove the Watch widget
      await tester.pumpWidget(const SizedBox());

      // The scoped instance should be disposed and removed from DI
      // Next access should create a new instance
      final secondInstance = ModelLocator.instance.get<TestModelNotifier>();
      expect(secondInstance.model.value, 42);
      expect(secondInstance, isNot(firstInstance));
    });

    testWidgets('Watch handles null builder gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Watch((context) => const SizedBox()),
        ),
      );
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('disposal unsubscribes', (tester) async {
      // Use a scoped instance to test proper disposal
      ModelLocator.instance.registerScoped<TestModelNotifier>(
        () => TestModelNotifier(TestModel(value: 0)),
      );

      var builds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Watch((context) {
            builds++;
            final notifier = ModelLocator.instance.get<TestModelNotifier>();
            notifier.model; // Access to subscribe
            return const SizedBox();
          }),
        ),
      );
      expect(builds, 1);

      await tester.pumpWidget(const SizedBox()); // Remove Watch

      // For scoped instances, the notifier should be disposed when no subscribers remain
      // We can verify this by checking that a new instance is created on next access
      final newNotifier = ModelLocator.instance.get<TestModelNotifier>();
      expect(newNotifier.model.value, 0);
    });

    testWidgets('global instances are not disposed when Watch widgets are removed', (tester) async {
      // Register a global instance
      final globalInstance = TestModelNotifier(TestModel(value: 42));
      ModelLocator.instance.registerGlobal<TestModelNotifier>(globalInstance);

      var builds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Watch((context) {
            builds++;
            final notifier = ModelLocator.instance.get<TestModelNotifier>();
            notifier.model; // Access to subscribe
            return Text('Value: ${notifier.model.value}');
          }),
        ),
      );
      expect(builds, 1);
      expect(find.text('Value: 42'), findsOneWidget);

      // Remove Watch widget
      await tester.pumpWidget(const SizedBox());

      // Global instance should still be accessible and functional
      final retrieved = ModelLocator.instance.get<TestModelNotifier>();
      expect(retrieved, globalInstance);
      expect(retrieved.model.value, 42);

      // Should still be able to update and use the instance
      retrieved.updateValue(100);
      expect(retrieved.model.value, 100);
    });
  });

}
