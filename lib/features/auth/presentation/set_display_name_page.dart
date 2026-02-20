import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../providers/auth_providers.dart';

class SetDisplayNamePage extends ConsumerStatefulWidget {
  const SetDisplayNamePage({super.key});

  @override
  ConsumerState<SetDisplayNamePage> createState() => _SetDisplayNamePageState();
}

class _SetDisplayNamePageState extends ConsumerState<SetDisplayNamePage> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final name = _nameController.text.trim();

      if (name.isEmpty) {
        setState(() => _error = 'Please enter a display name');
        return;
      }

      if (name.length < 3) {
        setState(() => _error = 'Name must be at least 3 characters');
        return;
      }

      if (name.length > 20) {
        setState(() => _error = 'Name must be at most 20 characters');
        return;
      }

      final authService = ref.read(authServiceProvider);
      await authService.updateDisplayName(name);

      // Refresh profile provider to ensure app state is up to date
      ref.invalidate(profileProvider);

      if (mounted) {
        context.go('/menu');
      }
    } catch (e) {
      setState(() => _error = 'Failed to update display name');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [AppColors.surface, AppColors.background],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'WELCOME',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppColors.playerX,
                    fontSize: 32,
                    letterSpacing: 4,
                  ),
                ),
                Text(
                  'PLAYER',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppColors.playerO,
                    fontSize: 48,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Choose your display name',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: 'Enter Name',
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                      color: AppColors.playerX,
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.loss),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.background,
                            ),
                          )
                        : const Text('CONTINUE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
