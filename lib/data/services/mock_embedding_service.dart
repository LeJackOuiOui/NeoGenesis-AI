import 'dart:math';

import 'embedding_service.dart';

class MockEmbeddingService implements EmbeddingService {
  @override
  Future<List<double>> generateEmbedding(String text) async {
    final random = Random(text.hashCode);

    return List.generate(10, (_) => random.nextDouble() * 2 - 1);
  }
}
