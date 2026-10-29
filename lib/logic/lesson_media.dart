import '../data/content.dart';
import '../data/models.dart';
import 'coach.dart';
import 'logic.dart';

/// Lesson media served from the Asanova media server (Cloudflare R2) and kept on the phone
/// after the first download (web `src/lib/lesson-media.ts`, kept 1:1).
/// Paths are relative to the versioned media root: `video/<film>.mp4`, `voice/<key>.m4a`.
const kMediaBase = 'https://pub-e1f33e62495044f8b81b29fa39490d18.r2.dev/v1';

/// The tutor's course welcome and end-of-practice celebration films.
const kTutorWelcomeFilm = 'yf-tutor-welcome';
const kTutorCongratsFilm = 'yf-tutor-congrats';

/// Reviewed eyes-closed frame after the Namaste gesture; narration is independent.
const kTutorWelcomeStopSeconds = 8.8;
bool filmPlaybackComplete(String? film, double seconds) =>
    film == kTutorWelcomeFilm && seconds >= kTutorWelcomeStopSeconds;

String filmPath(String film) => 'video/$film.mp4';
String voicePath(String key) => 'voice/$key.m4a';

/// How the guided player opens and runs a session for this person.
class JourneyOptions {
  const JourneyOptions({
    required this.known,
    required this.demos,
    required this.welcome,
    this.completedDays = const [],
  });

  /// Poses and flows already practised ([practisedSet]).
  final Set<String> known;

  /// Watch-first demos are on.
  final bool demos;

  /// The tutor's course welcome plays first ([shouldWelcome]).
  final bool welcome;

  /// Days of this course finished before this session.
  final List<int> completedDays;
}

/// The continuous round film item [it] plays inside (its flow at its pace), or null for a pose hold.
RoundFilmDef? roundFilmOf(YogaFlow? flow, SessionItem it) {
  if (flow == null || it.f == null) return null;
  return it.k > 1 ? flow.roundSlow : flow.round;
}

/// The part of its round film item [i] plays in (web `roundPartAt`): [part] (0-based), the [film]
/// key, and [start], the item that began that part (the players restart the film there, so it never
/// drifts from the breath cues).
({RoundFilmDef round, int part, String film, int start})? roundPartAt(
  List<SessionItem> items,
  int i,
) {
  if (i < 0 || i >= items.length) return null;
  final it = items[i];
  final round = roundFilmOf(Content.i.flow(it.f), it);
  if (round == null) return null;
  final first = roundStart(items, i);
  final move = i - first;
  var part = 0;
  while (part + 1 < round.from.length && round.from[part + 1] <= move) {
    part++;
  }
  return (
    round: round,
    part: part,
    film: round.films[part],
    start: first + round.from[part],
  );
}

/// The affirmation spoken halfway through a single-step hold at item [index].
String halfwayAffirmation(String sessionId, int index) =>
    Content.i.affirmations[(index * 7 + sessionId.length) %
        Content.i.affirmations.length];

/// The demo the player shows before item [i] under [o] (none when demos are off).
DemoKind? journeyDemoAt(List<SessionItem> items, int i, JourneyOptions o) =>
    o.demos ? demoAt(items, i, o.known) : null;

/// Whether the demo at item [i] says "Watch first" / "Your turn" (only the first two demos of Day 1).
bool demoCueAt(Session s, int i, JourneyOptions o) {
  var n = 0;
  for (var j = 0; j < i; j++) {
    if (journeyDemoAt(s.items, j, o) != null) n++;
  }
  return speaksDemoCue(s.day, n);
}

