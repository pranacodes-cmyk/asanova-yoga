import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import '../widgets/scaffold.dart';
import '../widgets/toast.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final AppState app = context.read<AppState>();
  late final Profile draft = app.profile.copy();
  late final TextEditingController _name = TextEditingController(
    text: draft.name,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    draft.name = _name.text.trim();
    app.replaceProfile(draft);
    Toast.show(tr('editProfile.profileSaved'), tone: 'success');
    context.canPop() ? context.pop() : context.go('/profile');
  }

  List<OnbOptionLite> _opts(String id) =>
      (Content.i.step(id)?.options ?? const [])
          .map((o) => OnbOptionLite(o.id, o.label))
          .toList();

  @override
  Widget build(BuildContext context) {
    final watch = context.watch<AppState>();
    final suggested = recommendFor(draft);
    final suggestedPlan = Content.i.plan(suggested);

    return EnsoScaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              top: topInset(context) + 10,
              bottom: bottomInset(context) + 120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: BackBtn(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Text(tr('editProfile.title'), style: T.displayLg),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Field(
                        tr('editProfile.name'),
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: C.ivory,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: S.soft,
                          ),
                          alignment: Alignment.centerLeft,
                          child: TextField(
                            controller: _name,
                            maxLength: 24,
                            textCapitalization: TextCapitalization.words,
                            style: T.label.copyWith(fontSize: 17),
                            decoration: InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                              hintText: tr('editProfile.namePlaceholder'),
                              hintStyle: T.label.copyWith(
                                fontSize: 17,
                                color: C.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _Field(
                        tr('editProfile.age'),
                        Row(
                          children: [
                            for (final (i, o) in _opts('ageGroup').indexed) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: _Pill(
                                  o.label,
                                  draft.ageGroup == o.id,
                                  () => setState(() => draft.ageGroup = o.id),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _Field(
                        tr('editProfile.goals'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final o in _opts('goals'))
                              _Pill(
                                o.label,
                                draft.goals.contains(o.id),
                                () => setState(
                                  () => draft.goals = draft.goals.contains(o.id)
                                      ? draft.goals
                                            .where((g) => g != o.id)
                                            .toList()
                                      : [...draft.goals, o.id],
                                ),
                              ),
                          ],
                        ),
                      ),
                      _Field(
                        tr('editProfile.yogaLevel'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final o in _opts('experience'))
                              _Pill(
                                o.label,
                                draft.experience == o.id,
                                () => setState(() => draft.experience = o.id),
                              ),
                          ],
                        ),
                      ),
                      _Field(
                        tr('editProfile.style'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final o in _opts('style'))
                              _Pill(
                                o.label,
                                draft.style == o.id,
                                () => setState(() => draft.style = o.id),
                              ),
                          ],
                        ),
                      ),
                      _Field(
                        tr('editProfile.gentlerOptionsFor'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final o in _opts('limitations'))
                              _Pill(
                                o.label,
                                draft.limitations.contains(o.id),
                                () => setState(
                                  () => draft.limitations = toggleExclusive(
                                    draft.limitations,
                                    o.id,
                                    'none',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      _Field(
                        tr('editProfile.dailyPractice'),
                        Row(
                          children: [
                            for (final (i, m) in const [
                              5,
                              10,
                              15,
                              20,
                            ].indexed) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: _Pill(
                                  tr('common.minShort', {'n': m}),
                                  draft.dailyMinutes == m,
                                  () => setState(() => draft.dailyMinutes = m),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (suggested != watch.activePlanId &&
                          suggestedPlan != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: C.jadeSoft,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    LucideIcons.sparkles,
                                    size: 16,
                                    color: C.jadeDeep,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    tr('editProfile.suggestedForGoals'),
                                    style: T.caption.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: C.jadeDeep,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                suggestedPlan.title,
                                style: T.title.c(C.jadeDeep),
                              ),
                              const SizedBox(height: 12),
                              EnsoButton(
                                label: tr('editProfile.switchToThisPlan'),
                                size: BtnSize.sm,
                                expand: false,
                                onTap: () {
                                  app.startPlan(suggested);
                                  Toast.show(
                                    tr('editProfile.planUpdated'),
                                    description: suggestedPlan.title,
                                    tone: 'success',
                                  );
                                },
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
          BottomCta(
            child: EnsoButton(
              label: tr('editProfile.saveChanges'),
              onTap: _save,
            ),
          ),
        ],
      ),
    );
  }
}

class OnbOptionLite {
  const OnbOptionLite(this.id, this.label);
  final String id, label;
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.child);
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: T.tiny.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.on, this.onTap);
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: on ? C.ink : C.ivory,
        borderRadius: BorderRadius.circular(44),
        boxShadow: on ? null : S.soft,
      ),
      // widthFactor 1: the pill hugs its label inside a Wrap (web flex-wrap)
      child: Align(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          style: T.label.copyWith(fontSize: 14, color: on ? C.ivory : C.ink),
        ),
      ),
    ),
  );
}
