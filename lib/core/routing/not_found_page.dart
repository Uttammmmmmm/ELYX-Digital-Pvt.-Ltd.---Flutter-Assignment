library;

import 'package:flutter/material.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({required this.routeName, super.key});

  final String? routeName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      key: const Key('not_found_page'),
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.wrong_location_outlined,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                "That screen doesn't exist",
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                routeName == null ? 'Unknown route.' : 'Route: $routeName',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).popUntil((Route<dynamic> r) => r.isFirst),
                child: const Text('Back to users'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
