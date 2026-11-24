// NativePreviewTexture structure tests: rotation quarter-turns follow
// the overlay mapper convention (turns = rotation/90), mirroring wraps
// in a centered horizontal flip, rot 0 has no RotatedBox. Pure widget
// structure — no camera plugin needed (Texture pumps blank in tests).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/ui/widgets/common.dart';

void main() {
  Future<void> pumpTex(
    WidgetTester tester, {
    required int rotationDeg,
    required bool mirrored,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox.expand(
          child: NativePreviewTexture(
            textureId: 1,
            rotationDeg: rotationDeg,
            mirrored: mirrored,
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  // Framework widgets (Scaffold, RotatedBox internals) own Transforms
  // too — scope to ancestors of our Texture, innermost first.
  List<Transform> flipsOf(WidgetTester tester) => find
      .ancestor(
          of: find.byType(Texture), matching: find.byType(Transform))
      .evaluate()
      .map((e) => e.widget as Transform)
      .toList();

  testWidgets('rot 270 -> 3 quarter turns + mirror flip', (tester) async {
    await pumpTex(tester, rotationDeg: 270, mirrored: true);
    final box = tester.widget<RotatedBox>(find.byType(RotatedBox));
    expect(box.quarterTurns, 3);
    final flips = flipsOf(tester);
    expect(flips.length, 1);
    expect(flips.first.transform.getRow(0)[0], closeTo(-1.0, 1e-9));
    expect(find.byType(Texture), findsOneWidget);
  });

  testWidgets('rot 90 -> 1 quarter turn, no mirror', (tester) async {
    await pumpTex(tester, rotationDeg: 90, mirrored: false);
    final box = tester.widget<RotatedBox>(find.byType(RotatedBox));
    expect(box.quarterTurns, 1);
    expect(flipsOf(tester), isEmpty);
  });

  testWidgets('rot 0 mirrored -> flip only, no RotatedBox',
      (tester) async {
    await pumpTex(tester, rotationDeg: 0, mirrored: true);
    expect(find.byType(RotatedBox), findsNothing);
    final flips = flipsOf(tester);
    expect(flips.length, 1);
    expect(flips.first.transform.getRow(0)[0], closeTo(-1.0, 1e-9));
    expect(find.byType(Texture), findsOneWidget);
  });

  testWidgets('rear rot 90 unmirrored passes texture through',
      (tester) async {
    await pumpTex(tester, rotationDeg: 90, mirrored: false);
    expect(
        tester
            .widget<Texture>(find.byType(Texture))
            .textureId,
        1);
  });
}
