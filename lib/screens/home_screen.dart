import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../data/models.dart';
import '../logic/logic.dart';
import '../services/purchase_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/cards.dart';
import '../widgets/feedback_sheet.dart';
import '../widgets/scaffold.dart';
import '../widgets/tab_shell.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final now = DateTime.now();
    final today = dateKey(now);
    final plan = app.activePlan;
    final completed = app.activeCompleted;
    final stats = app.stats;
    final dayNumber = nextPlanDay(plan.days.length, completed);
    final day = plan.days[dayNumber - 1];
    final planDone = completed.length >= plan.days.length;
    final todayDone =
        completed.contains(dayNumber) ||
        app.history.any(
          (h) =>
              h.planId == plan.id &&
              h.day == dayNumber &&
              dateKey(h.completedAt) == today,
        );
    final todayEntries = app.history
        .where((h) => dateKey(h.completedAt) == today)
        .toList();
    final minutesToday =
        (todayEntries.fold<int>(0, (s, h) => s + h.durationSec) / 60).round();
    final minuteGoal = app.profile.dailyMinutes == 0
        ? 10
        : app.profile.dailyMinutes;
    final c = Content.i;
    final challenge = dailyPick(c.dailyChallenges, now);
    final challengeKey = '$today:${challenge.id}';
    final challengeState = app.challenges[challengeKey];
    final quote = dailyPick(c.quotes, now, 3);
    final tip = dailyPick(c.tips, now, 7);
    final evening = now.hour >= 17 || now.hour < 5;
    final med = c.meditation(
      evening ? 'evening-wind-down' : 'morning-clarity',
    )!;
    final days = app.history.map((h) => dateKey(h.completedAt)).toSet();
    final weekStart = addDays(now, -(now.weekday % 7));
    final pct = completed.length / plan.days.length;
    final name = app.profile.name;
    final premium = app.premium.active;
    final heroLocked = !planDone && isDayLocked(plan, dayNumber, premium);
    // the 60-day daily practice (seated or standing); offer the other one if it's already the main plan
    var dailyId = dailyPlanId(
      limitations: app.profile.limitations,
      style: app.profile.style,
    );
    if (dailyId == plan.id) {
      dailyId = c.dailyPlanIds.firstWhere(
        (id) => id != plan.id,
        orElse: () => dailyId,
      );
    }
    final daily = c.plan(dailyId)!;
    final dailyDone =
        app.planProgress[daily.id]?.completedDays ?? const <int>[];
    final dailyDay = nextPlanDay(daily.days.length, dailyDone);
    final dailyToday = app.history.any(
      (h) => h.planId == daily.id && dateKey(h.completedAt) == today,
    );
    final dailyLocked = isDayLocked(daily, dailyDay, premium);

    final leadFree = homeLeadsWithFree(heroLocked);
    final freeQ = c.quickSessions.firstWhere(
      (q) => q.id == freePickQuickId(now.hour),
      orElse: () => c.quickSessions.first,
    );
    final starter = c.plan(freeStarterId);
    final starterDay = starter == null
        ? null
        : freeStarterDay(
            starter.days.length,
            app.planProgress[starter.id]?.completedDays ?? const <int>[],
          );
    final Widget planHero = Reveal(
      delay: 0.05,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 430,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            boxShadow: S.float,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              KenBurns(child: EImage(img(plan.image))),
              DecoratedBox(decoration: BoxDecoration(gradient: G.scrim)),
              Positioned(
                left: 16,
                right: 16,
                top: 16,
                child: Row(
                  children: [
                    Glass(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        planDone
                            ? tr('home.planComplete')
                            : tr('home.dayOfTotal', {
                                'day': dayNumber,
                                'total': plan.days.length,
                              }),
                        style: T.tiny.c(C.ivory),
                      ),
                    ),
                    const Spacer(),
                    Ring(
                      value: pct,
                      size: 46,
                      stroke: 4.5,
                      track: C.ivory.withValues(alpha: 0.25),
                      bar: C.ivory,
                      child: Text(
                        '${(pct * 100).round()}%',
                        style: T.tiny
                            .copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: C.ivory,
                            )
                            .tab,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(plan.title, color: C.ivory.withValues(alpha: 0.7)),
                    const SizedBox(height: 8),
                    Text(
                      planDone
                          ? tr('home.youDidIt')
                          : tr('home.dayTitle', {
                              'day': dayNumber,
                              'title': day.title,
                            }),
                      style: T.displayLg.copyWith(
                        fontSize: 29.6,
                        color: C.ivory,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 2,
                      children: [
                        Text(
                          formatMinutes(totalSeconds(day.items)),
                          style: T.caption.copyWith(
                            fontSize: 14,
                            color: C.ivory.withValues(alpha: 0.8),
                          ),
                        ),
                        const Dot(),
                        Text(
                          tr('home.poses', {'n': day.items.length}),
                          style: T.caption.copyWith(
                            fontSize: 14,
                            color: C.ivory.withValues(alpha: 0.8),
                          ),
                        ),
                        const Dot(),
                        Text(
                          trTag(plan.level),
                          style: T.caption.copyWith(
                            fontSize: 14,
                            color: C.ivory.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Pressable(
                            onTap: () => planDone
                                ? context.go('/courses')
                                : heroLocked
                                ? context.push('/paywall?from=plan')
                                : context.push(
                                    '/session/${planSessionId(plan.id, dayNumber)}',
                                  ),
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: heroLocked ? null : C.ivory,
                                gradient: heroLocked ? G.gold : null,
                                borderRadius: BorderRadius.circular(56),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    heroLocked
                                        ? LucideIcons.crown
                                        : planDone
                                        ? LucideIcons.arrowRight
                                        : (todayDone
                                              ? LucideIcons.check
                                              : Icons.play_arrow_rounded),
                                    size: planDone || todayDone || heroLocked
                                        ? 20
                                        : 24,
                                    color: C.ink,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      heroLocked
                                          ? tr('home.unlockDay', {
                                              'day': dayNumber,
                                            })
                                          : planDone
                                          ? tr('home.chooseNextPlan')
                                          : (todayDone
                                                ? tr(
                                                    'home.doneTapPracticeAgain',
                                                  )
                                                : tr(
                                                    'home.startTodaysSession',
                                                  )),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: T.label.copyWith(fontSize: 17),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        CircleBtn(
                          icon: LucideIcons.arrowRight,
                          tone: Tone.dark,
                          size: 56,
                          label: tr('home.viewPlan'),
                          onTap: () => context.push('/plan/${plan.id}'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final weekSessions = app.history
        .where(
          (h) => !h.completedAt.isBefore(
            DateTime(weekStart.year, weekStart.month, weekStart.day),
          ),
        )
        .length;
    final Widget rings = Reveal(
      delay: 0.12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _PracticeRhythm(
          minutesToday: minutesToday,
          minuteGoal: minuteGoal,
          streak: stats.streak,
          best: stats.best,
          weekSessions: weekSessions,
          totalMinutes: stats.minutes,
          weekStart: weekStart,
          practisedDays: days,
          now: now,
        ),
      ),
    );
    final Widget dailyCard = Reveal(
      delay: 0.15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _DailyPracticeCard(
          plan: daily,
          day: dailyDay,
          doneDays: dailyDone.length,
          doneToday: dailyToday,
          locked: dailyLocked,
          weightKg: app.profile.weightKg,
          onTap: () => context.push(
            dailyLocked
                ? '/paywall?from=plan'
                : '/session/${planSessionId(daily.id, dailyDay)}',
          ),
          onOpen: () => context.push('/plan/${daily.id}'),
        ),
      ),
    );
    final Widget habit = Reveal(
      delay: 0.18,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: challengeState == 'done' ? G.jade : null,
            color: challengeState == 'done' ? null : C.ivory,
            borderRadius: BorderRadius.circular(30),
            boxShadow: S.card,
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: challengeState == 'done'
                          ? C.ivory.withValues(alpha: 0.15)
                          : C.terracottaSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: challengeState == 'done'
                        ? const Icon(
                            LucideIcons.check,
                            size: 28,
                            color: C.ivory,
                          )
                        : ContentIcon(
                            challenge.icon,
                            size: 28,
                            color: C.terracotta,
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(
                          tr('home.mindfulHabit'),
                          color: challengeState == 'done'
                              ? C.ivory.withValues(alpha: 0.7)
                              : C.terracotta,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          challenge.title,
                          style: T.title.c(
                            challengeState == 'done' ? C.ivory : C.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          challengeState == 'done'
                              ? tr('home.habitDone')
                              : challenge.description,
                          style: T.caption.copyWith(
                            fontSize: 14,
                            height: 1.5,
                            color: challengeState == 'done'
                                ? C.ivory.withValues(alpha: 0.8)
                                : C.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (challengeState != 'done') ...[
                const SizedBox(height: 16),
                Pressable(
                  onTap: () => app.setChallenge(
                    challengeKey,
                    challengeState == 'accepted' ? 'done' : 'accepted',
                  ),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: challengeState == 'accepted' ? C.jade : C.ink,
                      borderRadius: BorderRadius.circular(48),
                    ),
                    child: Text(
                      challengeState == 'accepted'
                          ? tr('home.markAsDone')
                          : tr('home.acceptChallenge'),
                      style: T.label.c(C.ivory),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    final Widget quick = Reveal(
      delay: 0.22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            leadFree
                ? tr('home.moreFreeSessions')
                : tr('singleClasses.quickSessions'),
            action: tr('common.seeAll'),
            onAction: () => context.go('/courses?view=classes'),
          ),
          HScroll(children: [for (final q in c.quickSessions) QuickCard(q)]),
        ],
      ),
    );
    // The one Plus offer this person was shown on the paywall — never a different deal.
    final List<Widget> offerCard = [
      const SizedBox(height: 16),
      Reveal(
        delay: 0.13,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _PlusOfferCard(
            variant: paywallVariant('home', 'standard', app.paywallOffer),
            onTap: () => context.push('/paywall?from=home'),
          ),
        ),
      ),
    ];

    final intention = dailyPick(c.affirmations, now, 5);
    final pose = dailyPick(
      c.exercises.where((e) => isPoseOfDayCandidate(e.id, e.category)).toList(),
      now,
      11,
    );
    final ancient = c.plans
        .where((p) => p.group == _ancientGroup && !p.isSingleSession)
        .toList();
    final breaths = breatheNowIds
        .map(c.meditation)
        .whereType<Meditation>()
        .toList();

    final Widget breatheNow = Reveal(
      delay: 0.14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            tr('home.breatheNow'),
            action: tr('home.allBreathwork'),
            onAction: () => context.go('/meditate'),
          ),
          HScroll(
            gap: 12,
            children: [
              _BreathTile(
                title: tr('meditate.breathingCoach'),
                meta: tr('home.breathingCoachMeta'),
                coach: true,
                onTap: () => context.push('/breathe'),
              ),
              for (final m in breaths)
                _BreathTile(
                  title: m.title.split(':').first,
                  meta: tr('common.minShort', {'n': m.minutes}),
                  image: m.image,
                  locked: isMeditationLocked(m.id, premium),
                  onTap: () => context.push(
                    isMeditationLocked(m.id, premium)
                        ? '/paywall?from=meditation'
                        : '/meditation/${m.id}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    final Widget poseOfDay = Reveal(
      delay: 0.16,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _PoseOfDay(pose),
      ),
    );
    final Widget ancientShelf = ancient.isEmpty
        ? const SizedBox.shrink()
        : Reveal(
            delay: 0.2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.flower2, size: 13, color: C.gold),
                      const SizedBox(width: 6),
                      Eyebrow(tr('home.classicalYoga'), color: C.gold),
                    ],
                  ),
                ),
                SectionHeader(
                  trTag('Ancient paths'),
                  action: tr('common.seeAll'),
                  onAction: () => context.go('/courses'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                  child: Text(
                    tr('home.ancientPathsDesc'),
                    style: T.caption.copyWith(height: 1.45),
                  ),
                ),
                HScroll(
                  children: [
                    for (final p in ancient)
                      PlanCard(
                        p,
                        progress:
                            (app.planProgress[p.id]?.completedDays.length ??
                                0) /
                            p.days.length,
                      ),
                  ],
                ),
              ],
            ),
          );

    return EnsoScaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          top: topInset(context) + 18,
          bottom: tabBarSpace(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(
                          DateFormat('EEEE, MMM d', appLocale).format(now),
                        ),
                        const SizedBox(height: 6),
                        // long greetings (Japanese, German) and names shrink to stay on one line
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            tr('home.greetingLine', {
                              'greeting': greeting(now.hour),
                              'hasName': name.isNotEmpty ? 'yes' : 'no',
                            }),
                            maxLines: 1,
                            softWrap: false,
                            style: T.displayMd,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            name.isNotEmpty ? name : tr('home.friendFallback'),
                            maxLines: 1,
                            softWrap: false,
                            style: T.serifAccent.copyWith(
                              fontSize: 30,
                              color: C.jadeDeep,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Pressable(
                          onTap: () => context.push('/history'),
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: C.ivory,
                              borderRadius: BorderRadius.circular(44),
                              boxShadow: S.soft,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  stats.streak > 0
                                      ? Icons.local_fire_department_rounded
                                      : LucideIcons.flame,
                                  size: 19,
                                  color: stats.streak > 0
                                      ? C.terracotta
                                      : C.muted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${stats.streak}',
                                  style: T.label
                                      .copyWith(fontWeight: FontWeight.w700)
                                      .tab,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Pressable(
                          onTap: () => context.go('/profile'),
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: G.jade,
                              shape: BoxShape.circle,
                              boxShadow: S.glow,
                            ),
                            child: Text(
                              (name.isNotEmpty ? name : 'E')[0].toUpperCase(),
                              style: T.label.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: C.ivory,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Reveal(
              delay: 0.02,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _Intention(intention),
              ),
            ),
            const SizedBox(height: 18),

            if (!leadFree) ...[
              planHero,
              const SizedBox(height: 16),
              rings,
              if (!premium) ...offerCard,
              const SizedBox(height: 32),
              breatheNow,
              const SizedBox(height: 28),
              dailyCard,
              const SizedBox(height: 16),
              poseOfDay,
              const SizedBox(height: 36),
              quick,
              const SizedBox(height: 36),
              ancientShelf,
              const SizedBox(height: 28),
              habit,
              const SizedBox(height: 28),
              const FeedbackInvite(),
            ] else ...[
              Reveal(
                delay: 0.05,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: starter != null && starterDay != null
                      ? _FreeHero(
                          title: tr('home.dayTitle', {
                            'day': starterDay,
                            'title': starter.days[starterDay - 1].title,
                          }),
                          image: starter.image,
                          eyebrow: tr('home.planDayOfTotal', {
                            'title': starter.title,
                            'day': starterDay,
                            'total': starter.days.length,
                          }),
                          meta: tr('home.freeHeroMeta', {
                            'minutes': formatMinutes(
                              totalSeconds(starter.days[starterDay - 1].items),
                            ),
                            'n': starter.days[starterDay - 1].items.length,
                            'level': trTag(starter.level),
                          }),
                          cta: starterDay == 1
                              ? tr('home.startYourFreeCourse')
                              : tr('plan.continueDay', {'day': starterDay}),
                          progress: (starterDay - 1) / starter.days.length,
                          onTap: () => context.push(
                            '/session/${planSessionId(starter.id, starterDay)}',
                          ),
                        )
                      : _FreeHero(
                          title: freeQ.title,
                          image: freeQ.image,
                          eyebrow: tr('home.todaysFreeSession'),
                          meta: tr('home.freeSessionMeta', {
                            'minutes': formatMinutes(totalSeconds(freeQ.items)),
                            'n': freeQ.items.length,
                          }),
                          cta: tr('home.startFreeSession'),
                          onTap: () =>
                              context.push('/session/quick:${freeQ.id}'),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              rings,
              if (!premium) ...offerCard,
              const SizedBox(height: 32),
              breatheNow,
              const SizedBox(height: 28),
              poseOfDay,
              const SizedBox(height: 36),
              quick,
              const SizedBox(height: 36),
              const _MadeForYouHeader(),
              planHero,
              const SizedBox(height: 16),
              dailyCard,
              const SizedBox(height: 36),
              ancientShelf,
              const SizedBox(height: 28),
              habit,
              const SizedBox(height: 28),
              const FeedbackInvite(),
            ],
            const SizedBox(height: 36),

            // meditation pick
            Reveal(
              delay: 0.28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    evening
                        ? tr('home.windDownTonight')
                        : tr('home.startWithStillness'),
                    action: tr('tabs.meditate'),
                    onAction: () => context.go('/meditate'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Pressable(
                      onTap: () => context.push('/meditation/${med.id}'),
                      child: Container(
                        height: 190,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: S.card,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            EImage(img(med.image)),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF111A15)
                                        .withValues(alpha: 0.85),
                                    const Color(0xFF111A15)
                                        .withValues(alpha: 0.1),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 20,
                              top: 0,
                              bottom: 0,
                              width: 220,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        LucideIcons.sparkles,
                                        size: 12,
                                        color: C.ivory.withValues(alpha: 0.7),
                                      ),
                                      const SizedBox(width: 4),
                                      Eyebrow(
                                        tr('guide.tagMinutes', {
                                          'tag': trTag(med.category),
                                          'n': med.minutes,
                                        }),
                                        color: C.ivory.withValues(alpha: 0.7),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    med.title,
                                    style: T.displayMd.c(C.ivory),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    med.subtitle,
                                    style: T.caption.c(
                                      C.ivory.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              right: 20,
                              bottom: 20,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: C.ivory,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 28,
                                  color: C.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // wisdom
            Reveal(
              delay: 0.3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: C.jadeSoft,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: -72,
                        bottom: -72,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: C.jade.withValues(alpha: 0.1),
                              width: 14,
                            ),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                LucideIcons.quote,
                                size: 22,
                                color: C.jade.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 10),
                              Eyebrow(
                                tr('home.wisdomForToday'),
                                color: C.jadeDeep,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            quote.text,
                            style: T.serifAccent.copyWith(
                              fontSize: 25.6,
                              height: 1.2,
                              color: C.jadeDeep,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tr('home.quoteAttribution', {
                              'author': quote.author,
                            }),
                            style: T.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: C.jadeDeep.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // daily tip
            Reveal(
              delay: 0.31,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ECard(
                  radius: 26,
                  shadow: S.soft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: G.jade,
                          shape: BoxShape.circle,
                          boxShadow: S.glow,
                        ),
                        child: ContentIcon(tip.icon, size: 20, color: C.ivory),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow(tr('home.teachersTip'), color: C.jade),
                            const SizedBox(height: 4),
                            Text(
                              tip.title,
                              style: T.label.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tip.body,
                              style: T.bodySm.copyWith(
                                fontSize: 14,
                                color: C.muted,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),

            // learn
            Reveal(
              delay: 0.34,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(tr('home.learnTheTradition')),
                  HScroll(
                    gap: 14,
                    children: [
                      for (final g in c.guides)
                        Pressable(
                          onTap: () => context.push('/guide/${g.id}'),
                          child: Container(
                            width: 180,
                            height: 230,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: C.ivory,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: S.soft,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 120,
                                  width: double.infinity,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      EImage(img(g.image)),
                                      Positioned(
                                        left: 10,
                                        top: 10,
                                        child: Glass(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          child: Text(
                                            trTag(g.tag).toUpperCase(),
                                            style: T.tiny.copyWith(
                                              fontSize: 10,
                                              letterSpacing: 1,
                                              fontWeight: FontWeight.w700,
                                              color: C.ivory,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        g.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: T.label.copyWith(
                                          fontWeight: FontWeight.w700,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            LucideIcons.bookOpen,
                                            size: 12,
                                            color: C.muted,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              tr('guide.minRead', {
                                                'n': g.minutes,
                                              }),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: T.tiny.w(FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Reveal(
                delay: 0.6,
                dy: 0,
                child: Text(
                  tr('home.footerLine'),
                  textAlign: TextAlign.center,
                  style: T.serifAccent.copyWith(fontSize: 18.4, color: C.muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shelf of classical courses on Today (the `planGroups` name in content).
const _ancientGroup = 'Ancient paths';

/// Today's intention (sankalpa): one of the shared affirmations, picked per day.
class _Intention extends StatelessWidget {
  const _Intention(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: C.goldSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: C.ivory,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.sprout, size: 17, color: C.jadeDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(
                  tr('home.todaysIntention'),
                  color: C.jadeDeep.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: T.serifAccent.copyWith(
                    fontSize: 18,
                    height: 1.25,
                    color: C.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Practice summary that replaces fitness rings: minutes toward the daily goal, this week,
/// total practice and the week strip.
class _PracticeRhythm extends StatelessWidget {
  const _PracticeRhythm({
    required this.minutesToday,
    required this.minuteGoal,
    required this.streak,
    required this.best,
    required this.weekSessions,
    required this.totalMinutes,
    required this.weekStart,
    required this.practisedDays,
    required this.now,
  });
  final int minutesToday, minuteGoal, streak, best, weekSessions, totalMinutes;
  final DateTime weekStart, now;
  final Set<String> practisedDays;

  static String _hm(int minutes) => minutes >= 60
      ? tr('home.hoursMinutesShort', {'h': minutes ~/ 60, 'm': minutes % 60})
      : tr('medPlayer.sleepMinutesShort', {'n': minutes});

  @override
  Widget build(BuildContext context) {
    final today = dateKey(now);
    final left = minuteGoal - minutesToday;
    return ECard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(tr('home.yourPracticeToday'), color: C.jade),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$minutesToday', style: T.displayMd.tab),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tr('home.ofGoalMin', {'n': minuteGoal}),
                            maxLines: 2,
                            style: T.caption.copyWith(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: C.terracottaSoft,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 16,
                      color: C.terracotta,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tr('home.streakDayStreak', {'n': streak}),
                      style: T.tiny.copyWith(
                        fontWeight: FontWeight.w700,
                        color: C.jadeDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Bar(
            value: (minutesToday / minuteGoal).clamp(0, 1).toDouble(),
            height: 8,
          ),
          const SizedBox(height: 8),
          Text(
            left <= 0
                ? tr('home.dailyGoalReached')
                : tr('home.minToDailyGoal', {'n': left}),
            style: T.tiny.w(FontWeight.w500),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _Stat('$weekSessions', tr('home.statThisWeek'))),
              Container(width: 1, height: 34, color: C.line),
              Expanded(
                child: _Stat(_hm(totalMinutes), tr('home.statPractised')),
              ),
              Container(width: 1, height: 34, color: C.line),
              Expanded(child: _Stat('$best', tr('home.statBestStreak'))),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: C.line),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Builder(
                    builder: (_) {
                      final d = addDays(weekStart, i);
                      final k = dateKey(d);
                      final done = practisedDays.contains(k);
                      final isToday = k == today;
                      final future = d.isAfter(now) && !isToday;
                      return Column(
                        children: [
                          Text(
                            weekLetters[i],
                            style: T.tiny.copyWith(
                              fontSize: 11,
                              color: isToday ? C.jade : C.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // seven days always fit: the dots shrink on the narrowest phones
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: done
                                    ? C.jade
                                    : (isToday || future
                                          ? Colors.transparent
                                          : C.sand),
                                border: isToday && !done
                                    ? Border.all(color: C.jade, width: 2)
                                    : null,
                              ),
                              child: done
                                  ? const Icon(
                                      LucideIcons.check,
                                      size: 16,
                                      color: C.ivory,
                                    )
                                  : Text(
                                      '${d.day}',
                                      style: T.caption
                                          .copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: isToday
                                                ? C.jadeDeep
                                                : (future
                                                      ? C.muted.withValues(
                                                          alpha: 0.6,
                                                        )
                                                      : C.muted),
                                          )
                                          .tab,
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: T.title.s(18).tab),
        const SizedBox(height: 2),
        Text(label, style: T.tiny),
      ],
    );
  }
}

/// Compact tile in Today's "Breathe now" row.
class _BreathTile extends StatelessWidget {
  const _BreathTile({
    required this.title,
    required this.meta,
    required this.onTap,
    this.image,
    this.locked = false,
    this.coach = false,
  });
  final String title, meta;
  final String? image;
  final bool locked, coach;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final fg = coach ? C.ivory : C.ink;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 148,
        height: 172,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: coach ? null : C.ivory,
          gradient: coach ? G.jade : null,
          borderRadius: BorderRadius.circular(26),
          boxShadow: S.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coach)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: C.ivory.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.wind, size: 26, color: C.ivory),
              )
            else
              ClipOval(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      EImage(img(image!)),
                      if (locked)
                        Container(
                          color: C.ink.withValues(alpha: 0.35),
                          child: const Icon(
                            LucideIcons.lock,
                            size: 16,
                            color: C.ivory,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: T.label.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: fg,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Flexible(
                  child: Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.tiny.c(
                      coach ? C.ivory.withValues(alpha: 0.8) : C.jade,
                    ),
                  ),
                ),
                if (locked) ...[const SizedBox(width: 6), const PremiumBadge()],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's pose: the still, its Sanskrit name and focus, opening the full pose guide.
class _PoseOfDay extends StatelessWidget {
  const _PoseOfDay(this.e);
  final Exercise e;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.push('/exercise/${e.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.ivory,
          borderRadius: BorderRadius.circular(30),
          boxShadow: S.card,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 132,
                height: 132,
                color: C.sand,
                child: EImage(img(e.image)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(tr('home.poseOfTheDay'), color: C.jade),
                  const SizedBox(height: 6),
                  Text(
                    e.baseName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: T.title.copyWith(height: 1.15),
                  ),
                  if (e.sanskrit != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      e.sanskrit!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.serifAccent.copyWith(
                        fontSize: 17,
                        color: C.jadeDeep,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    e.focus.take(3).map((f) => trTag(f)).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.caption,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          tr('home.learnThePose'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.label.copyWith(fontSize: 14, color: C.jade),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        LucideIcons.arrowRight,
                        size: 15,
                        color: C.jade,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyPracticeCard extends StatelessWidget {
  const _DailyPracticeCard({
    required this.plan,
    required this.day,
    required this.doneDays,
    required this.doneToday,
    required this.locked,
    required this.weightKg,
    required this.onTap,
    required this.onOpen,
  });
  final Plan plan;
  final int day, doneDays;
  final bool doneToday, locked;
  final double weightKg;
  final VoidCallback onTap, onOpen;

  @override
  Widget build(BuildContext context) {
    final d = plan.days[day - 1];
    final hasAffirmation = d.items.any(
      (it) => Content.i.exercise(it.e)?.isAffirmation ?? false,
    );
    return Pressable(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.ivory,
          borderRadius: BorderRadius.circular(30),
          boxShadow: S.card,
        ),
        child: Column(
          children: [
            Row(
              children: [
                RoundedImage(img(plan.image), size: 92, radius: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow(
                        tr('home.dailyChallengeDay', {'day': day}),
                        color: C.terracotta,
                      ),
                      const SizedBox(height: 4),
                      Text(plan.title, style: T.title),
                      const SizedBox(height: 2),
                      Text(
                        tr('home.dailyCardMeta', {
                          'minutes': formatMinutes(totalSeconds(d.items)),
                          'n': d.items.length,
                          'affirmation': hasAffirmation ? 'yes' : 'no',
                        }),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.caption,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Bar(
                              value: doneDays / plan.days.length,
                              height: 6,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$doneDays/${plan.days.length}',
                            style: T.tiny
                                .copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: C.ink,
                                )
                                .tab,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Pressable(
              onTap: onTap,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: locked ? null : (doneToday ? C.jadeSoft : C.ink),
                  gradient: locked ? G.gold : null,
                  borderRadius: BorderRadius.circular(48),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      locked
                          ? LucideIcons.crown
                          : (doneToday
                                ? LucideIcons.check
                                : Icons.play_arrow_rounded),
                      size: locked || doneToday ? 18 : 22,
                      color: locked
                          ? C.ink
                          : (doneToday ? C.jadeDeep : C.ivory),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        locked
                            ? tr('plan.unlockDayWithPlus', {'day': day})
                            : (doneToday
                                  ? tr('home.doneTodayPracticeDay', {
                                      'day': day,
                                    })
                                  : tr('home.startDayTitle', {
                                      'day': day,
                                      'title': d.title,
                                    })),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.label.c(
                          locked ? C.ink : (doneToday ? C.jadeDeep : C.ivory),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeHero extends StatelessWidget {
  const _FreeHero({
    required this.title,
    required this.image,
    required this.eyebrow,
    required this.meta,
    required this.cta,
    required this.onTap,
    this.progress,
  });
  final String title, image, eyebrow, meta, cta;
  final double? progress;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 400,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          boxShadow: S.float,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            KenBurns(child: EImage(img(image))),
            DecoratedBox(decoration: BoxDecoration(gradient: G.scrim)),
            Positioned(
              left: 16,
              top: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: C.ivory,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.sparkles,
                          size: 13,
                          color: C.jadeDeep,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          tr('home.madeForYou'),
                          style: T.tiny.c(C.jadeDeep),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Glass(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(tr('common.free'), style: T.tiny.c(C.ivory)),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(eyebrow, color: C.ivory.withValues(alpha: 0.7)),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: T.displayLg.copyWith(fontSize: 29.6, color: C.ivory),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    meta,
                    style: T.caption.copyWith(
                      fontSize: 14,
                      color: C.ivory.withValues(alpha: 0.8),
                    ),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: C.ivory.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation(C.ivory),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: C.ivory,
                      borderRadius: BorderRadius.circular(56),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          size: 24,
                          color: C.ink,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            cta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.label.copyWith(fontSize: 17),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MadeForYouHeader extends StatelessWidget {
  const _MadeForYouHeader();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sparkles, size: 13, color: C.gold),
              const SizedBox(width: 6),
              Eyebrow(tr('home.yourPersonalPlan'), color: C.gold),
            ],
          ),
          const SizedBox(height: 4),
          Text(tr('home.builtFromYourAnswers'), style: T.title.s(20)),
        ],
      ),
    );
  }
}

/// The one Plus offer this person was shown on the paywall (normal price, trial, gift or the
/// lower price revealed after closing it) — never a different deal. Mirrors web `PlusOfferCard`.
class _PlusOfferCard extends StatelessWidget {
  const _PlusOfferCard({required this.variant, required this.onTap});
  final String variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final offer = PurchaseService.localized(switch (variant) {
      'exit' => exitOffer,
      'gift' => giftOffers.first,
      'regular' => regularOffers.first,
      _ => standardOffers.first,
    });
    final title = switch (variant) {
      'exit' => tr('paywall.lowerPriceReady'),
      'regular' => tr('paywall.trialReady', {'days': offer.trialDays}),
      _ => tr('home.unlockEveryCourse'),
    }.replaceAll('\n', ' ');
    final detail = switch (variant) {
      'exit' => tr('paywall.lowerPriceDetail', {'price': offer.price}),
      'regular' => tr('paywall.trialDetail', {'days': offer.trialDays}),
      _ =>
        '${offer.price} ${tr('paywall.perPeriodLower', {'period': offer.period})}',
    };
    final cta = switch (variant) {
      'exit' => tr('paywall.seeLowerPrice'),
      'regular' => tr('paywall.startTrialDays', {'days': offer.trialDays}),
      _ => tr('paywall.continueWith', {'title': 'Asanova Plus'}),
    };
    return Semantics(
      button: true,
      label: '$title. $detail',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: C.ink,
            borderRadius: BorderRadius.circular(30),
            boxShadow: S.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: C.gold.withValues(alpha: 0.22),
                        blurRadius: 60,
                        spreadRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            gradient: G.gold,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            LucideIcons.crown,
                            size: 14,
                            color: C.ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr('paywall.plusBadge'),
                            style: T.eyebrow.c(C.goldSoft),
                          ),
                        ),
                        if (offer.strike != null)
                          Text(
                            offer.strike!,
                            style: T.caption.copyWith(
                              color: C.ivory.withValues(alpha: 0.55),
                              decoration: TextDecoration.lineThrough,
                              decorationColor: C.ivory.withValues(alpha: 0.55),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: T.title.copyWith(fontSize: 20, color: C.ivory),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: T.bodySm.c(C.ivory.withValues(alpha: 0.78)),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 48,
                      width: double.infinity,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        gradient: G.gold,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        cta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.label.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: C.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
