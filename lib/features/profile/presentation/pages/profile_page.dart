import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../domain/entities/profile_data.dart';
import '../../domain/repositories/profile_repository.dart';

// Tujuan: Halaman profil user — menampilkan foto profil (dari URL), nama, divisi, jabatan, employee ID, dan logout.
// Caller: FeatureShellPage via route /profile.
// Dependensi: ProfileRepository, CachedNetworkImage, AppColors.
// Main Functions: ProfilePage (widget utama), _buildProfileHeader, _buildInitialsAvatar, _buildInfoCard, _confirmLogout.
// Side Effects: Fetch GET /api/v1/users/profile via ProfileRepository.getProfile(); CachedNetworkImage load dari object storage.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = sl<ProfileRepository>();
    return FutureBuilder<ProfileData>(
      future: repository.getProfile(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            children: [
              _buildProfileHeader(profile),
              const SizedBox(height: 24),
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
              // Role card intentionally hidden from UI.
              // Permissions section intentionally hidden from UI.
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context, repository),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusLocked,
                    side: const BorderSide(color: AppColors.statusLocked),
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                    placeholder: (context, url) => const Center(
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
        const SizedBox(height: 14),
        Text(
          profile.fullName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${profile.grade} — ${profile.division}',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  /// Widget avatar inisial (fallback saat tidak ada foto).
  Widget _buildInitialsAvatar(String initials) {
    return Container(
      color: AppColors.gold.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.gold),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
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
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Logout?',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: const Text('Anda akan keluar dari akun ini.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
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
            child: const Text('Logout',
                style: TextStyle(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
