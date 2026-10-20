import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/core/widgets/near_mouse.dart';

void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: NearMouse(
              builder: (near) => Padding(
                padding: const EdgeInsets.fromLTRB(96, 4, 4, 96),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.close),
                    RevealedWhen(near, child: const Icon(Icons.tune)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));

  double opacityOfTune(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(find.ancestor(of: find.byIcon(Icons.tune), matching: find.byType(AnimatedOpacity))).opacity;

  testWidgets('without a mouse everything is there', (tester) async {
    await pump(tester);
    expect(opacityOfTune(tester), 1);
  });

  testWidgets('with a mouse the rest comes up only when it gets near', (tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(10, 500));
    await pump(tester);
    expect(opacityOfTune(tester), 0);
    // Within the padding around the buttons counts as near.
    final close = tester.getCenter(find.byIcon(Icons.close));
    await mouse.moveTo(close - const Offset(80, -60));
    await tester.pumpAndSettle();
    expect(opacityOfTune(tester), 1);
    await mouse.moveTo(const Offset(10, 500));
    await tester.pumpAndSettle();
    expect(opacityOfTune(tester), 0);
  });
}
