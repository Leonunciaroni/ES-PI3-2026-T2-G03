// Autor principal: Mariana Ferrarez
// RA: 25002010

import 'package:flutter/material.dart';

/// Avatar de perfil editável: exibe imagem ou iniciais e abre um BottomSheet.
class AvatarPerfilEditavel extends StatelessWidget {
  const AvatarPerfilEditavel({
    super.key,
    required this.iniciais,
    required this.primary,
    this.photoUrl,
    this.onTakePhoto,
    this.onChooseFromGallery,
    this.onRemovePhoto,
  });

  final String iniciais;
  final String? photoUrl;
  final Color primary;
  final VoidCallback? onTakePhoto;
  final VoidCallback? onChooseFromGallery;
  final VoidCallback? onRemovePhoto;

  Future<void> _mostrarOpcoes(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Text(
                  'Escolher foto do perfil',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecione uma opção para atualizar sua foto de perfil.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 16),
                _AvatarOptionTile(
                  icon: Icons.camera_alt_outlined,
                  label: 'Tirar foto',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onTakePhoto?.call();
                  },
                ),
                _AvatarOptionTile(
                  icon: Icons.photo_library_outlined,
                  label: 'Escolher da galeria',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onChooseFromGallery?.call();
                  },
                ),
                _AvatarOptionTile(
                  icon: Icons.delete_outline,
                  label: 'Remover foto',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onRemovePhoto?.call();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoUrlValue = photoUrl?.trim();
    final hasPhoto = photoUrlValue?.isNotEmpty == true;

    return GestureDetector(
      onTap: () => _mostrarOpcoes(context),
      child: ClipOval(
        child: Container(
          width: 72,
          height: 72,
          color: primary,
          alignment: Alignment.center,
          child: hasPhoto
              ? Image.network(
                  photoUrlValue!,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Text(
                    iniciais,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                )
              : Text(
                  iniciais,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
        ),
      ),
    );
  }
}

class _AvatarOptionTile extends StatelessWidget {
  const _AvatarOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

