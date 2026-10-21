import 'package:flutter/material.dart';
import 'package:haoka_app/widgets/app_surface.dart';

/// 表单里可点击的选择项（地区、商家等）。
class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.value,
    this.subtitle,
    this.prefix,
  });

  final String label;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  final String? value;
  final String? subtitle;
  final Widget? prefix;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return Material(
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: AppStyle.softInput(
            labelText: label,
            prefixIcon: prefix == null
                ? Icon(icon)
                : SizedBox(width: 48, height: 48, child: Center(child: prefix)),
            suffixIcon: const Icon(
              Icons.keyboard_arrow_down,
              color: AppStyle.chevron,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasValue ? value! : hint,
                style: TextStyle(
                  fontSize: 16,
                  color: hasValue ? AppStyle.title : AppStyle.subtitle,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppStyle.subtitle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
