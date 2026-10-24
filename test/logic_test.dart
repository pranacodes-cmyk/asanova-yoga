// Mirrors src/lib/logic.test.ts — the same rules must hold on Android and web.
import 'dart:convert';
import 'dart:io';

import 'package:asanova/data/content.dart';
import 'package:asanova/data/models.dart';
import 'package:asanova/logic/coach.dart';
import 'package:asanova/logic/logic.dart';
import 'package:asanova/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryEntry entry(DateTime d) => HistoryEntry(
  id: d.toIso8601String(),
  sessionId: 'quick:desk-reset',
  title: 'Desk',
  kind: 'workout',
  image: 'quick-desk',
  completedAt: d,
  durationSec: 300,
  kcal: 10,
);

void main() {
  late Map<String, dynamic> json;
  setUpAll(() {
    json = jsonDecode(
      File('assets/data/content.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    Content.loadFromJson(json);
  });

  group('shared content', () {
    final webFile = File('../src/data/content.json');
    test(
      'Android ships the same content as the web app',
      () {
        final web = webFile.readAsStringSync();
        expect(jsonEncode(jsonDecode(web)), jsonEncode(json));
      },
      skip: webFile.existsSync()
          ? false
          : 'web project not present in this checkout',
    );
    test(
      'ships exactly the curated movements that programs and classes use',
      () {
        final c = Content.i;
        final used = {
          for (final p in c.plans)
            for (final d in p.days)
              for (final it in d.items) it.e,
          for (final q in c.quickSessions)
            for (final it in q.items) it.e,
          for (final cat in c.categories)
            for (final it in cat.items) it.e,
        };
        final browsable = {for (final cat in c.categories) ...cat.exerciseIds};
        final shipped = {for (final e in c.exercises) e.id};
        expect(
          shipped
              .where((id) => !used.contains(id) && !browsable.contains(id))
              .toList(),
          isEmpty,
        );
        expect(used.where((id) => !shipped.contains(id)).toList(), isEmpty);
        for (final cat in c.categories) {
          expect(cat.exerciseIds.every(shipped.contains), isTrue);
        }
      },
    );
    test('free offer: 3 quick sessions + the 7-day starter + 4 meditations, everything else fully paid', () {
      final c = Content.i;
      final starter = c.plans.firstWhere((p) => p.id == freeStarterId);
      expect(starter.days.length, 7);
      for (final p in c.plans) {
        final free =
            c.quickSessions.any((q) => q.id == p.id) || p.id == freeStarterId;
        expect(
          [p.premium, p.freeDays],
          free ? [false, p.days.length] : [true, 0],
          reason: p.id,
        );
      }
      expect(c.meditations.where((m) => !m.premium).length, 4);
    });
    test('the free starter is the only free course', () {
      final free = Content.i.challengeIds
          .where((id) => !Content.i.plan(id)!.premium)
          .toList();
      expect(free, [freeStarterId]);
    });
    test('free quick sessions run 10, 5 and 8 minutes including rests', () {
      expect(
        {for (final q in Content.i.quickSessions) q.id: totalSeconds(q.items)},
        {'morning-wake-up': 600, 'desk-reset': 300, 'evening-unwind': 480},
      );
    });
    test('every program day references a real exercise', () {
      final missing = [
        for (final p in Content.i.plans)
          for (final d in p.days)
            for (final it in d.items)
              if (Content.i.exercise(it.e) == null) '${p.id}:${d.day}:${it.e}',
      ];
      expect(missing, isEmpty);
    });
    test('no two single-session routines are the same class', () {
      final seqs = [
        for (final p in Content.i.plans)
          if (p.days.length == 1)
            p.days.first.items.map((it) => it.e).join(','),
      ];
      expect(seqs.toSet().length, seqs.length);
    });
    test('multi-day programs never repeat one class for a whole week', () {
      for (final p in Content.i.plans.where((x) => x.days.length >= 7)) {
        for (var start = 0; start + 7 <= p.days.length; start++) {
          final week = {
            for (final d in p.days.sublist(start, start + 7))
              d.items.map((it) => it.e).join(','),
          };
          expect(
            week.length,
            greaterThanOrEqualTo(4),
            reason: '${p.id} days ${start + 1}-${start + 7}',
          );
        }
      }
    });
    test('daily practices are Chair Yoga 21 and Daily Yoga 28', () {
      expect(Content.i.dailyPlanIds, ['chair-yoga-21', 'daily-yoga-28']);
      expect(Content.i.plan('chair-yoga-21')!.days.length, 21);
      expect(Content.i.plan('daily-yoga-28')!.days.length, 28);
    });
    test('the catalogue ships 18 courses and 25 single sessions, every one on a shelf', () {
      final c = Content.i;
      final courses = c.plans.where((p) => p.days.length > 1).toList();
      final sessions = c.plans.where((p) => p.days.length == 1).toList();
      expect(courses.length, 18);
      expect(sessions.length, 25);
      for (final p in courses) {
        expect(c.planGroups, contains(p.group));
      }
      for (final p in sessions) {
        expect([...c.planGroups, 'Quick & free'], contains(p.group));
      }
    });
    test('Yoga Foundations promises and schedules 21 labelled lessons', () {
      final p = Content.i.plan('yoga-foundations-21')!;
      expect(p.days.length, 21);
      expect(p.subtitle, contains('21 days'));
      for (final d in p.days) {
        expect(d.items.every((it) => it.p != null), isTrue);
        expect(d.items.last.p, 'Settle');
      }
    });
    test('no third-party hosted media ships with the app', () {
      expect(jsonEncode(json).contains('firebasestorage'), isFalse);
    });
  });

  group('body metrics', () {
    test('computes BMI to one decimal', () => expect(bmi(170, 70), 24.2));
    test('classifies BMI bands', () {
      expect(bmiCategory(18.4), 'Underweight');
      expect(bmiCategory(24.9), 'Healthy');
      expect(bmiCategory(25), 'Overweight');
      expect(bmiCategory(30), 'Obese');
    });
    test('predicts 0.5 kg per week, at least 4 and at most 26 weeks', () {
      expect(predictWeeks(80, 75), 10);
      expect(predictWeeks(70, 69), 4);
      expect(predictWeeks(120, 70), 26);
    });
  });

  group('personal plan', () {
    String rec({
      List<String> goals = const [],
      String style = '',
      List<String> limitations = const [],
      String ageGroup = '30-39',
      String experience = '',
      String strengthCheck = '',
    }) => recommendPlanId(
      goals: goals,
      style: style,
      limitations: limitations,
      ageGroup: ageGroup,
      experience: experience,
      strengthCheck: strengthCheck,
    );
    test('limited mobility and chair style start Chair Yoga', () {
      expect(rec(limitations: ['mobility']), 'chair-yoga-21');
      expect(rec(style: 'chair'), 'chair-yoga-21');
    });
    test('style answers choose the matching yoga course', () {
      expect(rec(style: 'wall'), 'wall-yoga-14');
      expect(rec(style: 'restorative'), 'yin-sleep-14');
      expect(rec(style: 'power'), 'strength-21');
      expect(rec(style: 'vinyasa'), 'daily-yoga-28');
      expect(rec(), 'yoga-foundations-21');
    });
    test(
      'newcomers stay on gentle foundations even when they pick a strong style',
      () {
        expect(rec(style: 'power', experience: 'new'), 'yoga-foundations-21');
        expect(rec(style: 'vinyasa', experience: 'new'), 'sun-salutation-14');
      },
    );
    test(
      "people who can't hold Downward Dog yet never start the strength course",
      () {
        expect(
          rec(style: 'power', experience: 'dedicated', strengthCheck: 'notyet'),
          'yoga-foundations-21',
        );
        expect(
          rec(goals: ['core'], experience: 'regular', strengthCheck: 'notyet'),
          'yoga-foundations-21',
        );
        expect(
          rec(style: 'power', experience: 'regular', strengthCheck: 'unsure'),
          'yoga-foundations-21',
        );
        expect(
          rec(style: 'power', experience: 'regular', strengthCheck: 'effort'),
          'strength-21',
        );
      },
    );
    test('back needs start Healthy Back', () {
      expect(rec(limitations: ['back']), 'back-care-14');
      expect(rec(goals: ['back']), 'back-care-14');
    });
    test(
      'strength goal starts Strong Yoga only for people who already practise',
      () {
        expect(rec(goals: ['core'], experience: 'regular'), 'strength-21');
        expect(rec(goals: ['core'], experience: 'dedicated'), 'strength-21');
        expect(rec(goals: ['core'], experience: 'new'), 'yoga-foundations-21');
      },
    );
    test("'none' excludes every other gentler-option answer", () {
      expect(toggleExclusive(['wrists', 'knees'], 'none', 'none'), ['none']);
      expect(toggleExclusive(['none'], 'wrists', 'none'), ['wrists']);
      expect(toggleExclusive(['wrists', 'knees'], 'wrists', 'none'), ['knees']);
      expect(toggleExclusive(['none'], 'none', 'none'), <String>[]);
    });
    test('session phases merge consecutive labels in order', () {
      final spans = phaseSpans(const [
        SessionItem('a', 30, 'Warm-up'),
        SessionItem('b', 40, 'Warm-up'),
        SessionItem('c', 50, 'New today'),
        SessionItem('d', 20),
        SessionItem('e', 60, 'Settle'),
      ]);
      expect(spans.map((s) => '${s.label}:${s.sec}').toList(), [
        'Warm-up:70',
        'New today:50',
        'Practice:20',
        'Settle:60',
      ]);
    });
    test('daily practice is seated for limited mobility', () {
      expect(
        dailyPlanId(limitations: ['mobility'], style: ''),
        'chair-yoga-21',
      );
      expect(dailyPlanId(limitations: [], style: 'vinyasa'), 'daily-yoga-28');
    });
  });

  group('sessions & premium', () {
    test('free programs are open on every day', () {
      final desk = Content.i.plan('desk-reset')!;
      expect(isDayLocked(desk, 1, false), false);
    });
    test('paid courses are fully locked from day 1 without Asanova Plus', () {
      final plan = Content.i.plan('yoga-foundations-21')!;
      expect(isDayLocked(plan, 1, false), true);
      expect(isDayLocked(plan, 4, false), true);
      expect(isDayLocked(plan, 4, true), false);
    });
    test('one meditation per everyday need is free', () {
      expect(
        Content.i.meditations.where((m) => !m.premium).map((m) => m.id).toList()
          ..sort(),
        ['box-breathing', 'evening-wind-down', 'morning-clarity', 'ocean-calm'],
      );
    });
    test('Ancient paths ships six premium courses and three premium classes, with no free days', () {
      final ancient = Content.i.plans
          .where((p) => p.group == 'Ancient paths')
          .toList();
      expect(
        ancient.where((p) => p.days.length > 1).map((p) => p.id).toList(),
        [
          'chakra-journey-14',
          'eight-limbs-8',
          'classical-hatha-14',
          'surya-chandra-10',
          'ashtanga-primer-14',
          'dosha-balance-9',
        ],
      );
      expect(
        ancient.where((p) => p.days.length == 1).map((p) => p.id).toList(),
        ['seven-chakra-flow', 'moon-salutation', 'rishikesh-hatha'],
      );
      for (final p in ancient) {
        expect(p.premium, true);
        expect(p.freeDays, 0);
      }
    });
    test('ships 36 meditations, each line spoken once', () {
      final meds = Content.i.meditations;
      expect(meds.length, 36);
      for (final m in meds) {
        expect(m.script.map((l) => l.text).toSet().length, m.script.length);
      }
    });
    test('the player route cannot bypass a locked premium day', () {
      expect(isSessionLocked('plan:yoga-foundations-21:1', false), true);
      expect(isSessionLocked('plan:yoga-foundations-21:4', false), true);
      expect(isSessionLocked('plan:yoga-foundations-21:4', true), false);
      expect(isSessionLocked('quick:desk-reset', false), false);
    });
    test('chair and wall classes are labelled with their equipment', () {
      for (final id in [
        'chair-yoga-21',
        'chair-yoga-break',
        'seated-stretch',
        'neck-shoulder-release',
        'desk-reset',
      ]) {
        expect(Content.i.plan(id)!.equipment, 'chair', reason: id);
      }
      for (final id in ['wall-yoga-14', 'wall-yoga-reset']) {
        expect(Content.i.plan(id)!.equipment, 'wall', reason: id);
      }
    });
    test('premium single classes are locked without Asanova Plus', () {
      final p = Content.i.plan('core-power')!;
      expect(isPlanLocked(p, false), true);
      expect(isPlanLocked(p, true), false);
    });
    test(
      'adds 10s rest between exercises',
      () => expect(
        totalSeconds(const [SessionItem('a', 60), SessionItem('b', 60)]),
        130,
      ),
    );
    test(
      'scales calories by body weight against a 70 kg baseline',
      () => expect(kcalForWeight(35, 84), 42),
    );
    test('resolves plan day sessions', () {
      final s = resolveSession('plan:daily-yoga-28:2');
      expect(s?.day, 2);
      expect(s!.items.length, greaterThan(3));
      expect(s.title, startsWith('Day 2 · '));
    });
    test(
      'next plan day is the first not yet completed',
      () => expect(nextPlanDay(28, [1, 2, 4]), 3),
    );
  });

  group('streaks', () {
    final today = DateTime(2026, 10, 17, 12);
    test('counts consecutive days ending today', () {
      expect(
        currentStreak([
          entry(DateTime(2026, 10, 15, 9)),
          entry(DateTime(2026, 10, 16, 9)),
          entry(DateTime(2026, 10, 17, 9)),
        ], today),
        3,
      );
    });
    test('keeps the streak alive until the end of today', () {
      expect(
        currentStreak([
          entry(DateTime(2026, 10, 15, 9)),
          entry(DateTime(2026, 10, 16, 9)),
        ], today),
        2,
      );
    });
    test(
      'breaks after a missed day',
      () => expect(currentStreak([entry(DateTime(2026, 10, 14, 9))], today), 0),
    );
    test('finds the best streak', () {
      expect(
        bestStreak(
          [1, 2, 3, 5, 6].map((d) => entry(DateTime(2026, 10, d, 9))).toList(),
        ),
        3,
      );
    });
  });

  group('app state', () {
    test('completing a plan day records progress once', () {
      final s = AppState.memory();
      s.completeOnboarding('yoga-foundations-21');
      final e = HistoryEntry(
        id: 'x',
        sessionId: 'plan:yoga-foundations-21:1',
        title: 'Day 1',
        kind: 'workout',
        image: 'cov-yoga-foundations-21',
        completedAt: DateTime.now(),
        durationSec: 600,
        kcal: 30,
        planId: 'yoga-foundations-21',
        day: 1,
      );
      s.completeSession(e);
      s.completeSession(e);
      expect(s.planProgress['yoga-foundations-21']!.completedDays, [1]);
      expect(s.history.length, 2);
    });
    test('state survives a JSON round trip', () {
      final s = AppState.memory();
      s.setProfile((p) => p.name = 'Mohit');
      s.setPremium('yearly');
      final restored =
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      expect(restored['profile']['name'], 'Mohit');
      expect(restored['premium']['plan'], 'yearly');
    });
  });

  group('onboarding opening', () {
    test('opens straight with the breath chapter, no welcome host film', () {
      expect(Content.i.onboardingHost, isNull);
      expect(Content.i.onboardingChapters.any((c) => c.host != null), isFalse);
      expect(Content.i.onboardingChapters.first.breath, isTrue);
    });
    test('his breath cues have natural-voice clips', () {
      for (final p in [CoachBreath.inhale, CoachBreath.exhale]) {
        for (final l in CoachLines.onbBreath(p)) {
          expect(Content.i.voice.contains(voiceKey(l)), isTrue, reason: l);
        }
      }
    });
  });

  group('onboarding imagery', () {
    test('men see male photos, everyone else the female set', () {
      expect(genderVariant('male'), 'm');
      expect(genderVariant('female'), 'f');
      expect(genderVariant('other'), 'f');
    });
    test('resolves gender templates for age and body photos', () {
      expect(onbImage('onb-age-{g}-50', 'male'), 'onb-age-m-50');
      expect(onbImage('onb-body-{g}-plus', 'female'), 'onb-body-f-plus');
      expect(onbImage('onb-proof', 'male'), 'onb-proof');
    });
    test('uses male wording only when provided', () {
      expect(onbLabel('Curvy', 'Stocky', 'male'), 'Stocky');
      expect(onbLabel('Curvy', 'Stocky', 'female'), 'Curvy');
      expect(onbLabel('Slim', null, 'male'), 'Slim');
    });
    test('every templated onboarding photo exists for both genders', () {
      final keys = Content.i.onboarding
          .expand(
            (s) => [s.image ?? '', ...s.options.map((o) => o.image ?? '')],
          )
          .where((k) => k.isNotEmpty);
      for (final k in keys) {
        for (final g in ['male', 'female']) {
          expect(
            Content.i.imageFocus.containsKey(onbImage(k, g)),
            isTrue,
            reason: onbImage(k, g),
          );
        }
      }
    });
  });

  group('demo films', () {
    test('every movement has its own bundled demo film', () {
      final moves = Content.i.exercises.where((e) => !e.isAffirmation).toList();
      expect(moves.every((e) => e.demo != null), isTrue);
      for (final d in moves.map((e) => e.demo!).toSet()) {
        expect(File('assets/video/$d.mp4').existsSync(), isTrue, reason: d);
      }
    });
  });

  group('coach voice', () {
    test('hashes lines identically across clients', () {
      expect(voiceKey('Breathe in'), 'v1c9247bd');
      expect(voiceKey('Session complete. Beautifully done.'), 'vd714375a');
      expect(voiceKey('Yoga · योग — calm'), 'veb0a5329');
    });
    test('every line the players speak has a natural-voice clip or recorded provider refusal', () {
      final blockedFile =
          [
            File('../scripts/content/voice-blocked.json'),
            File('test/voice-blocked.json'),
          ].firstWhere(
            (f) => f.existsSync(),
            orElse: () => File('test/voice-blocked.json'),
          );
      final blocked = blockedFile.existsSync()
          ? (jsonDecode(blockedFile.readAsStringSync()) as Map).keys.toSet()
          : <dynamic>{};
      final missing = <String>[];
      void check(List<String> lines) {
        for (final line in lines) {
          final k = voiceKey(line);
          if (!Content.i.voice.contains(k) && !blocked.contains(k)) {
            missing.add(line);
          }
        }
      }

      final first = Content.i.exercises.first;
      check(CoachLines.begin(first));
      check(CoachLines.rest(first));
      check(CoachLines.finish());
      check(CoachLines.preview());
      for (final p in CoachBreath.values) {
        check(CoachLines.breath(p));
      }
      for (final e in Content.i.exercises) {
        check(CoachLines.start(e));
        for (var k = 0; k < e.steps.length; k++) {
          check(CoachLines.step(e, k));
        }
        if (e.isAffirmation) check(CoachLines.halfway(e, ''));
      }
      check(Content.i.affirmations);
      for (final m in Content.i.meditations) {
        check([for (final l in m.script) l.text]);
      }
      for (final g in Content.i.guides) {
        check(CoachLines.guide(g));
      }
      expect(missing, isEmpty);
      for (final k in Content.i.voice) {
        expect(File('assets/voice/$k.m4a').existsSync(), isTrue, reason: k);
      }
    });
    test('every movement has 3 to 5 spoken steps and a coach tip', () {
      expect(
        Content.i.exercises.where(
          (e) =>
              !e.isAffirmation &&
              (e.steps.length < 3 || e.steps.length > 5 || e.tip == null),
        ),
        isEmpty,
      );
    });
  });

  group('paywall offer', () {
    test('onboarding shows the requested variant', () {
      expect(paywallVariant('onboarding', 'exit', null), 'exit');
    });
    test('in the app the last onboarding offer is repeated', () {
      expect(paywallVariant('plan', 'regular', 'exit'), 'exit');
      expect(paywallVariant('home', 'regular', 'gift'), 'gift');
      expect(paywallVariant('home', 'regular', null), 'regular');
    });
    test('exit survey is asked only once, only on the regular paywall', () {
      expect(shouldAskExitSurvey('regular', false), isTrue);
      expect(shouldAskExitSurvey('regular', true), isFalse);
      expect(shouldAskExitSurvey('exit', false), isFalse);
    });
    test('saved offer and survey flag survive a save', () {
      final s = AppState.memory()
        ..setPaywallOffer('exit')
        ..markExitSurveyAsked();
      final j = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      expect(j['paywallOffer'], 'exit');
      expect(j['exitSurveyAsked'], true);
    });
  });

  group('today free lead', () {
    test('features a free session by time of day', () {
      expect(freePickQuickId(7), 'morning-wake-up');
      expect(freePickQuickId(14), 'desk-reset');
      expect(freePickQuickId(21), 'evening-unwind');
      expect(freePickQuickId(2), 'evening-unwind');
    });
    test('features the next unfinished starter day, then hands back to quick sessions', () {
      expect(freeStarterDay(7, []), 1);
      expect(freeStarterDay(7, [1, 2]), 3);
      expect(freeStarterDay(7, [1, 3]), 2);
      expect(freeStarterDay(7, [1, 2, 3, 4, 5, 6, 7]), null);
      final s = Content.i.plan(freeStarterId)!;
      expect([s.premium, s.freeDays, s.days.length], [false, 7, 7]);
    });
    test('leads with free only when the personal plan is locked', () {
      expect(homeLeadsWithFree(true), true);
      expect(homeLeadsWithFree(false), false);
    });
  });

  group('rating prompt', () {
    test('asks once per day after a session until rated', () {
      expect(shouldAskRating(false, null, '2026-10-23'), true);
      expect(shouldAskRating(false, '2026-10-23', '2026-10-23'), false);
      expect(shouldAskRating(false, '2026-10-22', '2026-10-23'), true);
      expect(shouldAskRating(true, '2026-10-22', '2026-10-23'), false);
    });
    test('sends 4-5 stars to the store, 1-3 to feedback', () {
      expect(ratingGoesToStore(5), true);
      expect(ratingGoesToStore(4), true);
      expect(ratingGoesToStore(3), false);
    });
  });

  test(
    'Breathe now leads with the free box breathing, then classic pranayama',
    () {
      expect(breatheNowIds, [
        'box-breathing',
        'alternate-nostril',
        'bhramari-bee',
        'moon-breath',
        'cooling-breath',
      ]);
      expect(chakraJourneyId, 'chakra-journey');
    },
  );

  test('pose of the day uses one side of mat poses only', () {
    expect(isPoseOfDayCandidate('tree-right', 'balance'), true);
    expect(isPoseOfDayCandidate('tree-left', 'balance'), false);
    expect(isPoseOfDayCandidate('chair-twist-right', 'chair'), false);
    expect(isPoseOfDayCandidate('wall-dog', 'wall'), false);
    expect(isPoseOfDayCandidate('nadi-shodhana', 'breath'), false);
    expect(isPoseOfDayCandidate('downward-dog', 'sun'), true);
  });

  test('featured meditation is free for people without Plus', () {
    expect(featuredMeditationId(20, false), 'evening-wind-down');
    expect(featuredMeditationId(20, true), 'yoga-nidra');
    expect(featuredMeditationId(8, false), 'morning-clarity');
  });
}