/// Every line the guided player can speak during [s], in play order (welcome, day intention,
/// demos, "your turn", breath cues, steps, rests, finish and the celebration).
List<String> sessionLines(Session s, JourneyOptions o) {
  final c = Content.i;
  final out = <String>[];
  final items = s.items;
  final plan = s.planId == null ? null : c.plan(s.planId!);
  final multiDay = plan != null && plan.days.length > 1;
  if (o.welcome && plan != null) out.addAll(CoachLines.welcome(plan));
  if (s.intro.isNotEmpty) {
    out.addAll(CoachLines.dayIntro(s.intro, multiDay ? s.day : null));
  } else if (items.isNotEmpty) {
    final first = c.exercise(items.first.e);
    if (first != null) out.addAll(CoachLines.begin(first));
  }
  for (var i = 0; i < items.length; i++) {
    final it = items[i];
    final ex = c.exercise(it.e);
    if (ex == null) continue;
    if (i > 0 && gapBefore(items, i, s.restSec) > 0) {
      out.addAll(CoachLines.rest(ex));
    }
    final demo = journeyDemoAt(items, i, o);
    if (it.f != null) {
      final flow = c.flow(it.f);
      final blockStart = i == 0 || items[i - 1].f != it.f;
      if (flow != null && blockStart) {
        if (demo == DemoKind.flow) {
          out.addAll(CoachLines.flowDemo(flow, demoCueAt(s, i, o)));
        }
        out.addAll(CoachLines.flowGo(flow));
      }
      out.addAll(CoachLines.flowMove(it, isRoundStart(items, i)));
      continue;
    }
    if (demo == DemoKind.pose) {
      out.addAll(CoachLines.demo(ex, demoCueAt(s, i, o)));
      out.addAll(CoachLines.yourTurn(ex, demoCueAt(s, i, o)));
    } else {
      out.addAll(CoachLines.start(ex));
    }
    if (!ex.isAffirmation && ex.steps.length > 1) {
      for (var k = 1; k < ex.steps.length; k++) {
        out.addAll(CoachLines.step(ex, k));
      }
    } else if (it.s >= 40) {
      out.addAll(CoachLines.halfway(ex, halfwayAffirmation(s.id, i)));
    }
  }
  out.addAll(CoachLines.finish());
  out.addAll(completionLines(s.planId, s.day, o.completedDays));
  return out;
}

/// What the tutor says on the completion screen.
List<String> completionLines(
  String? planId,
  int? day,
  List<int> completedDays,
) {
  final done = completionOf(planId, day, completedDays);
  return switch (done.kind) {
    CompletionKind.day => CoachLines.dayDone(done.day!, done.next),
    CompletionKind.course => CoachLines.courseDone(done.plan!),
    CompletionKind.single => CoachLines.classDone(),
  };
}

/// Every film and coach clip a guided session can use, in play order, without duplicates.
/// [clips] is the set of voice keys that have a rendered clip (`Content.voice`).
List<String> sessionMediaPaths(Session s, JourneyOptions o, Set<String> clips) {
  final c = Content.i;
  final out = <String>[];
  void add(String p) {
    if (!out.contains(p)) out.add(p);
  }

  final plan = s.planId == null ? null : c.plan(s.planId!);
  if (o.welcome && plan != null) add(filmPath(kTutorWelcomeFilm));
  final items = s.items;
  for (var i = 0; i < items.length; i++) {
    final it = items[i];
    if (journeyDemoAt(items, i, o) == DemoKind.flow) {
      final film = c.flow(it.f)?.demo;
      if (film != null) add(filmPath(film));
    }
    final ex = c.exercise(it.e);
    if (ex == null || ex.video != null) continue;
    // a flow round plays its continuous film (one or a few parts); without one, the move's pose film
    if (it.f != null) {
      final round = roundFilmOf(c.flow(it.f), it);
      if (round != null) {
        for (final f in round.films) {
          add(filmPath(f));
        }
      } else if (ex.demo != null) {
        add(filmPath(ex.demo!));
      }
      continue;
    }
    // play order: the pose's entry film, then its looping hold film
    if (ex.entry != null) add(filmPath(ex.entry!));
    if (ex.demo != null) add(filmPath(ex.demo!));
  }
  add(filmPath(kTutorCongratsFilm));
  for (final line in sessionLines(s, o)) {
    final k = voiceKey(line);
    if (clips.contains(k)) add(voicePath(k));
  }
  return out;
}

/// Narration clips of a meditation.
List<String> meditationMediaPaths(Meditation m, Set<String> clips) => [
  for (final k in {for (final l in m.script) voiceKey(l.text)})
    if (clips.contains(k)) voicePath(k),
];

/// Share of a download that is complete, as a whole percent (nothing needed is 100).
int downloadPercent(int done, int total) =>
    total <= 0 ? 100 : ((done / total) * 100).floor().clamp(0, 100);
