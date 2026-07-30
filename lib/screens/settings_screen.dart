import 'dart:async';

import 'package:flutter/material.dart';
import '../core/auth/auth_state.dart';
import '../core/common/app_settings_state.dart';
import '../core/notification/notification_permission_service.dart';
import '../data/user/user_repository.dart';
import '../theme/app_palette.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_snackbar.dart';
import '../utils/legal_document_links.dart';
import '../widgets/screen_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _isUpdatingAgreements = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncNotificationStateOnResume());
    }
  }

  Future<void> _syncNotificationStateOnResume() async {
    await NotificationPermissionService.syncNotificationPermissionState();
    await NotificationPermissionService.syncCurrentDeviceTokenPreference();
  }

  Future<void> _handlePushToggle(bool value) async {
    if (_isUpdatingAgreements) return;
    if (!AuthState.isLoggedIn.value) {
      showAppSnackBar(context, '로그인 후 알림 설정을 진행할 수 있어요.');
      return;
    }

    final previousPush = AppSettingsState.pushEnabled.value;
    final previousNightPush = AppSettingsState.nightPushEnabled.value;
    final previousMarketing = AppSettingsState.marketingEnabled.value;

    if (!value) {
      AppSettingsState.setPushEnabled(false);
      try {
        await _updateAgreements(
          pushAgreed: false,
          nightAgreed: false,
          mktAgreed: false,
        );
        await NotificationPermissionService.syncCurrentDeviceTokenPreference();
      } catch (e) {
        _restoreNotificationSettings(
          pushEnabled: previousPush,
          nightPushEnabled: previousNightPush,
          marketingEnabled: previousMarketing,
        );
        if (mounted) {
          showAppSnackBar(context, '알림 동의를 변경하지 못했어요. 잠시 후 다시 시도해주세요.');
        }
      }
      return;
    }

    final granted =
        await NotificationPermissionService.ensureGrantedForSettings(context);
    if (!granted) return;

    AppSettingsState.setPushEnabled(true);
    try {
      await _updateAgreements(pushAgreed: true);
      await NotificationPermissionService.syncCurrentDeviceTokenPreference();
    } catch (e) {
      _restoreNotificationSettings(
        pushEnabled: previousPush,
        nightPushEnabled: previousNightPush,
        marketingEnabled: previousMarketing,
      );
      if (mounted) {
        showAppSnackBar(context, '알림 동의를 변경하지 못했어요. 잠시 후 다시 시도해주세요.');
      }
    }
  }

  Future<void> _handleNightPushToggle(bool value) async {
    if (_isUpdatingAgreements) return;
    if (!AuthState.isLoggedIn.value) {
      showAppSnackBar(context, '로그인 후 알림 설정을 진행할 수 있어요.');
      return;
    }

    final previousValue = AppSettingsState.nightPushEnabled.value;

    if (!value) {
      AppSettingsState.setNightPushEnabled(false);
      try {
        await _updateAgreements(nightAgreed: false);
      } catch (e) {
        AppSettingsState.setNightPushEnabled(previousValue);
        if (mounted) {
          showAppSnackBar(context, '야간 알림 동의를 변경하지 못했어요.');
        }
      }
      return;
    }

    final granted =
        await NotificationPermissionService.ensureGrantedForSettings(context);
    if (!granted) return;

    AppSettingsState.setNightPushEnabled(true);
    try {
      await _updateAgreements(nightAgreed: true);
    } catch (e) {
      AppSettingsState.setNightPushEnabled(previousValue);
      if (mounted) {
        showAppSnackBar(context, '야간 알림 동의를 변경하지 못했어요.');
      }
    }
  }

  Future<void> _handleMarketingToggle(bool value) async {
    if (_isUpdatingAgreements) return;
    if (!AuthState.isLoggedIn.value) {
      showAppSnackBar(context, '로그인 후 알림 설정을 진행할 수 있어요.');
      return;
    }

    final previousValue = AppSettingsState.marketingEnabled.value;

    if (!value) {
      AppSettingsState.setMarketingEnabled(false);
      try {
        await _updateAgreements(mktAgreed: false);
      } catch (e) {
        AppSettingsState.setMarketingEnabled(previousValue);
        if (mounted) {
          showAppSnackBar(context, '마케팅 수신 동의를 변경하지 못했어요.');
        }
      }
      return;
    }

    final granted =
        await NotificationPermissionService.ensureGrantedForSettings(context);
    if (!granted) return;

    AppSettingsState.setMarketingEnabled(true);
    try {
      await _updateAgreements(mktAgreed: true);
    } catch (e) {
      AppSettingsState.setMarketingEnabled(previousValue);
      if (mounted) {
        showAppSnackBar(context, '마케팅 수신 동의를 변경하지 못했어요.');
      }
    }
  }

  Future<void> _updateAgreements({
    bool? pushAgreed,
    bool? nightAgreed,
    bool? mktAgreed,
  }) async {
    final accessToken = AuthState.session?.accessToken;
    if (accessToken == null || accessToken.isEmpty) return;

    _isUpdatingAgreements = true;
    try {
      await UserRepository.updateAgreements(
        accessToken: accessToken,
        pushAgreed: pushAgreed,
        nightAgreed: nightAgreed,
        mktAgreed: mktAgreed,
      );
    } finally {
      _isUpdatingAgreements = false;
    }
  }

  void _restoreNotificationSettings({
    required bool pushEnabled,
    required bool nightPushEnabled,
    required bool marketingEnabled,
  }) {
    AppSettingsState.setPushEnabled(pushEnabled);
    if (pushEnabled) {
      AppSettingsState.setNightPushEnabled(nightPushEnabled);
      AppSettingsState.setMarketingEnabled(marketingEnabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: '설정', onTapBack: () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: Column(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: AppSettingsState.pushEnabled,
                      builder: (context, pushEnabled, _) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: AppSettingsState.nightPushEnabled,
                          builder: (context, nightPushEnabled, _) {
                            return ValueListenableBuilder<bool>(
                              valueListenable:
                                  AppSettingsState.marketingEnabled,
                              builder: (context, marketingEnabled, _) {
                                return _SectionCard(
                                  title: '알림 설정',
                                  child: Column(
                                    children: [
                                      _SettingToggleTile(
                                        title: '푸시 알림 동의',
                                        subtitle:
                                            '방문 일정, 문의 상태, 주요 알림을 받아볼 수 있어요.',
                                        value: pushEnabled,
                                        onChanged: _handlePushToggle,
                                      ),
                                      const SizedBox(height: 10),
                                      _SettingToggleTile(
                                        title: '야간 알림 허용',
                                        subtitle:
                                            '늦은 시간에도(22:00 ~ 08:00) 필요한 알림을 받을 수 있어요.',
                                        value: nightPushEnabled,
                                        onChanged: pushEnabled
                                            ? _handleNightPushToggle
                                            : null,
                                      ),
                                      const SizedBox(height: 10),
                                      _SettingToggleTile(
                                        title: '마케팅 수신 동의',
                                        subtitle: '이벤트, 혜택, 추천 소식을 받아볼 수 있어요.',
                                        value: marketingEnabled,
                                        onChanged: pushEnabled
                                            ? _handleMarketingToggle
                                            : null,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: AppSettingsState.themeMode,
                      builder: (context, themeMode, _) {
                        final isDarkMode = themeMode == ThemeMode.dark;

                        return _SectionCard(
                          title: '화면 설정',
                          child: Column(
                            children: [
                              _ThemeModeTile(
                                isDarkMode: isDarkMode,
                                onChanged: AppSettingsState.setDarkMode,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  12,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.surfaceSoft,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: palette.border),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 18,
                                      color: palette.textSecondary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '설정에서 선택한 테마가 앱 전체에 바로 반영돼요.',
                                        style: AppTextStyles.homeBody.copyWith(
                                          height: 1.45,
                                          color: palette.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: '기타',
                      child: Column(
                        children: [
                          _SimpleMenuTile(
                            icon: Icons.description_outlined,
                            title: '이용약관',
                            subtitle: '서비스 이용 관련 내용을 확인할 수 있어요.',
                            onTap: () {
                              LegalDocumentLinks.open(
                                context,
                                LegalDocumentLinks.terms,
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _SimpleMenuTile(
                            icon: Icons.privacy_tip_outlined,
                            title: '개인정보처리방침',
                            subtitle: '개인정보 수집 및 이용 정책을 확인할 수 있어요.',
                            onTap: () {
                              LegalDocumentLinks.open(
                                context,
                                LegalDocumentLinks.privacy,
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _SimpleMenuTile(
                            icon: Icons.manage_accounts_outlined,
                            title: '계정 삭제 안내',
                            subtitle: '앱을 사용할 수 없을 때의 계정 삭제 방법을 확인해요.',
                            onTap: () {
                              LegalDocumentLinks.open(
                                context,
                                LegalDocumentLinks.accountDeletion,
                              );
                            },
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
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: palette.shadow,
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: AppTextStyles.homeSectionTitle.copyWith(
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SettingToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final Future<void> Function(bool)? onChanged;

  const _SettingToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onChanged != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: enabled ? palette.surfaceSoft : palette.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.homeBodyStrong.copyWith(
                    color: enabled ? palette.textPrimary : palette.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.homeCaption.copyWith(
                    height: 1.4,
                    color: enabled
                        ? palette.textSecondary
                        : palette.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Transform.scale(
            scale: 0.95,
            child: Switch(
              value: value,
              onChanged: onChanged == null
                  ? null
                  : (nextValue) => onChanged!(nextValue),
              activeThumbColor: palette.primaryStrong,
              activeTrackColor: palette.primary.withValues(alpha: 0.58),
              inactiveThumbColor: palette.textTertiary,
              inactiveTrackColor: palette.surfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onChanged;

  const _ThemeModeTile({required this.isDarkMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: 22,
              color: palette.primaryStrong,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDarkMode ? '다크모드' : '라이트모드',
                  style: AppTextStyles.homeBodyStrong.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '앱 화면 테마를 변경할 수 있어요.',
                  style: AppTextStyles.homeCaption.copyWith(
                    height: 1.4,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: isDarkMode,
            onChanged: onChanged,
            activeThumbColor: palette.primaryStrong,
            activeTrackColor: palette.primary.withValues(alpha: 0.58),
            inactiveThumbColor: palette.textTertiary,
            inactiveTrackColor: palette.surfaceMuted,
          ),
        ],
      ),
    );
  }
}

class _SimpleMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SimpleMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.surfaceSoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: palette.primaryStrong),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.homeBodyStrong.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.homeCaption.copyWith(
                        height: 1.4,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: palette.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
