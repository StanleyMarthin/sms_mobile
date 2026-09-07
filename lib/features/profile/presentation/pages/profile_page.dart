// Tujuan: Halaman profil user — menampilkan foto profil, data user, mode tema, dan logout.
// Caller: FeatureShellPage via route /profile.
// Dependensi: ProfileRepository, CachedNetworkImage, AppColors.
// Main Functions: ProfilePage, _buildProfileHeader, _buildInitialsAvatar, _buildInfoCard, _confirmLogout.
// Side Effects: Fetch GET /api/v1/users/profile via ProfileRepository.getProfile(); CachedNetworkImage load avatar.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../domain/entities/profile_data.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = sl<ProfileRepository>();
    return FutureBuilder<ProfileData>(
      future: repository.getProfile(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final profile = snapshot.data!;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            children: [
              _buildProfileHeader(profile),
              SizedBox(height: 24),
              _buildInfoCard(
                icon: Icons.badge_outlined,
                label: 'Employee ID',
                value: profile.employeeId,
              ),
              _buildInfoCard(
                icon: Icons.business_outlined,
                label: 'Divisi',
                value: profile.division,
              ),
              _buildInfoCard(
                icon: Icons.work_outline_rounded,
                label: 'Jabatan',
                value: profile.grade,
              ),
              const SizedBox(height: 24),
              _buildThemeCard(),
              // Role card intentionally hidden from UI.
              // Permissions section intentionally hidden from UI.
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context, repository),
                  icon: Icon(Icons.logout_rounded, size: 18),
                  label: Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusLocked,
                    side: BorderSide(color: AppColors.statusLocked),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(ProfileData profile) {
    final initials = profile.fullName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    final hasPhoto =
        profile.photoUrl != null && profile.photoUrl!.trim().isNotEmpty;

    return Column(
      children: [
        // Avatar circle — foto profil atau inisial fallback
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.gold.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: ClipOval(
            child: hasPhoto
                ? CachedNetworkImage(
                    imageUrl: profile.photoUrl!,
                    fit: BoxFit.cover,
                    width: 88,
                    height: 88,
                    memCacheWidth: 176,
                    memCacheHeight: 176,
                    placeholder: (context, url) => Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      debugPrint('--- AVATAR LOAD ERROR: $error ---');
                      return _buildInitialsAvatar(initials);
                    },
                  )
                : _buildInitialsAvatar(initials),
          ),
        ),
        SizedBox(height: 14),
        Text(
          profile.fullName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '${profile.grade} — ${profile.division}',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildThemeCard() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: ValueListenableBuilder<String>(
        valueListenable: ThemeController.mode,
        builder: (context, mode, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, size: 20, color: AppColors.gold),
                const SizedBox(width: 14),
                Text(
                  'Mode Tampilan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Ikuti Sistem: mengikuti mode gelap/terang HP.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'system',
                  label: Text('Sistem'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: 'light',
                  label: Text('Terang'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: 'dark',
                  label: Text('Gelap'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) =>
                  ThemeController.setMode(selection.first),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget avatar inisial (fallback saat tidak ada foto).
  Widget _buildInitialsAvatar(String initials) {
    return Container(
      color: AppColors.gold.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.gold,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.gold),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Permissions section intentionally kept out of the UI because access data is background-only.

  void _confirmLogout(BuildContext context, ProfileRepository repository) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(
          'Logout?',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        content: Text(
          'Anda akan keluar dari akun ini.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await repository.logout();
              if (!context.mounted) return;
              context.go('/login');
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusLocked,
            ),
            child: Text(
              'Logout',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
