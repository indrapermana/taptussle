import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shipped Lane Dash sprites stay within the decoded-source budget', () {
    final directory = Directory('assets/games/lane_dash');
    final sprites = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.png'))
        .toList();
    final bytes = sprites.fold<int>(
      0,
      (total, file) => total + file.lengthSync(),
    );

    expect(sprites, hasLength(28));
    expect(bytes, lessThan(4 * 1024 * 1024));
    expect(sprites.every((file) => file.lengthSync() < 300 * 1024), isTrue);
  });
}
