import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/cloudinary_upload.dart';
import '../../core/utils/password_strength.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/list_widgets.dart';
import '../../widgets/page_container.dart';
import '../../widgets/user_avatar.dart';
import '../auth/password_strength_meter.dart';
import 'change_email_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _avatarBusy = false;
  String _avatarError = '';

  final _name = TextEditingController();
  final _email = TextEditingController();
  String _profileError = '';
  String _profileSuccess = '';
  bool _savingProfile = false;

  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  String _passwordError = '';
  String _passwordSuccess = '';
  bool _savingPassword = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _name.text = user?.name ?? '';
    _email.text = user?.email ?? '';
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _currentPassword, _newPassword, _confirmPassword]) {
      c.dispose();
    }
    super.dispose();
  }

  AuthProvider get _auth => context.read<AuthProvider>();

  Future<void> _pickAvatar() async {
    setState(() => _avatarError = '');
    XFile? file;
    try {
      file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    } catch (_) {
      setState(() => _avatarError = 'Could not open the image picker.');
      return;
    }
    if (file == null) return;
    final problem = await validateAvatarImage(file);
    if (problem.isNotEmpty) {
      setState(() => _avatarError = problem);
      return;
    }
    setState(() => _avatarBusy = true);
    try {
      final updated = await uploadAvatar(file);
      _auth.updateCurrentUser({'avatar': updated['avatar']});
    } catch (e) {
      final text = e.toString().replaceFirst('Exception: ', '');
      setState(() => _avatarError = apiErrorMessage(e, text.isEmpty ? 'Failed to upload picture.' : text));
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() {
      _avatarError = '';
      _avatarBusy = true;
    });
    try {
      await AuthService.removeAvatar();
      _auth.updateCurrentUser({'avatar': ''});
    } catch (e) {
      setState(() => _avatarError = apiErrorMessage(e, 'Failed to remove picture.'));
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = _auth.user;
    if (user == null) return;
    setState(() {
      _profileError = '';
      _profileSuccess = '';
    });
    final newName = _name.text.trim();
    final newEmail = _email.text.trim().toLowerCase();
    if (newName.isEmpty) {
      setState(() => _profileError = 'Name is required.');
      return;
    }
    final nameChanged = newName != user.name;
    final emailChanged = newEmail != user.email.toLowerCase();
    if (!nameChanged && !emailChanged) {
      setState(() => _profileSuccess = 'No changes to save.');
      return;
    }

    setState(() => _savingProfile = true);
    try {
      if (nameChanged) {
        final res = await UserService.updateUser(user.id, {'name': newName});
        _auth.updateCurrentUser({'name': (res['data'] as Map?)?['name'] ?? newName});
      }
      if (emailChanged) {
        final res = await AuthService.requestEmailChange(newEmail);
        final data = (res['data'] as Map?) ?? const {};
        if (!mounted) return;
        setState(() => _savingProfile = false);
        final confirmed = await showChangeEmailDialog(
          context,
          newEmail: '${data['newEmail'] ?? newEmail}',
          currentEmailMasked: '${data['currentEmailMasked'] ?? user.email}',
          initialCooldown: (data['resendAfterSeconds'] as num?)?.toInt() ?? 60,
        );
        if (!mounted) return;
        if (confirmed != null) {
          _auth.updateCurrentUser({'email': confirmed});
          _email.text = confirmed;
          setState(() => _profileSuccess = 'Email updated successfully.');
        } else {
          _email.text = _auth.user?.email ?? '';
          if (nameChanged) setState(() => _profileSuccess = 'Name updated. Email was not changed.');
        }
      } else {
        setState(() => _profileSuccess = 'Profile updated.');
      }
    } catch (e) {
      if (mounted) setState(() => _profileError = apiErrorMessage(e, 'Failed to update profile.'));
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    setState(() {
      _passwordError = '';
      _passwordSuccess = '';
    });
    if (_currentPassword.text.isEmpty) {
      setState(() => _passwordError = 'Enter your current password.');
      return;
    }
    if (!evaluatePassword(_newPassword.text).isValid) {
      setState(() => _passwordError = 'New password does not meet all the requirements below.');
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      setState(() => _passwordError = 'New passwords do not match');
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await AuthService.changePassword(_currentPassword.text, _newPassword.text, _confirmPassword.text);
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() => _passwordSuccess = 'Password changed successfully.');
    } catch (e) {
      if (mounted) setState(() => _passwordError = apiErrorMessage(e, 'Failed to change password.'));
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Widget _card(String title, List<Widget> children) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final user = context.watch<AuthProvider>().user;
    final role = user?.role ?? '';
    final mismatch =
        _confirmPassword.text.isNotEmpty && _newPassword.text != _confirmPassword.text;

    return PageContainer(
      maxWidth: 720,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _card('Account details', [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    UserAvatar(user, radius: 40),
                    if (_avatarBusy)
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (role.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SmallChip('${role[0].toUpperCase()}${role.substring(1)}',
                              color: role == 'admin' ? AppPalette.primary : null),
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _avatarBusy ? null : _pickAvatar,
                            icon: const Icon(Icons.photo_camera_rounded, size: 18),
                            label: Text(user?.avatar != null ? 'Change photo' : 'Upload photo'),
                          ),
                          if (user?.avatar != null)
                            TextButton.icon(
                              style: TextButton.styleFrom(foregroundColor: AppPalette.error),
                              onPressed: _avatarBusy ? null : _removeAvatar,
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: const Text('Remove'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('JPG, PNG or WebP, up to 2 MB.',
                          style: TextStyle(fontSize: 12, color: p.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_avatarError.isNotEmpty)
              AppAlert(_avatarError, onClose: () => setState(() => _avatarError = '')),
            if (_profileError.isNotEmpty) AppAlert(_profileError),
            if (_profileSuccess.isNotEmpty) AppAlert(_profileSuccess, severity: AlertSeverity.success),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email *',
                helperText: 'Changing your email requires codes sent to both your current and new address.',
                helperMaxLines: 3,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _savingProfile ? null : _saveProfile,
              child: Text(_savingProfile ? 'Saving…' : 'Save changes'),
            ),
          ]),
          const SizedBox(height: 16),
          _card('Change password', [
            if (_passwordError.isNotEmpty) AppAlert(_passwordError),
            if (_passwordSuccess.isNotEmpty) AppAlert(_passwordSuccess, severity: AlertSeverity.success),
            TextField(
              controller: _currentPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPassword,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'New password *'),
            ),
            const SizedBox(height: 8),
            PasswordStrengthMeter(password: _newPassword.text),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPassword,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Confirm new password *',
                errorText: mismatch ? 'Passwords do not match' : null,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _savingPassword ? null : _changePassword,
              child: Text(_savingPassword ? 'Saving…' : 'Change password'),
            ),
          ]),
        ],
      ),
    );
  }
}
