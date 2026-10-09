import 'memory_match_model.dart';

class MemoryMatchSymbolAsset {
  const MemoryMatchSymbolAsset({required this.name, required this.path});

  final String name;
  final String path;
}

abstract final class MemoryMatchAssets {
  static const directory = 'assets/games/memory_match';
  static const cardBack = '$directory/card_back.png';

  /// Stable pair order. Deck pair IDs index directly into this list.
  static const symbols = <MemoryMatchSymbolAsset>[
    MemoryMatchSymbolAsset(name: 'car', path: '$directory/car.png'),
    MemoryMatchSymbolAsset(name: 'dinosaur', path: '$directory/dinosaur.png'),
    MemoryMatchSymbolAsset(name: 'ball', path: '$directory/ball.png'),
    MemoryMatchSymbolAsset(name: 'butterfly', path: '$directory/butterfly.png'),
    MemoryMatchSymbolAsset(name: 'cat', path: '$directory/cat.png'),
    MemoryMatchSymbolAsset(name: 'dog', path: '$directory/dog.png'),
    MemoryMatchSymbolAsset(name: 'cupcake', path: '$directory/cupcake.png'),
    MemoryMatchSymbolAsset(
      name: 'strawberry',
      path: '$directory/strawberry.png',
    ),
    MemoryMatchSymbolAsset(name: 'pizza', path: '$directory/pizza.png'),
    MemoryMatchSymbolAsset(name: 'crown', path: '$directory/crown.png'),
    MemoryMatchSymbolAsset(name: 'planet', path: '$directory/planet.png'),
    MemoryMatchSymbolAsset(
      name: 'treasure chest',
      path: '$directory/treasure.png',
    ),
  ];

  static List<MemoryMatchSymbolAsset> symbolsFor(
    MemoryMatchDifficulty difficulty,
  ) => symbols.take(difficulty.pairCount).toList(growable: false);
}
