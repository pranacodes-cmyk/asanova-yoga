/// Prefer a clear installed iOS voice without changing Android's voice selection.
Map? bestIosVoice(List<Map> voices) {
  int quality(Map voice) => switch (voice['quality']) {
    'premium' => 2,
    'enhanced' => 1,
    _ => 0,
  };
  final female = voices.where((v) => v['gender'] == 'female').toList();
  final candidates = female.isNotEmpty ? female : List<Map>.of(voices);
  candidates.sort((a, b) => quality(b).compareTo(quality(a)));
  return candidates.firstOrNull;
}