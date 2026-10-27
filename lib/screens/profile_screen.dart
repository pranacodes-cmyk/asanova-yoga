import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../logic/logic.dart';
import '../services/app_links.dart';
import '../services/purchase_service.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/scaffold.dart';
import '../widgets/sheet.dart';
import '../widgets/tab_shell.dart';
import '../widgets/toast.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    final premium = app.premium;
    final r = app.reminders;
    final plan = app.activePlan;
    final completed = app.activeCompleted;
    final stats = app.stats;
    String? optionLabel(String step, String id) => Content.i
        .step(step)
        ?.options
        .where((o) => o.id == id)
        .firstOrNull
        ?.label;
    final gentle = p.limitations
        .where((l) => l != 'none')
        .map((l) => optionLabel('limitations', l))
        .whereType<String>()
        .toList();
    final goalLabels = {
      for (final o in Content.i.step('goals')?.options ?? const [])
        o.id: o.label,
    };
    final reminderLabel = r.enabled
        ? DateFormat(
            'h:mm a',
            appLocale,
          ).format(DateTime(2020, 1, 1, r.hour, r.minute))
        : tr('profile.reminderOff');
    final planName = switch (premium.plan) {
      'gift' => tr('profile.planYearlyGift'),
      'exit' => tr('profile.planYearlySpecial'),
      'lifetime' => tr('profile.planLifetime'),
      'monthly' => tr('purchase.planMonthly'),
      'yearly' || 'standardYearly' => tr('purchase.planYearly'),
      null => '',
      final p => p[0].toUpperCase() + p.substring(1),
    };

    return EnsoScaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          top: topInset(context) + 26,
          bottom: tabBarSpace(context),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: G.jade,
                    shape: BoxShape.circle,
                    boxShadow: S.glow,
                  ),
                  child: Text(
                    (p.name.isNotEmpty ? p.name : 'E')[0].toUpperCase(),
                    style: T.displayXl.copyWith(fontSize: 36, color: C.ivory),
                  ),
                ),
                if (premium.active)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: G.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: C.cream, width: 3),
                      ),
                      child: const Icon(
                        LucideIcons.crown,
                        size: 16,
                        color: C.ink,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              p.name.isNotEmpty ? p.name : tr('profile.friend'),
              style: T.displayMd,
            ),
            const SizedBox(height: 4),
            Text(
              premium.active
                  ? tr('profile.memberStatusPlus', {'n': stats.sessions})
                  : tr('profile.memberStatusFree', {'n': stats.sessions}),
              style: T.caption.s(14),
            ),
            const SizedBox(height: 16),
            Pressable(
              onTap: () => context.push('/edit-profile'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: C.ivory,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: S.soft,
                ),
                child: Text(tr('profile.editProfile'), style: T.label.s(14)),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Reveal(
                    delay: 0.05,
                    child: !premium.active
                        ? Pressable(
                            onTap: () => context.push('/paywall?from=profile'),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: C.ink,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: S.card,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: G.gold,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(
                                      LucideIcons.crown,
                                      size: 28,
                                      color: C.ink,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tr('profile.tryPlusFree'),
                                          style: T.title.c(C.ivory),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tr('profile.allPlansSubtitle'),
                                          style: T.caption.c(
                                            C.ivory.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    LucideIcons.chevronRight,
                                    size: 20,
                                    color: C.gold,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Pressable(
                            onTap: premium.plan == 'lifetime'
                                ? null
                                : () => AppLinks.manageSubscription(),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: C.goldSoft,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: G.gold,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      LucideIcons.crown,
                                      size: 24,
                                      color: C.ink,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tr('profile.plusPlanTitle', {
                                            'plan': planName,
                                          }),
                                          style: T.title,
                                        ),
                                        Text(
                                          premium.plan == 'lifetime'
                                              ? tr('profile.sinceLifetime', {
                                                  'date': premium.since != null
                                                      ? DateFormat.yMd(
                                                          appLocale,
                                                        ).format(premium.since!)
                                                      : tr(
                                                          'profile.todayLower',
                                                        ),
                                                })
                                              : tr('profile.sinceManage', {
                                                  'date': premium.since != null
                                                      ? DateFormat.yMd(
                                                          appLocale,
                                                        ).format(premium.since!)
                                                      : tr(
                                                          'profile.todayLower',
                                                        ),
                                                  'store': AppLinks.storeName,
                                                }),
                                          style: T.caption.c(
                                            C.ink.withValues(alpha: 0.7),
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
                  const SizedBox(height: 16),
                  Reveal(
                    delay: 0.1,
                    child: ECard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr('profile.yourPractice'),
                                  style: T.title,
                                ),
                              ),
                              Pressable(
                                onTap: () => context.push('/edit-profile'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: C.jadeSoft,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    tr('profile.adjust'),
                                    style: T.caption.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: C.jadeDeep,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // equal-height tiles; long answers wrap (web grid)
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _Stat(
                                    LucideIcons.sprout,
                                    tr('profile.level'),
                                    optionLabel('experience', p.experience) ??
                                        tr('profile.notSet'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _Stat(
                                    LucideIcons.waves,
                                    tr('profile.style'),
                                    optionLabel('style', p.style) ??
                                        tr('profile.styleAny'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _Stat(
                                    LucideIcons.clock,
                                    tr('profile.eachDay'),
                                    tr('common.minShort', {
                                      'n': p.dailyMinutes,
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: C.sand.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.shieldCheck,
                                  size: 16,
                                  color: C.jade,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    gentle.isEmpty
                                        ? tr('profile.noGentlerOptions')
                                        : tr('profile.gentlerOptions', {
                                            'options': gentle.join(', '),
                                          }),
                                    style: T.label.s(14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Reveal(
                    delay: 0.14,
                    child: ECard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('profile.yourGoals'), style: T.title),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final g
                                  in (p.goals.isEmpty
                                      ? ['wellbeing']
                                      : p.goals))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: C.jadeSoft,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    goalLabels[g] ?? g,
                                    style: T.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: C.jadeDeep,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Pressable(
                            onTap: () => context.push('/plan/${plan.id}'),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                10,
                                10,
                                16,
                                10,
                              ),
                              decoration: BoxDecoration(
                                color: C.sand.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Row(
                                children: [
                                  RoundedImage(
                                    img(plan.image),
                                    size: 56,
                                    radius: 14,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tr('profile.currentPlan'),
                                          style: T.tiny,
                                        ),
                                        Text(
                                          plan.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: T.label.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Ring(
                                    value: completed.length / plan.days.length,
                                    size: 40,
                                    stroke: 4,
                                    child: Text(
                                      '${completed.length}',
                                      style: T.tiny
                                          .copyWith(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: C.ink,
                                          )
                                          .tab,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Group(
                    title: tr('profile.practice'),
                    children: [
                      _Row(
                        icon: LucideIcons.bell,
                        label: tr('profile.dailyReminder'),
                        value: reminderLabel,
                        onTap: () => context.push('/reminders'),
                      ),
                      _Row(
                        icon: LucideIcons.slidersHorizontal,
                        label: tr('profile.soundVoice'),
                        onTap: () => context.push('/settings'),
                      ),
                      _Row(
                        icon: LucideIcons.languages,
                        label: tr('profile.language'),
                        value: languageNames[appLang],
                        onTap: () => _language(context),
                      ),
                      _Row(
                        icon: LucideIcons.chartColumn,
                        label: tr('profile.history'),
                        value: tr('common.sessions', {'n': app.history.length}),
                        onTap: () => context.push('/history'),
                      ),
                      _Row(
                        icon: LucideIcons.trophy,
                        label: tr('profile.achievements'),
                        value:
                            '${app.unlocked.length}/${Content.i.achievements.length}',
                        onTap: () => context.push('/achievements'),
                      ),
                      Pressable(
                        onTap: () => app.setProfile(
                          (x) => x.units = x.imperial ? 'metric' : 'imperial',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              const _RowIcon(LucideIcons.ruler),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  tr('profile.units'),
                                  style: T.label,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: C.sand,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Row(
                                  children: [
                                    for (final u in [
                                      ('metric', tr('profile.unitsMetric')),
                                      ('imperial', tr('profile.unitsImperial')),
                                    ])
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: p.units == u.$1
                                              ? C.ink
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                        child: Text(
                                          u.$2,
                                          style: T.tiny.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: p.units == u.$1
                                                ? C.ivory
                                                : C.ink,
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
                    ],
                  ),
                  _Group(
                    title: tr('profile.support'),
                    children: [
                      _Row(
                        icon: LucideIcons.star,
                        label: tr('profile.rateApp'),
                        onTap: () => AppLinks.rate(),
                      ),
                      _Row(
                        icon: LucideIcons.share2,
                        label: tr('profile.shareWithFriend'),
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: tr('profile.shareInviteText')),
                          );
                          Toast.show(
                            tr('profile.inviteCopied'),
                            description: tr('profile.pasteToFriend'),
                          );
                        },
                      ),
                      _Row(
                        icon: LucideIcons.refreshCw,
                        label: tr('profile.restorePurchases'),
                        onTap: () => _restore(context),
                      ),
                      _Row(
                        icon: LucideIcons.circleHelp,
                        label: tr('profile.helpFeedback'),
                        onTap: () async {
                          if (!await AppLinks.contact()) {
                            await Clipboard.setData(
                              ClipboardData(text: Content.i.legal.contact),
                            );
                            Toast.show(
                              tr('profile.supportEmailCopied'),
                              description: Content.i.legal.contact,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  _Group(
                    title: tr('profile.about'),
                    children: [
                      _Row(
                        icon: LucideIcons.shield,
                        label: tr('profile.privacyPolicy'),
                        onTap: () => context.push('/legal/privacy'),
                      ),
                      _Row(
                        icon: LucideIcons.fileText,
                        label: tr('profile.termsOfUse'),
                        onTap: () => context.push('/legal/terms'),
                      ),
                      _Row(
                        icon: LucideIcons.trash2,
                        label: tr('profile.resetAllData'),
                        danger: true,
                        onTap: () => _reset(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: FutureBuilder<String>(
                      future: AppLinks.version(),
                      builder: (_, v) => Text(
                        tr('profile.versionFooter', {'version': v.data ?? ''}),
                        style: T.tiny.w(FontWeight.w400),
                      ),
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

  Future<void> _restore(BuildContext context) async {
    final app = context.read<AppState>();
    Toast.show(tr('profile.checkingPurchases'));
    final ok = await PurchaseService.restore();
    if (ok) {
      if (!app.premium.active) app.setPremium('yearly');
      Toast.show(
        tr('profile.plusRestored'),
        description: tr('profile.welcomeBack'),
      );
    } else {
      Toast.show(
        tr('profile.noPurchaseFound'),
        description: tr('profile.useStoreAccount', {
          'store': AppLinks.storeName,
        }),
      );
    }
  }

  /// Language picker: the device language (default) or any shipped language, each in its own name.
  void _language(BuildContext context) {
    final app = context.read<AppState>();
    showEnsoSheet<void>(
      context,
      builder: (ctx) {
        Widget option(String? code, String title) {
          final selected = app.language == code;
          return Semantics(
            button: true,
            selected: selected,
            child: Pressable(
              onTap: () {
                Navigator.pop(ctx);
                if (!selected) app.setLanguage(code);
              },
              scale: 0.985,
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected ? C.jadeSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: T.label)),
                    if (selected)
                      const Icon(
                        LucideIcons.check,
                        size: 20,
                        color: C.jadeDeep,
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('profile.languageSheetTitle'),
                style: T.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      option(null, tr('profile.deviceLanguage')),
                      for (final e in languageNames.entries)
                        option(e.key, e.value),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _reset(BuildContext context) {
    final app = context.read<AppState>();
    showEnsoSheet<void>(
      context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Column(
            children: [
              Text(tr('profile.resetEverything'), style: T.displayMd),
              const SizedBox(height: 8),
              Text(
                tr('profile.resetDescription'),
                textAlign: TextAlign.center,
                style: T.bodySm.c(C.muted),
              ),
              const SizedBox(height: 24),
              Pressable(
                onTap: () {
                  Navigator.pop(ctx);
                  app.reset();
                  context.go('/welcome');
                },
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: C.danger,
                    borderRadius: BorderRadius.circular(56),
                  ),
                  child: Text(
                    tr('profile.eraseStartOver'),
                    style: T.label.copyWith(fontSize: 17, color: C.ivory),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              EnsoButton(
                label: tr('common.cancel'),
                variant: BtnVariant.ghost,
                size: BtnSize.md,
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: C.sand.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: C.jade),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: T.label.copyWith(fontWeight: FontWeight.w700).tab,
        ),
        Text(
          label,
          style: T.tiny.copyWith(fontSize: 11, fontWeight: FontWeight.w400),
        ),
      ],
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: T.tiny.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: C.ivory,
            borderRadius: BorderRadius.circular(26),
            boxShadow: S.soft,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: C.line),
                children[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon, {this.danger = false});
  final IconData icon;
  final bool danger;
  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: danger ? C.terracottaSoft : C.sand,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, size: 18, color: danger ? C.danger : C.jadeDeep),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.985,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _RowIcon(icon, danger: danger),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: T.label.c(danger ? C.danger : C.ink)),
          ),
          if (value != null) ...[
            Text(value!, style: T.caption.s(14)),
            const SizedBox(width: 6),
          ],
          const Icon(LucideIcons.chevronRight, size: 16, color: C.muted),
        ],
      ),
    ),
  );
}
