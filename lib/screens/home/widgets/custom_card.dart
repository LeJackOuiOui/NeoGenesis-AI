import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final Widget subtitle;
  final Widget? trailing;

  const CustomCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: leading,
        title: Text(title),
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }
}
