import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/memory_match/memory_match_assets.dart';
import 'package:tap_tussle/games/memory_match/memory_match_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('difficulty mappings use the stable six, eight, and twelve symbols', () {
    expect(
      MemoryMatchAssets.symbolsFor(MemoryMatchDifficulty.easy),
      hasLength(6),
    );
    expect(
      MemoryMatchAssets.symbolsFor(MemoryMatchDifficulty.normal),
      hasLength(8),
    );
    expect(
      MemoryMatchAssets.symbolsFor(MemoryMatchDifficulty.hard),
      hasLength(12),
    );
    expect(
      MemoryMatchAssets.symbols.map((symbol) => symbol.name).toSet(),
      hasLength(12),
    );
    expect(
      MemoryMatchAssets.symbols.map((symbol) => symbol.path).toSet(),
      hasLength(12),
    );
  });

  test('production artwork is bundled as compact square RGBA images', () async {
    final paths = [
      MemoryMatchAssets.cardBack,
      ...MemoryMatchAssets.symbols.map((symbol) => symbol.path),
    ];

    for (final path in paths) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, lessThan(150 * 1024), reason: path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 256, reason: path);
      expect(frame.image.height, 256, reason: path);
      frame.image.dispose();
      codec.dispose();
    }
  });
}
