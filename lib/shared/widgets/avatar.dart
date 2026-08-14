import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserAvatar extends StatelessWidget {
  final String? name;
  final String? imageUrl;
  final double size;
  final bool showStatus;
  final String? status;
  final Color? statusColor;

  const UserAvatar({
    super.key,
    this.name,
    this.imageUrl,
    this.size = 40,
    this.showStatus = false,
    this.status,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = _getInitial();

    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getAvatarColor(colorScheme),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _buildInitial(initial, colorScheme),
                  errorWidget: (_, __, ___) =>
                      _buildInitial(initial, colorScheme),
                )
              : _buildInitial(initial, colorScheme),
        ),
        if (showStatus && status != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getStatusColor(colorScheme),
                border: Border.all(
                  color: colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getInitial() {
    if (name == null || name!.isEmpty) return '?';
    return name![0].toUpperCase();
  }

  Color _getAvatarColor(ColorScheme colorScheme) {
    if (name == null || name!.isEmpty) {
      return colorScheme.primaryContainer;
    }
    final colors = [
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
      colorScheme.tertiaryContainer,
      colorScheme.errorContainer,
    ];
    final index = name!.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  Color _getStatusColor(ColorScheme colorScheme) {
    if (statusColor != null) return statusColor!;
    switch (status) {
      case 'online':
        return const Color(0xFF10B981);
      case 'busy':
        return const Color(0xFFF59E0B);
      case 'offline':
        return const Color(0xFF9CA3AF);
      default:
        return colorScheme.outline;
    }
  }

  Widget _buildInitial(String initial, ColorScheme colorScheme) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
