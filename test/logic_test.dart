// Mirrors src/lib/logic.test.ts — the same rules must hold on Android and web.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:enso/data/content.dart';
import 'package:enso/data/models.dart';
import 'package:enso/i18n/i18n.dart';
import 'package:enso/logic/coach.dart';
import 'package:enso/logic/lesson_media.dart';
import 'package:enso/logic/logic.dart';
import 'package:enso/state/app_state.dart';
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
    test('free offer: 3 quick sessions + Days 1–2 of the 30-day journey + 4 meditations, everything else fully paid', () {
      final c = Content.i;
      final starter = c.plans.firstWhere((p) => p.id == freeStarterId);
      expect(starter.days.length, 30);
      for (final p in c.plans) {
        final free = c.quickSessions.any((q) => q.id == p.id);
        expect(
          [p.premium, p.freeDays],
          free ? [false, p.days.length] : [true, p.id == freeStarterId ? 2 : 0],
          reason: p.id,
        );
      }
      expect(c.meditations.where((m) => !m.premium).length, 4);
    });
    test('no multi-day course is fully free; the journey is the only one with free days', () {
      final free = Content.i.challengeIds
          .where((id) => !Content.i.plan(id)!.premium)
          .toList();
      expect(free, isEmpty);
      expect(
        Content.i.plans
            .where((p) => p.premium && p.freeDays > 0)
            .map((p) => p.id)
            .toList(),
        [freeStarterId],
      );
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
      expect(rec(), 'yoga-journey-30');
    });
    test(
      'newcomers stay on gentle foundations even when they pick a strong style',
      () {
        expect(rec(style: 'power', experience: 'new'), 'yoga-journey-30');
        expect(rec(style: 'vinyasa', experience: 'new'), 'sun-salutation-14');
      },
    );
    test(
      "people who can't hold Downward Dog yet never start the strength course",
      () {
        expect(
          rec(style: 'power', experience: 'dedicated', strengthCheck: 'notyet'),
          'yoga-journey-30',
        );
        expect(
          rec(goals: ['core'], experience: 'regular', strengthCheck: 'notyet'),
          'yoga-journey-30',
        );
        expect(
          rec(style: 'power', experience: 'regular', strengthCheck: 'unsure'),
          'yoga-journey-30',
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
        expect(rec(goals: ['core'], experience: 'new'), 'yoga-journey-30');
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
    test('the 30-day journey: Days 1 and 2 are free, Day 3 onwards needs Asanova Plus', () {
      final j = Content.i.plan('yoga-journey-30')!;
      expect(isDayLocked(j, 1, false), false);
      expect(isDayLocked(j, 2, false), false);
      expect(isDayLocked(j, 3, false), true);
      expect(isDayLocked(j, 30, false), true);
      expect(isDayLocked(j, 3, true), false);
      expect(freeDayCount(j), 2);
    });
    test(
      "the journey's first week is beginner-safe: floor first, no straight-leg folds, Downward Dog only from Day 8",
      () {
        final j = Content.i.plan('yoga-journey-30')!;
        final week1 = j.days
            .where((d) => d.day <= 7)
            .expand((d) => d.items.map((it) => basePoseId(it.e)))
            .toList();
        for (final hard in [
          'forward-fold',
          'downward-dog',
          'plank',
          'chaturanga',
          'cobra',
          'pigeon',
          'triangle',
          'crow',
          'wheel',
          'boat',
        ]) {
          expect(week1, isNot(contains(hard)), reason: hard);
        }
        final day1 = j.days.first.items
            .map((it) => Content.i.exercise(it.e)!.category)
            .toList();
        expect(day1, isNot(contains('standing')));
        expect(
          j.days.firstWhere((d) => d.day == 8).learn,
          contains('downward-dog'),
        );
      },
    );
    test('counts different poses: both sides and every breath of a flow once', () {
      expect(
        poseCount(const [
          SessionItem('warrior-1-right', 30),
          SessionItem('warrior-1-left', 30),
          SessionItem('upward-salute', 5),
          SessionItem('upward-salute', 5),
          SessionItem('savasana', 60),
        ]),
        3,
      );
      final d15 = Content.i.plan('yoga-journey-30')!.days[14].items;
      expect(poseCount(d15), lessThan(d15.length));
    });
    test('names what a day teaches without sides and finds its stage', () {
      expect(
        learnNames(['supine-twist-right', 'flow:half-sun', 'supine-twist-left']),
        ['Supine Spinal Twist', 'Half Sun Salutation'],
      );
      final j = Content.i.plan('yoga-journey-30')!;
      expect(
        [1, 7, 8, 21, 29, 30].map((d) => chapterOf(j, d)?.title).toList(),
        ['Arrive', 'Arrive', 'Build', 'Flow', 'Integrate', 'Integrate'],
      );
      expect(chapterOf(Content.i.plan('yoga-foundations-21')!, 1), isNull);
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
    test('every meditation has its own script, with only the safety and eyes-open lines shared', () {
      final meds = Content.i.meditations;
      final scripts = meds.map((m) => m.script.map((l) => l.text.toLowerCase()).join('|')).toSet();
      expect(scripts.length, meds.length);
      final owners = <String, Set<String>>{};
      for (final m in meds) {
        for (final l in m.script) {
          owners.putIfAbsent(l.text.trim().toLowerCase(), () => <String>{}).add(m.id);
        }
      }
      final shared = owners.entries.where((e) => e.value.length > 1).map((e) => e.key).toList()..sort();
      expect(shared, [
        'gently open your eyes.',
        'if you feel light-headed or uneasy at any point, let the technique go and simply breathe naturally.',
        'open your eyes when you are ready.',
      ]);
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
      s.completeOnboarding('standing-tai-chi');
      final e = HistoryEntry(
        id: 'x',
        sessionId: 'plan:standing-tai-chi:1',
        title: 'Day 1',
        kind: 'workout',
        image: 'prog-standing-taichi',
        completedAt: DateTime.now(),
        durationSec: 600,
        kcal: 30,
        planId: 'standing-tai-chi',
        day: 1,
      );
      s.completeSession(e);
      s.completeSession(e);
      expect(s.planProgress['standing-tai-chi']!.completedDays, [1]);
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
    final bundled = jsonDecode(
      File('test/bundled-media.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final bundledFilms = (bundled['films'] as List).cast<String>();
    test('every movement and flow has a film on the media server', () {
      final moves = Content.i.exercises.where((e) => !e.isAffirmation).toList();
      expect(moves.every((e) => e.demo != null), isTrue);
      final uploaded = jsonDecode(
        File('test/remote-media.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final d in {
        ...moves.map((e) => e.demo!),
        for (final f in Content.i.flows)
          if (f.demo != null) f.demo!,
        kTutorWelcomeFilm,
        kTutorCongratsFilm,
      }) {
        expect(uploaded.containsKey(filmPath(d)), isTrue, reason: d);
      }
    });
    test('the app bundles only the onboarding, paywall and tutor films', () {
      expect(bundledFilms, contains(kTutorWelcomeFilm));
      expect(bundledFilms, contains(kTutorCongratsFilm));
      expect(bundledFilms.length, lessThanOrEqualTo(12));
      final shipped =
          Directory('assets/video')
              .listSync()
              .map((f) => f.uri.pathSegments.last)
              .where((n) => n.endsWith('.mp4'))
              .map((n) => n.substring(0, n.length - 4))
              .toList()
            ..sort();
      expect(shipped, [...bundledFilms]..sort());
    });
  });

  group('lesson media', () {
    late Session day1;
    const fresh = JourneyOptions(known: {}, demos: true, welcome: true);
    setUp(() => day1 = resolveSession('plan:yoga-journey-30:1')!);
    test('a first course day downloads the tutor welcome first and her celebration', () {
      final paths = sessionMediaPaths(day1, fresh, Content.i.voice);
      expect(paths.first, 'video/yf-tutor-welcome.mp4');
      expect(paths, contains('video/yf-tutor-congrats.mp4'));
      expect(paths.toSet().length, paths.length);
    });
    test('a flow day downloads its continuous round films, never the old per-breath clips', () {
      final day = Content.i
          .plan('yoga-journey-30')!
          .days
          .firstWhere((d) => d.items.any((it) => it.f != null && it.k == 1));
      final s = resolveSession('plan:yoga-journey-30:${day.day}')!;
      final paths = sessionMediaPaths(
        s,
        const JourneyOptions(known: {}, demos: true, welcome: false),
        Content.i.voice,
      );
      final flow = Content.i.flow(
        s.items.firstWhere((it) => it.f != null && it.k == 1).f,
      )!;
      for (final f in flow.round!.films) {
        expect(paths, contains('video/$f.mp4'));
      }
      expect(paths.where((p) => p.startsWith('video/yt-')), isEmpty);
    });
    test(
      'later days skip the welcome film and only fetch clips that exist',
      () {
        final paths = sessionMediaPaths(
          day1,
          const JourneyOptions(known: {}, demos: true, welcome: false),
          Content.i.voice,
        );
        expect(paths, isNot(contains('video/yf-tutor-welcome.mp4')));
        for (final p in paths.where((x) => x.startsWith('voice/'))) {
          expect(
            Content.i.voice.contains(p.substring(6, p.length - 4)),
            isTrue,
          );
        }
      },
    );
    test(
      'download progress is a whole percent and empty downloads are complete',
      () {
        expect(downloadPercent(0, 0), 100);
        expect(downloadPercent(1, 3), 33);
        expect(downloadPercent(5, 3), 100);
      },
    );
    test('every line a guided lesson speaks has a natural-voice clip', () {
      final blocked = (jsonDecode(
        File('test/voice-blocked.json').readAsStringSync(),
      ) as Map).keys.toSet();
      final missing = <String>{};
      final ids = [
        for (final p in Content.i.plans)
          for (final d in p.days) planSessionId(p.id, d.day),
        for (final q in Content.i.quickSessions) 'quick:${q.id}',
      ];
      for (final id in ids) {
        final s = resolveSession(id)!;
        final plan = s.planId == null ? null : Content.i.plan(s.planId!);
        final welcome =
            plan != null &&
            s.day != null &&
            shouldWelcome(plan, s.day!, const []);
        for (final line in sessionLines(
          s,
          JourneyOptions(known: const {}, demos: true, welcome: welcome),
        )) {
          final k = voiceKey(line);
          if (!Content.i.voice.contains(k) && !blocked.contains(k)) {
            missing.add(line);
          }
        }
      }
      expect(missing, isEmpty);
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
      // lesson voice streams from the media server; the onboarding and breath cues ship inside
      final bundledVoice =
          ((jsonDecode(File('test/bundled-media.json').readAsStringSync())
                      as Map)['voice']
                  as List)
              .cast<String>();
      for (final k in bundledVoice) {
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
      expect(paywallVariant('onboarding', 'standard', null), 'standard');
    });
    test('in the app the last offer is repeated; without one it is the normal price', () {
      expect(paywallVariant('plan', 'standard', 'exit'), 'exit');
      expect(paywallVariant('home', 'standard', 'gift'), 'gift');
      expect(paywallVariant('home', 'standard', 'regular'), 'regular');
      expect(paywallVariant('home', 'standard', null), 'standard');
    });
    test(
      'exit survey is asked only once, on the normal-price or trial paywall',
      () {
        expect(shouldAskExitSurvey('standard', false), isTrue);
        expect(shouldAskExitSurvey('standard', true), isFalse);
        expect(shouldAskExitSurvey('regular', false), isTrue);
        expect(shouldAskExitSurvey('regular', true), isFalse);
        expect(shouldAskExitSurvey('exit', false), isFalse);
        expect(shouldAskExitSurvey('gift', false), isFalse);
      },
    );
    test('survey answers only reveal an offer: price → lower exit price, doubts → trial plan', () {
      expect(paywallSurveyOffer('price'), 'exit');
      expect(paywallSurveyOffer('later'), 'regular');
      expect(paywallSurveyOffer('unsure'), 'regular');
      expect(paywallSurveyOffer(null), isNull);
    });
    test('people the store gives no trial get the lower price instead of the trial', () {
      expect(paywallSurveyOffer('later', trialAvailable: false), 'exit');
      expect(paywallSurveyOffer('unsure', trialAvailable: false), 'exit');
      expect(paywallSurveyOffer('price', trialAvailable: false), 'exit');
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
      expect(freeStarterDay(2, []), 1);
      expect(freeStarterDay(2, [1]), 2);
      expect(freeStarterDay(2, [2]), 1);
      expect(freeStarterDay(2, [1, 2]), null);
      final s = Content.i.plan(freeStarterId)!;
      expect([s.premium, s.freeDays, s.days.length], [true, 2, 30]);
    });
    test('leads with free only when the personal plan is locked', () {
      expect(homeLeadsWithFree(true), true);
      expect(homeLeadsWithFree(false), false);
    });
    test("keeps a started course as Today's headline even when its next day is locked", () {
      expect(homeLeadsWithFree(true, true), false);
    });
    test('says Watch first / Your turn only for the first two demos of Day 1', () {
      expect(speaksDemoCue(1, 0), true);
      expect(speaksDemoCue(1, 1), true);
      expect(speaksDemoCue(1, 2), false);
      expect(speaksDemoCue(2, 0), false);
      expect(speaksDemoCue(null, 0), false);
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

  // Mirrors src/lib/i18n.test.ts.
  group('languages', () {
    test('fills placeholders and keeps unknown ones visible', () {
      expect(
        formatMessage('Hi {name}, {n} min', {'name': 'Mohit', 'n': 12}),
        'Hi Mohit, 12 min',
      );
      expect(formatMessage('Hi {name}', {}), 'Hi {name}');
    });
    test("picks plural forms by each language's rules", () {
      const days = '{n, plural, one {# day} other {# days}}';
      expect(formatMessage(days, {'n': 1}, 'en'), '1 day');
      expect(formatMessage(days, {'n': 2}, 'en'), '2 days');
      expect(formatMessage(days, {'n': 0}, 'en'), '0 days');
      expect(
        formatMessage('{n, plural, one {# jour} other {# jours}}', {
          'n': 0,
        }, 'fr'),
        '0 jour',
      );
      expect(
        formatMessage('{n, plural, one {# dia} other {# dias}}', {
          'n': 1,
        }, 'pt'),
        '1 dia',
      );
      expect(formatMessage('{n, plural, other {#日}}', {'n': 1}, 'ja'), '1日');
      expect(
        formatMessage('{n, plural, =0 {none} one {# Tag} other {# Tage}}', {
          'n': 0,
        }, 'de'),
        'none',
      );
      expect(pluralCategory('de', 1), 'one');
      expect(pluralCategory('it', 1.5), 'other');
      expect(pluralCategory('ja', 1), 'other');
    });
    test('uses Hindi plural rules (0 and 1 are singular)', () {
      expect(pluralCategory('hi', 0), 'one');
      expect(pluralCategory('hi', 1), 'one');
      expect(pluralCategory('hi', 2), 'other');
      expect(
        formatMessage('{n, plural, one {# दिन} other {# दिन}}', {'n': 3}, 'hi'),
        '3 दिन',
      );
    });
    test('agrees day counts in number on the real screens (1 day, 2 days)', () {
      Map<String, dynamic> bundle(String lang) => jsonDecode(
        File('assets/data/i18n/content.$lang.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      Content.loadFromJson(bundle('fr'), 'fr');
      expect(tr('common.days', {'n': 1}), '1 jour');
      expect(tr('common.days', {'n': 2}), '2 jours');
      Content.loadFromJson(bundle('de'), 'de');
      expect(tr('home.streakDayStreak', {'n': 1}), '1 Tag in Folge');
      expect(tr('home.streakDayStreak', {'n': 3}), '3 Tage in Folge');
      Content.loadFromJson(bundle('hi'), 'hi');
      expect(tr('common.days', {'n': 2}), '2 दिन');
      Content.loadFromJson(json);
      expect(tr('home.streakDayStreak', {'n': 1}), '1-day streak');
      expect(tr('common.days', {'n': 2}), '2 days');
    });
    test('finds the arguments a message uses, inside plural and select branches too', () {
      expect(
        messageArgs(
          '{price}/{period, select, month {month} other {year}} for {name}',
        ),
        ['name', 'period', 'price'],
      );
      expect(
        messageArgs('{n, plural, one {# day with {who}} other {# days}}'),
        ['n', 'who'],
      );
    });
    test('handles selects with nested placeholders', () {
      const m = '{hasName, select, yes {{name}, your plan} other {Your plan}}';
      expect(
        formatMessage(m, {'hasName': 'yes', 'name': 'Mo'}),
        'Mo, your plan',
      );
      expect(formatMessage(m, {'hasName': 'no'}), 'Your plan');
    });
    test('looks keys up in the active language and splits lists and link templates', () {
      setI18n('de', {
        'a.b': 'Hallo {name}',
        'a.list': 'S, M, D',
        'a.legal': 'Mit {terms} und {privacy}.',
      });
      expect(tr('a.b', {'name': 'Ana'}), 'Hallo Ana');
      expect(tr('missing.key'), 'missing.key');
      expect(trList('a.list'), ['S', 'M', 'D']);
      expect(trParts('a.legal').map((p) => p.name ?? p.text).toList(), [
        'Mit ',
        'terms',
        ' und ',
        'privacy',
        '.',
      ]);
      Content.loadFromJson(json);
    });
    test('ships English plus every translated language, each loading in its own language', () {
      expect(supportedLanguages, [
        'en',
        'hi',
        'es',
        'pt',
        'de',
        'fr',
        'it',
        'ja',
      ]);
      for (final lang in supportedLanguages.skip(1)) {
        final file = File('assets/data/i18n/content.$lang.json');
        Content.loadFromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
          lang,
        );
        expect(appLang, lang);
        expect(Content.i.plans.map((p) => p.id), [
          for (final p in json['plans'] as List) p['id'],
        ]);
        final web = File('../src/data/i18n/content.$lang.json');
        // the web prototype is only next to the app in the full project, not in the store repository
        if (web.existsSync()) {
          expect(file.readAsStringSync(), web.readAsStringSync());
        }
      }
      Content.loadFromJson(json);
      expect(appLang, 'en');
    });
    test('uses the saved choice, else the first device language we ship, else English', () {
      expect(resolveLanguage('ja', ['de-DE']), 'ja');
      expect(resolveLanguage(null, ['ko-KR', 'de-AT', 'en-US']), 'de');
      expect(resolveLanguage(null, ['hi-IN', 'en-US']), 'hi');
      expect(resolveLanguage(null, ['pt-PT']), 'pt');
      expect(resolveLanguage(null, ['es_419']), 'es');
      expect(resolveLanguage('xx', ['fr-CA']), 'fr');
      expect(resolveLanguage(null, ['ko-KR', 'zh-CN']), 'en');
      expect(resolveLanguage(null, []), 'en');
    });
    test('falls back to a device voice in the app language, English only in US or UK accents', () {
      expect(fallbackVoiceRank('en', 'en-US'), 0);
      expect(fallbackVoiceRank('en', 'en_GB'), 1);
      expect(fallbackVoiceRank('en', 'en-IN'), isNull);
      expect(fallbackVoiceRank('es', 'es-MX'), 0);
      expect(fallbackVoiceRank('es', 'es-ES'), 3);
      expect(fallbackVoiceRank('pt', 'pt-BR'), 0);
      expect(fallbackVoiceRank('pt', 'pt-PT'), 1);
      expect(fallbackVoiceRank('ja', 'ja-JP'), 0);
      expect(fallbackVoiceRank('ja', 'en-US'), isNull);
      expect(fallbackVoiceRank('de', 'de'), 1);
      expect(fallbackVoiceRank('hi', 'hi-IN'), 0);
      expect(fallbackVoiceRank('hi', 'en-IN'), isNull);
    });
  });

  group('guided journey', () {
    SessionItem it3(String e, int s, [String? f, int? r]) =>
        SessionItem(e, s, null, f, r, f == null ? null : 'cue');

    test('rests between poses, switches sides in 5 s and runs a flow without pauses', () {
      final items = [
        it3('cat-cow', 40),
        it3('warrior-1-right', 30),
        it3('warrior-1-left', 30),
        it3('upward-salute', 5, 'half-sun', 1),
        it3('forward-fold', 5, 'half-sun', 1),
        it3('savasana', 60),
      ];
      expect(
        [for (var i = 0; i < 6; i++) gapBefore(items, i)],
        [0, 10, 5, 10, 0, 10],
      );
      expect(totalSeconds(items), 170 + 35);
    });

    test('demonstrates each new pose once, never the second side, savasana or a familiar pose', () {
      final items = [
        it3('cat-cow', 40),
        it3('warrior-1-right', 30),
        it3('warrior-1-left', 30),
        it3('cat-cow', 30),
        it3('savasana', 60),
      ];
      expect(
        [for (var i = 0; i < items.length; i++) demoAt(items, i, {})],
        [DemoKind.pose, DemoKind.pose, null, null, null],
      );
      expect(demoAt(items, 1, {'warrior-1'}), isNull);
      expect(demoAt(items, 1, {'warrior-1'}, true), DemoKind.pose);
    });

    test('demonstrates a flow once at its first movement', () {
      final items = [
        it3('upward-salute', 5, 'sun-a', 1),
        it3('forward-fold', 5, 'sun-a', 1),
        it3('upward-salute', 5, 'sun-a', 2),
        it3('child-pose', 30),
        it3('upward-salute', 5, 'sun-a', 1),
      ];
      expect(
        [for (var i = 0; i < items.length; i++) demoAt(items, i, {})],
        [DemoKind.flow, null, null, DemoKind.pose, null],
      );
      expect(demoAt(items, 0, {'flow:sun-a'}), isNull);
      expect(
        [for (var i = 0; i < 3; i++) isRoundStart(items, i)],
        [true, false, true],
      );
      expect(flowRounds(items, 1), 2);
    });

    // a flow used to be one screen per breath (Day 2 showed 22 steps); now all of its rounds are one
    test('shows a whole flow as one step, with its own clock and movement count', () {
      final items = [
        it3('cat-cow', 40),
        it3('upward-salute', 5, 'half-sun', 1),
        it3('soft-fold', 5, 'half-sun', 1),
        it3('halfway-lift', 5, 'half-sun', 1),
        it3('upward-salute', 5, 'half-sun', 2),
        it3('soft-fold', 5, 'half-sun', 2),
        it3('halfway-lift', 5, 'half-sun', 2),
        it3('child-pose', 30),
      ];
      expect(screenCount(items), 3);
      expect(
        [for (var i = 0; i < items.length; i++) screenIndex(items, i)],
        [0, 1, 1, 1, 1, 1, 1, 2],
      );
      expect([screenStart(items, 4), screenEnd(items, 4)], [1, 7]);
      expect([screenStart(items, 7), screenEnd(items, 7)], [7, 8]);
      expect(screenSeconds(items, 3), 30);
      expect(screenRemaining(items, 2, 3), 3 + 5 * 4);
      expect(screenRemaining(items, 0, 12), 12);
      expect(roundStart(items, 5), 4);
      expect(moveOfRound(items, 5), (n: 2, total: 3));
      expect(moveOfRound(items, 0), (n: 1, total: 1));
    });

    test('plays every taught flow round as one continuous film at its pace', () {
      final sessions = [
        for (final p in Content.i.plans) ...p.days.map((d) => d.items),
        for (final q in Content.i.quickSessions) q.items,
      ];
      // the phone downloads round films from the media server (test/remote-media.json)
      final uploaded = jsonDecode(
        File('test/remote-media.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      var checked = 0;
      for (final items in sessions) {
        for (var i = 0; i < items.length; i++) {
          if (items[i].f == null) continue;
          final part = roundPartAt(items, i);
          expect(part, isNotNull, reason: '${items[i].f} pace ${items[i].k}');
          expect(
            uploaded.containsKey(filmPath(part!.film)),
            isTrue,
            reason: part.film,
          );
          expect(part.start, greaterThanOrEqualTo(roundStart(items, i)));
          expect(part.start, lessThanOrEqualTo(i));
          checked++;
        }
      }
      expect(checked, greaterThan(100));
      for (final f in Content.i.flows) {
        for (final r in [f.round, f.roundSlow].whereType<RoundFilmDef>()) {
          expect(r.from.first, 0, reason: f.id);
          expect(r.from.length, r.films.length, reason: f.id);
          expect([...r.from]..sort(), r.from, reason: f.id);
          expect(r.from.reduce(math.max), lessThan(f.moves.length));
        }
        expect(f.poster, isNotNull, reason: f.id);
      }
    });

    test('switches round film parts exactly at the movement they were cut at', () {
      final flow = Content.i.flow('sun-a')!;
      final sunA = flow.round!;
      expect(sunA.films.length, 2);
      final cut = sunA.from[1];
      final n = flow.moves.length;
      final items = [
        it3('child-pose', 30),
        for (final e in flow.moves) it3(e, 5, 'sun-a', 1),
        for (final e in flow.moves) it3(e, 5, 'sun-a', 2),
      ];
      expect(roundPartAt(items, 0), isNull);
      expect(roundPartAt(items, 1)!.film, sunA.films[0]);
      expect(roundPartAt(items, 1)!.start, 1);
      expect(roundPartAt(items, cut)!.part, 0);
      expect(roundPartAt(items, 1 + cut)!.part, 1);
      expect(roundPartAt(items, 1 + cut)!.film, sunA.films[1]);
      expect(roundPartAt(items, 1 + cut)!.start, 1 + cut);
      expect(roundPartAt(items, 1 + n)!.part, 0);
      expect(roundPartAt(items, 1 + n)!.start, 1 + n);
      final slow = [
        for (final it in items)
          it.f == null ? it : SessionItem(it.e, it.s, it.p, it.f, it.r, it.c, 2),
      ];
      expect(roundPartAt(slow, 1)!.film, flow.roundSlow!.films[0]);
    });

    test('counts poses and flows from finished workouts as practised', () {
      HistoryEntry h(String kind) => HistoryEntry(
        id: kind,
        sessionId: 'plan:yoga-journey-30:1',
        title: 'Day 1',
        kind: kind,
        image: 'x',
        completedAt: DateTime(2026, 1, 1),
        durationSec: 600,
        kcal: 20,
      );
      final known = practisedSet([h('workout')]);
      for (final it in Content.i.plan('yoga-journey-30')!.days.first.items) {
        expect(
          known.contains(it.f != null ? 'flow:${it.f}' : basePoseId(it.e)),
          isTrue,
        );
      }
      expect(practisedSet([h('meditation')]), isEmpty);
    });

    test(
      'welcomes people to a course before Day 1 until a day is finished',
      () {
        final course = Content.i.plan('yoga-journey-30')!;
        expect(shouldWelcome(course, 1, []), isTrue);
        expect(shouldWelcome(course, 1, [1]), isFalse);
        expect(shouldWelcome(course, 2, []), isFalse);
        expect(
          shouldWelcome(Content.i.plan('sun-salutation-a')!, 1, []),
          isFalse,
        );
      },
    );

    test("celebrates a course day with tomorrow's lesson, the last day as the whole course", () {
      final c = completionOf('yoga-journey-30', 3, [1, 2]);
      expect(c.kind, CompletionKind.day);
      expect(c.next!.day, 4);
      expect(
        completionOf('yoga-journey-30', 30, [for (var i = 1; i < 30; i++) i]).kind,
        CompletionKind.course,
      );
      expect(completionOf('yoga-journey-30', 5, [1, 2, 3, 4, 7]).next!.day, 6);
      expect(
        completionOf('sun-salutation-a', 1, []).kind,
        CompletionKind.single,
      );
      expect(completionOf(null, null, []).kind, CompletionKind.single);
    });

    test("every course has a welcome, a finale and a 'Tomorrow' preview for every day after Day 1", () {
      for (final p in Content.i.plans.where((x) => x.days.length > 1)) {
        expect(p.welcome, isNotEmpty, reason: p.id);
        expect(p.finale, isNotNull, reason: p.id);
        for (final d in p.days) {
          expect(d.intro, isNotEmpty, reason: '${p.id} ${d.day}');
          if (d.day > 1) {
            expect(
              d.tease ?? '',
              startsWith('Tomorrow'),
              reason: '${p.id} ${d.day}',
            );
          }
        }
      }
    });

    test('every flow has a sequence film and a spoken demo', () {
      expect(Content.i.flows.length, greaterThanOrEqualTo(5));
      for (final f in Content.i.flows) {
        expect(f.demo, isNotNull, reason: f.id);
        expect(f.watch, isNotEmpty, reason: f.id);
        expect(f.go, startsWith('Your turn'), reason: f.id);
      }
    });

    test('paces voice-led moments by spoken length when the voice is off', () {
      expect(speechSeconds(['Breathe in']), 1.9);
      expect(
        speechSeconds(['', 'One two three four five six seven eight nine ten']),
        4.4,
      );
    });
  });

  group('breath meditations follow the narrator', () {
    test('waits for the settle and instruction lines before counting', () {
      expect(breathStartSec([2, 13, 35, 68]), 35);
      expect(breathAt([4, 4, 4, 4], 33 - 35), isNull);
    });
    test('derives the phase from the clock', () {
      final a = breathAt([4, 7, 8, 0], 0)!;
      expect([a.phase, a.left, a.duration, a.cycle, a.starts], [0, 4, 4, 0, true]);
      final b = breathAt([4, 7, 8, 0], 5)!;
      expect([b.phase, b.left, b.duration, b.cycle, b.starts], [1, 6, 7, 0, false]);
      final c = breathAt([4, 0, 6, 0], 10)!;
      expect([c.phase, c.left, c.duration, c.cycle, c.starts], [0, 4, 4, 1, true]);
    });
    test('speaks cues only on phase starts of the first two rounds', () {
      expect(breathCueDue([4, 0, 6, 0], 4), isTrue);
      expect(breathCueDue([4, 0, 6, 0], 5), isFalse);
      expect(breathCueDue([4, 0, 6, 0], 20), isFalse);
    });
  });
}
