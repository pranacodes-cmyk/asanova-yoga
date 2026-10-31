// Pure business rules — 1:1 mirror of src/lib/logic.ts. Any change must be applied to both.
import 'dart:math' as math;

import '../data/content.dart';
import '../data/models.dart';
import '../i18n/i18n.dart';

const restBetweenSec = 10;

/// The 30-Day Yoga Journey: the course every standing newcomer starts with.
const defaultPlanId = 'yoga-journey-30';
const baseWeightKg = 70.0;

class Profile {
  String name,
      gender,
      ageGroup,
      bodyType,
      activity,
      flexibilityCheck,
      balanceCheck,
      experience,
      breathwork,
      strengthCheck,
      units,
      style;
  List<String> goals, zones, limitations;
  double heightCm, weightKg, targetWeightKg;
  int stress, dailyMinutes;

  Profile({
    this.name = '',
    this.gender = '',
    this.ageGroup = '',
    this.bodyType = '',
    this.activity = '',
    this.flexibilityCheck = '',
    this.balanceCheck = '',
    this.experience = '',
    this.breathwork = '',
    this.strengthCheck = '',
    this.units = 'metric',
    this.style = '',
    List<String>? goals,
    List<String>? zones,
    List<String>? limitations,
    this.heightCm = 168,
    this.weightKg = 72,
    this.targetWeightKg = 66,
    this.stress = 3,
    this.dailyMinutes = 10,
  }) : goals = goals ?? [],
       zones = zones ?? [],
       limitations = limitations ?? [];

  bool get imperial => units == 'imperial';

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender,
    'ageGroup': ageGroup,
    'goals': goals,
    'bodyType': bodyType,
    'zones': zones,
    'activity': activity,
    'flexibilityCheck': flexibilityCheck,
    'balanceCheck': balanceCheck,
    'experience': experience,
    'breathwork': breathwork,
    'strengthCheck': strengthCheck,
    'limitations': limitations,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'targetWeightKg': targetWeightKg,
    'units': units,
    'style': style,
    'stress': stress,
    'dailyMinutes': dailyMinutes,
  };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    name: j['name'] ?? '',
    gender: j['gender'] ?? '',
    ageGroup: j['ageGroup'] ?? '',
    goals: (j['goals'] as List? ?? []).cast<String>().toList(),
    bodyType: j['bodyType'] ?? '',
    zones: (j['zones'] as List? ?? []).cast<String>().toList(),
    activity: j['activity'] ?? '',
    flexibilityCheck: j['flexibilityCheck'] ?? '',
    balanceCheck: j['balanceCheck'] ?? '',
    experience: j['experience'] ?? '',
    breathwork: j['breathwork'] ?? '',
    strengthCheck: j['strengthCheck'] ?? '',
    limitations: (j['limitations'] as List? ?? []).cast<String>().toList(),
    heightCm: (j['heightCm'] as num? ?? 168).toDouble(),
    weightKg: (j['weightKg'] as num? ?? 72).toDouble(),
    targetWeightKg: (j['targetWeightKg'] as num? ?? 66).toDouble(),
    units: j['units'] ?? 'metric',
    style: j['style'] ?? '',
    stress: (j['stress'] as num? ?? 3).toInt(),
    dailyMinutes: (j['dailyMinutes'] as num? ?? 10).toInt(),
  );

  Profile copy() => Profile.fromJson(toJson());

  String getString(String field) => (toJson()[field] ?? '').toString();
  List<String> getList(String field) =>
      (toJson()[field] as List? ?? []).cast<String>();
}

class HistoryEntry {
  final String id, sessionId, title, kind, image;
  final String? planId;
  final int? day;
  final DateTime completedAt;
  final int durationSec, kcal;
  int? feeling;

  HistoryEntry({
    required this.id,
    required this.sessionId,
    required this.title,
    required this.kind,
    required this.image,
    this.planId,
    this.day,
    required this.completedAt,
    required this.durationSec,
    required this.kcal,
    this.feeling,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'title': title,
    'kind': kind,
    'image': image,
    if (planId != null) 'planId': planId,
    if (day != null) 'day': day,
    'completedAt': completedAt.toIso8601String(),
    'durationSec': durationSec,
    'kcal': kcal,
    if (feeling != null) 'feeling': feeling,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
    id: j['id'],
    sessionId: j['sessionId'],
    title: j['title'],
    kind: j['kind'],
    image: j['image'],
    planId: j['planId'],
    day: (j['day'] as num?)?.toInt(),
    completedAt: DateTime.parse(j['completedAt']).toLocal(),
    durationSec: (j['durationSec'] as num).toInt(),
    kcal: (j['kcal'] as num).toInt(),
    feeling: (j['feeling'] as num?)?.toInt(),
  );
}

class Session {
  final String id, kind, title, subtitle, image;
  final List<SessionItem> items;
  final int restSec, baseKcal;
  final String? planId;
  final int? day;

