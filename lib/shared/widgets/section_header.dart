import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import 'mini_chip.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.chip,
    this.trailing,
  });

  final String title;
  final String? chip;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (chip != null) ...[const SizedBox(width: 10), MiniChip(chip!)],
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}
