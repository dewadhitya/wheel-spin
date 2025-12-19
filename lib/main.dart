import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- 1. THE BRAIN (RIVERPOD PROVIDER) ---

// This Notifier manages the state: Is it loading? What is the result?
class SpinNotifier extends AutoDisposeNotifier<AsyncValue<int?>> {
  @override
  AsyncValue<int?> build() {
    // Initial state: No data, not loading.
    return const AsyncData(null);
  }

  Future<void> spinWheel(int itemCount) async {
    // 1. Set state to Loading
    state = const AsyncLoading();

    try {
      // 2. Simulate API Call (2 seconds delay)
      await Future.delayed(const Duration(seconds: 2));
      
      // 3. Generate result (Mocking the API response)
      final randomResult = Random().nextInt(itemCount);

      // 4. Update state with Success (Data)
      state = AsyncData(randomResult);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }
}

// Define the provider globally
final spinProvider = NotifierProvider.autoDispose<SpinNotifier, AsyncValue<int?>>(
  SpinNotifier.new,
);


// --- 2. THE UI (WIDGET) ---

void main() {
  // Don't forget ProviderScope at the root!
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riverpod Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Riverpod Fortune Wheel'),
    );
  }
}

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  // The StreamController belongs to the UI because it controls the Animation
  StreamController<int> controller = StreamController<int>();
  
  final items = <String>['Red', 'Green', 'Purple', 'Blue'];

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider to update UI based on state (Loading vs Data)
    final spinState = ref.watch(spinProvider);

    // --- THE BRIDGE: ref.listen ---
    // This listens for changes in the provider. When the API returns data,
    // we push that data into the stream to trigger the animation.
    ref.listen<AsyncValue<int?>>(spinProvider, (previous, next) {
      if (next is AsyncData && next.value != null) {
        // API finished! Start the animation.
        controller.add(next.value!);
      }
      
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${next.error}')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: FortuneWheel(
              selected: controller.stream,
              // Optional: Animation duration
              duration: const Duration(seconds: 4), 
              onAnimationEnd: () {
                // Read the current value to show the result
                final index = ref.read(spinProvider).value;
                if (index != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("You won: ${items[index]}")),
                  );
                }
              },
              indicators: <FortuneIndicator>[
                // --- YOUR CUSTOM INDICATOR UI ---
                FortuneIndicator(
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -20),
                        child: Transform.rotate(
                          angle: 3.14159,
                          child: const TriangleIndicator(
                            color: Colors.white,
                            width: 20.0,
                            height: 20.0,
                            elevation: 0,
                          ),
                        ),
                      ),
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2CCFA0),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.8), 
                            width: 3
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              items: [for (var it in items) FortuneItem(child: Text(it))],
            ),
          ),
          
          // --- THE BUTTON ---
          Padding(
            padding: const EdgeInsets.all(30.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                // Disable button if loading
                onPressed: spinState.isLoading 
                    ? null 
                    : () {
                        // Trigger the logic in the provider
                        ref.read(spinProvider.notifier).spinWheel(items.length);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2CCFA0),
                  foregroundColor: Colors.white,
                ),
                child: spinState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "SPIN NOW",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}