  /// The tutor's opening intention, spoken before the first pose ('' when none).
  final String intro;
  const Session({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.items,
    required this.restSec,
    required this.baseKcal,
    this.planId,
    this.day,
    this.intro = '',
  });
}

// ------------------------------------------------------------ dates

String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime addDays(DateTime d, int n) =>
    DateTime(d.year, d.month, d.day + n, d.hour, d.minute);
int dayOfYear(DateTime d) =>
    DateTime(d.year, d.month, d.day).difference(DateTime(d.year, 1, 1)).inDays +
    1;

// ------------------------------------------------------------ language

/// App languages, English first. Must match scripts/content/i18n/languages.ts (a test checks).
const supportedLanguages = ['en', 'hi', 'es', 'pt', 'de', 'fr', 'it', 'ja'];

/// Each language's own name, shown in the language picker.
const languageNames = {
  'en': 'English',
  'hi': 'हिन्दी',
  'es': 'Español',
  'pt': 'Português',
  'de': 'Deutsch',
  'fr': 'Français',
  'it': 'Italiano',
  'ja': '日本語',
};

/// The app language: the person's saved choice, else the first device language we ship, else English.
String resolveLanguage(String? saved, List<String> deviceLocales) {
  if (saved != null && supportedLanguages.contains(saved)) return saved;
  for (final l in deviceLocales) {
    final primary = l.toLowerCase().split(RegExp(r'[-_]')).first;
    if (supportedLanguages.contains(primary)) return primary;
  }
  return 'en';
}

/// Device-voice locales for the coach fallback, most preferred first (prefix match on the voice's
/// locale). English stays US/UK only; other languages prefer the accent of the clips.
List<String> fallbackVoiceLocales(String lang) =>
    const {
      'en': ['en-us', 'en-gb'],
      'hi': ['hi-in', 'hi'],
      'es': ['es-mx', 'es-us', 'es-419', 'es-es', 'es'],
      'pt': ['pt-br', 'pt'],
      'de': ['de-de', 'de'],
      'fr': ['fr-fr', 'fr'],
      'it': ['it-it', 'it'],
      'ja': ['ja-jp', 'ja'],
    }[lang] ??
    const ['en-us', 'en-gb'];

/// Rank of a device voice locale for [lang] (lower is better), or null when it must not be used.
int? fallbackVoiceRank(String lang, String locale) {
  final l = locale.toLowerCase().replaceAll('_', '-');
  final prefs = fallbackVoiceLocales(lang);
  for (var i = 0; i < prefs.length; i++) {
    if (l == prefs[i] || l.startsWith('${prefs[i]}-')) return i;
  }
  return null;
}

String greeting(int hour) {
  if (hour < 5) return tr('greet.evening');
  if (hour < 12) return tr('greet.morning');
  if (hour < 17) return tr('greet.afternoon');
  return tr('greet.evening');
}

/// Rating prompt: once per calendar day after a completed session, until the person has rated (4–5 stars sent to the store, or private feedback sent).
bool shouldAskRating(bool rated, String? lastAskedDay, String todayKey) =>
    !rated && lastAskedDay != todayKey;

/// 4–5 stars go to the store review; 1–3 stars open private feedback instead.
bool ratingGoesToStore(int stars) => stars >= 4;

/// Meditate tab's featured card: a free pick for people without Plus, so the first thing they see plays.
String featuredMeditationId(int hour, bool premium) {
  if (hour >= 17) return premium ? 'yoga-nidra' : 'evening-wind-down';
  return 'morning-clarity';
}

/// Today's "Breathe now" row, in order, after the free breathing coach: one free practice, then classic pranayama.
const breatheNowIds = [
  'box-breathing',
  'alternate-nostril',
  'bhramari-bee',
  'moon-breath',
  'cooling-breath',
];

/// The complete root-to-crown sitting shown beneath the chakra path on Meditate.
const chakraJourneyId = 'chakra-journey';

/// Today's pose of the day: one side of each pose, from the mat library only (no chair, wall or breathing drills).
bool isPoseOfDayCandidate(String id, String category) =>
    !id.endsWith('-left') &&
    !RegExp(r'^(chair|wall)-').hasMatch(id) &&
    category != 'breath' &&
    category != 'chair' &&
    category != 'wall';

/// Free quick session featured on Today for people without Plus: morning wake-up, evening unwind, desk reset in between.
String freePickQuickId(int hour) {
  if (hour >= 5 && hour < 12) return 'morning-wake-up';
  if (hour >= 17 || hour < 5) return 'evening-unwind';
  return 'desk-reset';
}

/// The flagship 30-day journey: its first free days are the free path every newcomer can follow.
const freeStarterId = 'yoga-journey-30';

/// Days of [plan] open without Asanova Plus: every day of a free course, else its first `freeDays`.
int freeDayCount(Plan plan) => plan.premium ? plan.freeDays : plan.days.length;

/// Display names of what a course day teaches for the first time (`PlanDay.learn`): flows by
/// name, poses without their side, each once, in teaching order.
List<String> learnNames(List<String> learn) {
  final out = <String>[];
  for (final id in learn) {
    final name = id.startsWith('flow:')
        ? Content.i.flow(id.substring(5))?.name
        : Content.i.exercise(id)?.baseName;
    if (name != null && !out.contains(name)) out.add(name);
  }
  return out;
}

/// The course stage a day belongs to, or null for courses without stages.
PlanChapter? chapterOf(Plan plan, int day) =>
    plan.chapters.where((c) => day >= c.from && day <= c.to).firstOrNull;

/// The free starter day Today features (of the first [totalDays] free days), or null once every
/// one is finished.
int? freeStarterDay(int totalDays, List<int> completed) {
  final done = completed.toSet();
  for (var d = 1; d <= totalDays; d++) {
    if (!done.contains(d)) return d;
  }
  return null;
}

/// Today leads with a free session (personal plan moves below) whenever the personal plan's next day is locked.
/// Unless the person already practises that course: then it stays the headline (its locked next day
/// is the Plus invitation) instead of swapping in a different session.
bool homeLeadsWithFree(bool planLocked, [bool planStarted = false]) =>
    planLocked && !planStarted;

/// "Watch first" / "Your turn" are spoken only for the first two demos of a course's Day 1.
bool speaksDemoCue(int? day, int demoOrdinal) => day == 1 && demoOrdinal < 2;

// ------------------------------------------------------------ body

double bmi(double heightCm, double weightKg) {
  final m = heightCm / 100;
  if (m <= 0) return 0;
  return (weightKg / (m * m) * 10).round() / 10;
}

String bmiCategory(double v) {
  if (v < 18.5) return 'Underweight';
  if (v < 25) return 'Healthy';
  if (v < 30) return 'Overweight';
  return 'Obese';
}

int kgToLb(double kg) => (kg * 2.20462).round();
double lbToKg(num lb) => (lb / 2.20462 * 10).round() / 10;
({int ft, int inch}) cmToFtIn(double cm) {
  final total = (cm / 2.54).round();
  return (ft: total ~/ 12, inch: total % 12);
}

int ftInToCm(int ft, int inch) => ((ft * 12 + inch) * 2.54).round();

String _trim(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
String formatWeight(double kg, String units) => units == 'imperial'
    ? '${kgToLb(kg)} lb'
    : '${_trim((kg * 10).round() / 10)} kg';
String formatHeight(double cm, String units) {
  if (units == 'imperial') {
    final r = cmToFtIn(cm);
    return '${r.ft}′${r.inch}″';
  }
  return '${cm.round()} cm';
}

int predictWeeks(double currentKg, double targetKg) {
  final diff = (currentKg - targetKg).abs();
  return math.min(26, math.max(4, (diff / 0.5).ceil()));
}

DateTime predictTargetDate(double currentKg, double targetKg, DateTime from) =>
    addDays(from, predictWeeks(currentKg, targetKg) * 7);

List<double> predictionCurve(
  double currentKg,
  double targetKg, [
  int points = 6,
]) {
  return List.generate(points, (i) {
    final t = i / (points - 1);
    final eased = 1 - math.pow(1 - t, 2.2).toDouble();
    return ((currentKg + (targetKg - currentKg) * eased) * 10).round() / 10;
  });
}

// ------------------------------------------------------------ personalization

/// The course a person starts with, from their onboarding answers (web `recommendPlanId`):
/// floor-free needs and chosen styles first, then newcomers stay on the foundations,
/// back care for back needs, and strength work only for people who already practise
/// and can hold Downward Dog.
String recommendPlanId({
  required List<String> goals,
  required String style,
  required List<String> limitations,
  required String ageGroup,
  String experience = '',
  String strengthCheck = '',
}) {
  final g = goals.toSet();
  final newcomer = experience == 'new';
  // can't hold Downward Dog yet, or doesn't know the pose: build the base before the strength course
  final notStrongYet = strengthCheck == 'notyet' || strengthCheck == 'unsure';
  final seated = limitations.contains('mobility') || style == 'chair';
  if (seated) return 'chair-yoga-21';
  if (style == 'wall') return 'wall-yoga-14';
  if (style == 'restorative') return 'yin-sleep-14';
  if (style == 'power') {
    return newcomer || notStrongYet ? defaultPlanId : 'strength-21';
  }
  if (style == 'vinyasa') {
    return newcomer ? 'sun-salutation-14' : 'daily-yoga-28';
  }
  if (limitations.contains('back') || g.contains('back')) return 'back-care-14';
  if (g.contains('core') &&
      !notStrongYet &&
      (experience == 'regular' || experience == 'dedicated')) {
    return 'strength-21';
  }
  return defaultPlanId;
}

/// Which daily practice suits this person: seated for limited mobility or chair lovers.
String dailyPlanId({
  required List<String> limitations,
  required String style,
}) => limitations.contains('mobility') || style == 'chair'
    ? 'chair-yoga-21'
    : 'daily-yoga-28';

String recommendFor(Profile p) => recommendPlanId(
  goals: p.goals,
  style: p.style,
  limitations: p.limitations,
  ageGroup: p.ageGroup,
  experience: p.experience,
  strengthCheck: p.strengthCheck,
);

/// Multi-choice toggle where one answer (e.g. "none") excludes every other (web `toggleExclusive`).
List<String> toggleExclusive(List<String> value, String id, String exclusive) {
  if (id == exclusive) return value.contains(id) ? [] : [id];
  final base = value.where((v) => v != exclusive).toList();
  return base.contains(id)
      ? base.where((v) => v != id).toList()
      : [...base, id];
}

/// One phase of a session (its authored label) and the seconds spent in it, in order.
class PhaseSpan {
  const PhaseSpan(this.label, this.sec);
  final String label;
  final int sec;
}

/// Consecutive items with the same phase label merged into one span (web `phaseSpans`);
/// unlabelled items count as "Practice". Shows what the inside of a session looks like.
List<PhaseSpan> phaseSpans(List<SessionItem> items) {
  final out = <PhaseSpan>[];
  for (final it in items) {
    final label = (it.p == null || it.p!.isEmpty)
        ? tr('session.phasePractice')
        : it.p!;
    if (out.isNotEmpty && out.last.label == label) {
      out[out.length - 1] = PhaseSpan(label, out.last.sec + it.s);
    } else {
      out.add(PhaseSpan(label, it.s));
    }
  }
  return out;
}

// ------------------------------------------------------------ sessions

/// "warrior-1-left" → "warrior-1": both sides of a pose share one base pose.
String basePoseId(String id) => id.replaceFirst(RegExp(r'-(left|right)$'), '');

/// Different poses in a lesson (both sides and every breath of a flow count once), shown as "N poses".
int poseCount(List<SessionItem> items) =>
    items.map((it) => basePoseId(it.e)).toSet().length;

/// Seconds between items i-1 and i (mirrors the content generator): none inside one
/// breath-paced flow, a short switch between the two sides of one pose, the session rest otherwise.
int gapBefore(List<SessionItem> items, int i, [int restSec = restBetweenSec]) {
  if (i <= 0 || restSec <= 0) return 0;
  final a = items[i - 1], b = items[i];
  if (b.f != null && a.f == b.f) return 0;
  if (a.e != b.e && basePoseId(a.e) == basePoseId(b.e)) {
    return math.min(restSec, 5);
  }
  return restSec;
}

int totalSeconds(List<SessionItem> items, [int restSec = restBetweenSec]) {
  var total = 0;
  for (var i = 0; i < items.length; i++) {
    total += items[i].s + gapBefore(items, i, restSec);
  }
  return total;
}

// ------------------------------------------------------------ guided journey

/// Simple starting shapes the tutor never needs to demonstrate.
const noDemoPoses = {'savasana', 'mountain', 'easy-seat', 'chair-mountain'};

/// Poses and flows this person has already practised in finished sessions.
Set<String> practisedSet(List<HistoryEntry> history) {
  final out = <String>{};
  for (final h in history) {
    if (h.kind != 'workout') continue;
    for (final it
        in resolveSession(h.sessionId)?.items ?? const <SessionItem>[]) {
      out.add(it.f != null ? 'flow:${it.f}' : basePoseId(it.e));
    }
  }
  return out;
}

enum DemoKind { flow, pose }

/// What the tutor demonstrates before item i: the whole sequence at the first movement of a
/// flow, a pose the first time it appears in the session, or nothing. Familiar poses and flows
/// (already practised) skip the demo unless [always]; the second side never repeats it.
DemoKind? demoAt(
  List<SessionItem> items,
  int i,
  Set<String> known, [
  bool always = false,
]) {
  if (i < 0 || i >= items.length) return null;
  final it = items[i];
  if (it.f != null) {
    if (i > 0 && items[i - 1].f == it.f) return null;
    if (items.take(i).any((x) => x.f == it.f)) return null;
    return always || !known.contains('flow:${it.f}') ? DemoKind.flow : null;
  }
  final base = basePoseId(it.e);
  if (noDemoPoses.contains(base)) return null;
  if (items.take(i).any((x) => x.f == null && basePoseId(x.e) == base)) {
    return null;
  }
  return always || !known.contains(base) ? DemoKind.pose : null;
}

/// Item i starts a new round of its flow (the first movement of round 2, 3…).
bool isRoundStart(List<SessionItem> items, int i) {
  if (i < 0 || i >= items.length || items[i].f == null) return false;
  if (i == 0) return true;
  final prev = items[i - 1], it = items[i];
  return prev.f != it.f || prev.r != it.r;
}

/// Number of rounds of the flow block item i belongs to.
int flowRounds(List<SessionItem> items, int i) {
  if (i < 0 || i >= items.length || items[i].f == null) return 0;
  final f = items[i].f;
  var start = i;
  while (start > 0 && items[start - 1].f == f) {
    start--;
  }
  var max = 0;
  for (var k = start; k < items.length && items[k].f == f; k++) {
    max = math.max(max, items[k].r ?? 1);
  }
  return max;
}

// ------------------------------------------------------------ screens: a whole flow is one step

/// First item of the screen item [i] is on: every pose hold is its own screen, a whole run of one
/// flow is one (web `screenStart`).
int screenStart(List<SessionItem> items, int i) {
  if (i < 0 || i >= items.length) return i;
  final f = items[i].f;
  if (f == null) return i;
  var k = i;
  while (k > 0 && items[k - 1].f == f) {
    k--;
  }
  return k;
}

/// One past the last item of the screen item [i] is on.
int screenEnd(List<SessionItem> items, int i) {
  if (i < 0 || i >= items.length) return i + 1;
  final f = items[i].f;
  if (f == null) return i + 1;
  var k = i + 1;
  while (k < items.length && items[k].f == f) {
    k++;
  }
  return k;
}

/// Screens of a lesson ("Step x of y"): pose holds plus one per flow block.
int screenCount(List<SessionItem> items) {
  var n = 0;
  for (var i = 0; i < items.length; i = screenEnd(items, i)) {
    n++;
  }
  return n;
}

/// 0-based screen of item [i].
int screenIndex(List<SessionItem> items, int i) {
  var n = 0;
  final start = screenStart(items, i);
  for (var k = 0; k < items.length && screenEnd(items, k) <= start; k = screenEnd(items, k)) {
    n++;
  }
  return n;
}

/// Seconds left on item [i]'s screen while [remaining] seconds are left on item [i] itself.
double screenRemaining(List<SessionItem> items, int i, double remaining) {
  var s = math.max(0.0, remaining);
  for (var k = i + 1; k < screenEnd(items, i); k++) {
    s += items[k].s;
  }
  return s;
}

/// Seconds of the whole screen item [i] is on.
int screenSeconds(List<SessionItem> items, int i) {
  var s = 0;
  for (var k = screenStart(items, i); k < screenEnd(items, i); k++) {
    s += items[k].s;
  }
  return s;
}

/// First item of the round of the flow that item [i] belongs to (item [i] itself for a pose hold).
int roundStart(List<SessionItem> items, int i) {
  if (i < 0 || i >= items.length || items[i].f == null) return i;
  final it = items[i];
  var k = i;
  while (k > 0 && items[k - 1].f == it.f && items[k - 1].r == it.r) {
    k--;
  }
  return k;
}

/// Movement [i] within its round, 1-based, and the movements in that round ("3 of 10").
({int n, int total}) moveOfRound(List<SessionItem> items, int i) {
  if (i < 0 || i >= items.length || items[i].f == null) return (n: 1, total: 1);
  final it = items[i];
  final start = roundStart(items, i);
  var end = i + 1;
  while (end < items.length && items[end].f == it.f && items[end].r == it.r) {
    end++;
  }
  return (n: i - start + 1, total: end - start);
}

/// The tutor welcomes a person to a course before Day 1 until they have finished a day of it.
bool shouldWelcome(Plan plan, int day, List<int> completedDays) =>
    plan.days.length > 1 &&
    plan.welcome.isNotEmpty &&
    day == 1 &&
    completedDays.isEmpty;

enum CompletionKind { day, course, single }

/// What the completion screen celebrates (web `completionOf`): a course day with tomorrow's
/// preview, the whole course, or one class.
class Completion {
  const Completion(this.kind, {this.day, this.next, this.plan});
  final CompletionKind kind;
  final int? day;
  final PlanDay? next;
  final Plan? plan;
}

Completion completionOf(String? planId, int? day, List<int> completedDays) {
  final plan = planId == null ? null : Content.i.plan(planId);
  if (plan == null || plan.days.length <= 1 || day == null) {
    return const Completion(CompletionKind.single);
  }
  final done = {...completedDays, day};
  if (plan.days.every((d) => done.contains(d.day))) {
    return Completion(CompletionKind.course, plan: plan);
  }
  final next =
      plan.days
          .where((d) => d.day > day && !done.contains(d.day))
          .firstOrNull ??
      plan.days.firstWhere((d) => !done.contains(d.day));
  return Completion(CompletionKind.day, day: day, next: next);
}

/// Rough spoken length of lines (s), used to pace voice-led moments when the voice is off.
double speechSeconds(List<String> lines) {
  var total = 0.0;
  final cjk = RegExp(r'[\u3040-\u30ff\u4e00-\u9fff]');
  for (final l in lines) {
    final t = l.trim();
    if (t.isEmpty) continue;
    final words = cjk.hasMatch(t)
        ? t.replaceAll(RegExp(r'\s'), '').length / 3
        : t.split(RegExp(r'\s+')).length.toDouble();
    total += math.max(1.5, words / 2.5) + 0.4;
  }
  return (total * 10).round() / 10;
}

int kcalForWeight(int baseKcal, double weightKg) =>
    math.max(1, (baseKcal * weightKg / baseWeightKg).round());

int itemsKcal(List<SessionItem> items) => items
    .fold<double>(
      0,
      (s, it) => s + (Content.i.exercise(it.e)?.kcalPerMin ?? 3) * (it.s / 60),
    )
    .round();

String planSessionId(String planId, int day) => 'plan:$planId:$day';

Session? resolveSession(String id) {
  final parts = id.split(':');
  final kind = parts[0];
  final a = parts.length > 1 ? parts[1] : null;
  final b = parts.length > 2 ? parts[2] : null;
  final c = Content.i;
  if (kind == 'quick' && a != null) {
    final q = c.quick(a);
    if (q == null) return null;
    return Session(
      id: id,
      kind: 'quick',
      title: q.title,
      subtitle: q.subtitle,
      image: q.image,
      items: q.items,
      restSec: restBetweenSec,
      baseKcal: q.kcal,
      intro: q.intro,
    );
  }
  if (kind == 'plan' && a != null && b != null) {
    final plan = c.plan(a);
    final dayNum = int.tryParse(b);
    final day = plan?.days.where((d) => d.day == dayNum).firstOrNull;
    if (plan == null || day == null) return null;
    return Session(
      id: id,
      kind: 'plan',
      title: plan.isSingleSession
          ? plan.title
          : tr('common.dayTitle', {'day': day.day, 'title': day.title}),
      subtitle: plan.isSingleSession ? trTag(plan.group) : plan.title,
      image: plan.image,
      items: day.items,
      restSec: restBetweenSec,
      baseKcal: day.kcal,
      planId: plan.id,
      day: day.day,
      intro: day.intro,
    );
  }
  if (kind == 'cat' && a != null) {
    final cat = c.category(a);
    if (cat == null) return null;
    return Session(
      id: id,
      kind: 'category',
      title: cat.name,
      subtitle: cat.tagline,
      image: cat.image,
      items: cat.items,
      restSec: restBetweenSec,
      baseKcal: cat.kcal,
      intro: cat.intro,
    );
  }
  if (kind == 'ex' && a != null) {
    final ex = c.exercise(a);
    if (ex == null) return null;
    final items = [SessionItem(ex.id, ex.durationSec * 2)];
    return Session(
      id: id,
      kind: 'exercise',
      title: ex.name,
      subtitle: tr('session.singlePractice'),
      image: ex.image,
      items: items,
      restSec: 0,
      baseKcal: itemsKcal(items),
    );
  }
  return null;
}

int nextPlanDay(int totalDays, List<int> completed) {
  final done = completed.toSet();
  for (var d = 1; d <= totalDays; d++) {
    if (!done.contains(d)) return d;
  }
  return totalDays;
}

/// Free programs are fully open; premium programs open their first `freeDays` days.
bool isDayLocked(Plan plan, int day, bool premium) =>
    !premium && plan.premium && day > plan.freeDays;

/// A program that cannot be started at all without Asanova Plus.
bool isPlanLocked(Plan plan, bool premium) => isDayLocked(plan, 1, premium);

bool isMeditationLocked(String id, bool premium) {
  final m = Content.i.meditation(id);
  return m != null && m.premium && !premium;
}

/// Player-entry guard: direct routes obey the same day gate as program screens.
bool isSessionLocked(String sessionId, bool premium) {
  final parts = sessionId.split(':');
  if (parts.length != 3 || parts[0] != 'plan') return false;
  final plan = Content.i.plan(parts[1]);
  final day = int.tryParse(parts[2]);
  return plan != null && day != null && isDayLocked(plan, day, premium);
}

// ------------------------------------------------------------ progress

List<String> uniqueDays(List<HistoryEntry> history) =>
    (history.map((h) => dateKey(h.completedAt)).toSet().toList()..sort());

int currentStreak(List<HistoryEntry> history, DateTime today) {
  final days = uniqueDays(history).toSet();
  var cursor = today;
  if (!days.contains(dateKey(cursor))) {
    cursor = addDays(today, -1);
    if (!days.contains(dateKey(cursor))) return 0;
  }
  var streak = 0;
  while (days.contains(dateKey(cursor))) {
    streak++;
    cursor = addDays(cursor, -1);
  }
  return streak;
}

int bestStreak(List<HistoryEntry> history) {
  final days = uniqueDays(history);
  var best = 0, run = 0;
  DateTime? prev;
  for (final key in days) {
    final p = key.split('-').map(int.parse).toList();
    final date = DateTime(p[0], p[1], p[2]);
    if (prev != null && dateKey(addDays(prev, 1)) == key) {
      run++;
    } else {
      run = 1;
    }
    best = math.max(best, run);
    prev = date;
  }
  return best;
}

class Stats {
  final int sessions,
      workouts,
      meditations,
      minutes,
      kcal,
      streak,
      best,
      plansCompleted,
      earlyBird,
      nightOwl;
  const Stats({
    required this.sessions,
    required this.workouts,
    required this.meditations,
    required this.minutes,
    required this.kcal,
    required this.streak,
    required this.best,
    required this.plansCompleted,
    required this.earlyBird,
    required this.nightOwl,
  });
}

Stats computeStats(
  List<HistoryEntry> history,
  DateTime today,
  int plansCompleted,
) {
  final workouts = history.where((h) => h.kind == 'workout').toList();
  return Stats(
    sessions: history.length,
    workouts: workouts.length,
    meditations: history.length - workouts.length,
    minutes: (history.fold<int>(0, (s, h) => s + h.durationSec) / 60).round(),
    kcal: workouts.fold<int>(0, (s, h) => s + h.kcal),
    streak: currentStreak(history, today),
    best: bestStreak(history),
    plansCompleted: plansCompleted,
    earlyBird: history.where((h) => h.completedAt.hour < 8).length,
    nightOwl: history.where((h) => h.completedAt.hour >= 21).length,
  );
}

int achievementValue(Achievement a, Stats s) {
  switch (a.metric) {
    case 'sessions':
      return s.sessions;
    case 'streak':
      return math.max(s.streak, s.best);
    case 'minutes':
      return s.minutes;
    case 'meditations':
      return s.meditations;
    case 'kcal':
      return s.kcal;
    case 'plansCompleted':
      return s.plansCompleted;
    case 'earlyBird':
      return s.earlyBird;
    case 'nightOwl':
      return s.nightOwl;
    default:
      return 0;
  }
}

List<String> unlockedAchievements(Stats s) => Content.i.achievements
    .where((a) => achievementValue(a, s) >= a.threshold)
    .map((a) => a.id)
    .toList();

class DayMinutes {
  final String key, label;
  final int minutes;
  const DayMinutes(this.key, this.label, this.minutes);
}

/// Weekday initials (Sunday first) in the app language.
List<String> get weekLetters => trList('common.weekdayLetters');

List<DayMinutes> weekMinutes(List<HistoryEntry> history, DateTime today) {
  return List.generate(7, (idx) {
    final i = 6 - idx;
    final d = addDays(today, -i);
    final key = dateKey(d);
    final secs = history
        .where((h) => dateKey(h.completedAt) == key)
        .fold<int>(0, (s, h) => s + h.durationSec);
    return DayMinutes(key, weekLetters[d.weekday % 7], (secs / 60).round());
  });
}

// ------------------------------------------------------------ formatting

String formatMinutes(int sec) =>
    tr('common.minShort', {'n': math.max(1, (sec / 60).round())});

String formatClock(num sec) {
  final s = math.max(0, sec.ceil());
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

T dailyPick<T>(List<T> list, DateTime date, [int salt = 0]) =>
    list[(dayOfYear(date) + salt) % list.length];

// ------------------------------------------------------------ onboarding imagery

/// Gender variant used by onboarding photos: men see "m" imagery, everyone else "f".
String genderVariant(String gender) => gender == 'male' ? 'm' : 'f';

/// Resolves an onboarding image template (`onb-age-{g}-18`) for the person's gender.
String onbImage(String template, String gender) =>
    template.replaceAll('{g}', genderVariant(gender));

/// Option label, using the male wording when one exists and the person identifies as male.
String onbLabel(String label, String? labelM, String gender) =>
    gender == 'male' && labelM != null ? labelM : label;

// ------------------------------------------------------------ saved privacy field

/// Legacy saved-state version. Asanova has no advertising or tracking choice.
const privacyNoticeVersion = 1;

// ------------------------------------------------------------ paywall offer

/// Which paywall variant to show. The first paywall is `standard` (normal price, no trial);
/// during onboarding the requested variant is shown (standard → regular / exit / gift);
/// afterwards the app always repeats the last offer the person was shown, so the in-app price
/// never rises and a first checkout never silently starts a trial.
String paywallVariant(String from, String requested, String? savedOffer) {
  if (from == 'onboarding') return requested;
  return savedOffer ?? 'standard';
}

/// The "what's holding you back?" question is asked once ever, only when the
/// normal-price (standard or trial) paywall is closed.
bool shouldAskExitSurvey(String variant, bool alreadyAsked) =>
    (variant == 'standard' || variant == 'regular') && !alreadyAsked;

/// Offer revealed after the exit survey: "the price feels high" → the lower yearly exit offer;
/// "check first" / "not sure" → the 7-day trial plan, or the lower price when the store says
/// this person cannot get the trial (e.g. subscribed before), so an answer is never ignored;
/// dismissed → none. A reveal only shows the offer: it never starts a trial or grants Plus.
/// Mirrors web `paywallSurveyOffer`.
String? paywallSurveyOffer(String? reason, {bool trialAvailable = true}) =>
    switch (reason) {
      'price' => 'exit',
      'later' || 'unsure' => trialAvailable ? 'regular' : 'exit',
      _ => null,
    };

// ---------------------------------------------------------------------------
// Breath meditations: the narrator settles the person first, then the circle
// starts; the breath phase is derived from the meditation clock so seeking,
// pausing and narration can never drift apart (web `breathStartSec`/`breathAt`).

/// Second the guided breath cycle begins: after the settle + instruction lines.
int breathStartSec(List<int> scriptTimes) =>
    scriptTimes.length >= 3 ? scriptTimes[2] : 0;

/// Phase (0 inhale, 1 hold, 2 exhale, 3 rest) at [sec] seconds since the
/// cycle began, whole seconds left, phase length, cycle count and whether the
/// phase starts exactly on this second. Null before the cycle starts.
({int phase, int left, int duration, int cycle, bool starts})? breathAt(
  List<int> pattern,
  int sec,
) {
  final len = pattern.fold<int>(0, (a, b) => a + b);
  if (sec < 0 || len <= 0) return null;
  final cycle = sec ~/ len;
  final o = sec % len;
  var start = 0;
  for (var i = 0; i < 4; i++) {
    final d = pattern[i];
    if (d > 0 && o < start + d) {
      return (
        phase: i,
        left: d - (o - start),
        duration: d,
        cycle: cycle,
        starts: o == start,
      );
    }
    start += d;
  }
  return null;
}

/// Spoken "breathe in / out" cues only teach the first two rounds.
bool breathCueDue(List<int> pattern, int sec) {
  final b = breathAt(pattern, sec);
  return b != null && b.starts && b.cycle < 2;
}

// ------------------------------------------------------------ over-the-air content

/// Content compatibility both clients understand; a server update with another schema is ignored.
/// Bumped when content needs this build's code or media: 2 = meditation timings measured on the
/// `voice-aac-lc-64-v2` narration, which older builds (schema 1, older clips) must never apply.
const int kContentSchema = 2;

typedef OtaFile = ({String hash, int bytes});
typedef OtaCached = ({int schema, int seq, String hash});

String? _otaHash(Object? f) => f is String ? f : (f is Map ? f['hash'] as String? : null);

/// The content file to download for [lang], or null when the app already has the newest.
/// [base] is the bundled `ota-base.json`, [remote] the server's `content/ota.json`.
OtaFile? otaPick(Map<String, dynamic> base, Map<String, dynamic>? remote, String lang, OtaCached? cached) {
  if (remote == null || remote['schema'] != kContentSchema) return null;
  final seq = (remote['seq'] as num?)?.toInt() ?? 0;
  if (seq <= ((base['seq'] as num?)?.toInt() ?? 0)) return null;
  final f = (remote['files'] as Map?)?[lang];
  if (f is! Map) return null;
  final hash = f['hash'] as String?;
  final bytes = (f['bytes'] as num?)?.toInt() ?? 0;
  if (hash == null || hash.isEmpty || bytes <= 0) return null;
  if (hash == _otaHash((base['files'] as Map?)?[lang])) return null;
  if (cached != null && cached.hash == hash && cached.seq >= seq) return null;
  return (hash: hash, bytes: bytes);
}

/// Use the downloaded content instead of the bundled one only when it is newer and readable.
bool otaUseCached(Map<String, dynamic> base, OtaCached? cached) =>
    cached != null && cached.schema == kContentSchema && cached.seq > ((base['seq'] as num?)?.toInt() ?? 0);

/// A downloaded content file is only kept when it is complete and has the shape the app reads.
bool otaValid(Object? json) {
  if (json is! Map) return false;
  bool list(String k) => json[k] is List && (json[k] as List).isNotEmpty;
  return list('exercises') && list('plans') && list('meditations') && json['ui'] is Map;
}
