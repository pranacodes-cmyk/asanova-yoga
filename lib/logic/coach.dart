import 'dart:convert';

import '../data/models.dart';
import '../i18n/i18n.dart';

/// Every line the coach speaks, built in one place so both clients say exactly the same words.
/// Natural-voice clips are pre-rendered per line and looked up by [voiceKey], so wording
/// changes need `bun scripts/render-voice.ts` + `bun scripts/generate-content.ts`.
/// Mirrors src/lib/coach.ts (tests assert identical keys).

/// Collapse whitespace so cosmetic spacing never changes a clip key.
String normalizeLine(String text) =>
    text.trim().replaceAll(RegExp(r'\s+'), ' ');

/// FNV-1a (32-bit) over the UTF-8 bytes of the normalised line → "v" + 8 hex chars.
String voiceKey(String text) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(normalizeLine(text))) {
    h ^= b;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return 'v${h.toRadixString(16).padLeft(8, '0')}';
}

enum CoachBreath { inhale, exhale, hold }

/// Strip the localized "Repeat after me:" lead-in from an affirmation cue.
String _affirmationWords(String cue) {
  final lead = tr('coach.repeatAfterMe');
  return cue.startsWith(lead) ? cue.substring(lead.length).trim() : cue;
}

class CoachLines {
  CoachLines._();

  static List<String> begin(Exercise first) => [
    tr('coach.begin'),
    tr('coach.name', {'name': first.name}),
  ];

  static List<String> start(Exercise ex) => ex.isAffirmation
      ? [tr('coach.spokenAffirmation'), ex.cue]
      : [
          tr('coach.name', {'name': ex.name}),
          ex.steps.isNotEmpty ? ex.steps.first : ex.cue,
        ];

  static List<String> step(Exercise ex, int k) => [
    k >= 0 && k < ex.steps.length ? ex.steps[k] : ex.cue,
  ];

  static List<String> halfway(Exercise ex, String affirmation) =>
      ex.isAffirmation
      ? [tr('coach.onceMore'), _affirmationWords(ex.cue)]
      : [affirmation];

  static List<String> rest(Exercise next) => [
    tr('coach.rest'),
    tr('coach.name', {'name': next.name}),
  ];

  static List<String> finish() => [tr('coach.finish')];

  static List<String> breath(CoachBreath phase) => [
    phase == CoachBreath.inhale
        ? tr('coach.breatheIn')
        : (phase == CoachBreath.exhale
              ? tr('coach.breatheOut')
              : tr('coach.hold')),
  ];

  /// Onboarding: the coach's reply to a picked answer.
  static List<String> onbReply(OnbOption o) =>
      (o.reply ?? '').isEmpty ? const [] : [o.reply!];

  /// Onboarding: spoken when a chapter card opens (the breath chapter uses breath cues).
  static List<String> onbChapter(OnbChapter c) =>
      c.breath ? const [] : [c.line];

  /// Onboarding: the coach's cues during the opening breath.
  static List<String> onbBreath(CoachBreath phase) => [
    phase == CoachBreath.inhale
        ? tr('coach.onbBreatheIn')
        : tr('coach.onbBreatheOut'),
  ];

  /// Onboarding: after the opening breath.
  static List<String> onbArrived() => [tr('coach.onbArrived')];

  static List<String> guide(Guide g) => [
    tr('coach.guideIntro', {'title': g.title, 'intro': g.intro}),
    for (final s in g.sections)
      tr('coach.guideSection', {
        'heading': s.heading.replaceFirst(RegExp(r'^\d+ · '), ''),
        'body': s.body,
      }),
    tr('coach.remember', {'list': g.takeaways.join(tr('coach.listSeparator'))}),
  ];

  static List<String> preview() => [tr('coach.preview')];

  // ---------------------------------------------------------------- guided journey
  /// The tutor demonstrates a new pose before the person's turn.
  static List<String> demo(Exercise ex, [bool cue = true]) => [
    if (cue) tr('coach.watchFirst'),
    tr('coach.name', {'name': ex.name}),
    ex.watch,
  ];

  /// The person's turn after a demo: the first instruction step.
  static List<String> yourTurn(Exercise ex, [bool cue = true]) => [
    if (cue) tr('coach.yourTurn'),
    ex.steps.isNotEmpty ? ex.steps.first : ex.cue,
  ];

  /// The tutor shows one round of a Sun / Moon Salutation.
  static List<String> flowDemo(YogaFlow f, [bool cue = true]) => [
    if (cue) tr('coach.watchFirst'),
    tr('coach.name', {'name': f.name}),
    f.watch,
  ];

  /// Spoken as the person starts a flow (after its demo or straight away).
  static List<String> flowGo(YogaFlow f) => [f.go];

  /// One breath-paced movement; a new round is announced on its first movement.
  static List<String> flowMove(SessionItem it, bool roundStart) => [
    if (roundStart && (it.r ?? 1) > 1) tr('coach.round', {'n': it.r!}),
    it.c ?? '',
  ];

  /// Day intention at the start of a lesson ([day] only for multi-day courses).
  static List<String> dayIntro(String intro, [int? day]) => [
    if (day != null) tr('coach.dayLead', {'day': day}),
    intro,
  ];

  /// The tutor's welcome before Day 1 of a course, one caption per line.
  static List<String> welcome(Plan p) => [
    tr('coach.welcomeTo', {'title': p.title}),
    ...p.welcome,
    tr('coach.welcomeHow'),
    tr('coach.welcomeBegin'),
  ];

  /// End of a course day: congratulations, then tomorrow's preview.
  static List<String> dayDone(int day, PlanDay? next) => [
    tr('coach.dayDone', {'day': day}),
    if (next?.tease != null) ...[next!.tease!, tr('coach.seeYouTomorrow')],
  ];

  /// The last day of a course is complete.
  static List<String> courseDone(Plan p) => [
    tr('coach.courseDone', {'title': p.title}),
    if (p.finale != null) p.finale!,
  ];

  /// A single class, quick session or style class is complete.
  static List<String> classDone() => [tr('coach.classDone')];
}
