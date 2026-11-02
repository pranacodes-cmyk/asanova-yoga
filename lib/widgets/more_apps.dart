import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/i18n.dart';
import '../services/analytics_service.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// Our studio's other apps (web `src/components/enso/MoreApps.tsx`). Each platform lists only
/// apps that are live in its own store: Play on Android, App Store (Prayly, AmenFirst) on iOS.
class StudioApp {
  const StudioApp(this.id, this.name, this.taglineKey, this.icon);
  final String id, name, taglineKey, icon;
}

/// App Store apps, keyed by their numeric Apple ID.
const iosStudioApps = [
  StudioApp('6772946279', 'Prayly', 'promo.praylyTagline', 'assets/images/app-prayly.png'),
  StudioApp('6816923095', 'AmenFirst', 'promo.amenFirstTagline', 'assets/images/app-amenfirst.png'),
];

String iosStudioAppUrl(String id) => 'https://apps.apple.com/app/id$id?ct=asanova_cross_promo';

const studioApps = [
  StudioApp('com.mylifecalendar.app', 'Life Calendar', 'promo.lifeCalendarTagline', 'assets/images/app-mylife.png'),
  StudioApp('com.atriumstudio.app', 'Atrium', 'promo.atriumTagline', 'assets/images/app-atrium.png'),
  StudioApp('com.jesuswallpaperbible.app', 'Prayly', 'promo.praylyTagline', 'assets/images/app-prayly.png'),
];

String studioAppUrl(String id) =>
    'https://play.google.com/store/apps/details?id=$id&referrer=utm_source%3Dasanova%26utm_medium%3Dcross_promo';

class MoreApps extends StatelessWidget {
  const MoreApps({super.key});

  static bool get _ios => !kIsWeb && Platform.isIOS;
  static List<StudioApp> get apps => _ios ? iosStudioApps : studioApps;
  static bool get available => apps.isNotEmpty;

  Future<void> _open(String id) async {
    AnalyticsService.event('cross_promo_clicked', {'app_id': id});
    if (_ios) {
      await launchUrl(Uri.parse(iosStudioAppUrl(id)), mode: LaunchMode.externalApplication);
      return;
    }
    try {
      await launchUrl(
        Uri.parse('market://details?id=$id&referrer=utm_source%3Dasanova%26utm_medium%3Dcross_promo'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      await launchUrl(Uri.parse(studioAppUrl(id)), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!available) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              tr('profile.moreApps').toUpperCase(),
              style: T.tiny.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
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
                for (var i = 0; i < apps.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: C.line),
                  _AppRow(app: apps[i], onTap: () => _open(apps[i].id)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.onTap});
  final StudioApp app;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.985,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(app.icon, width: 52, height: 52, fit: BoxFit.cover),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.name, style: T.label.c(C.ink)),
                const SizedBox(height: 2),
                Text(
                  tr(app.taglineKey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: T.caption.s(13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: C.jadeDeep,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('profile.moreAppsGet'),
                  style: T.tiny.copyWith(fontWeight: FontWeight.w700, color: C.ivory),
                ),
                const SizedBox(width: 4),
                const Icon(LucideIcons.arrowUpRight, size: 14, color: C.ivory),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
