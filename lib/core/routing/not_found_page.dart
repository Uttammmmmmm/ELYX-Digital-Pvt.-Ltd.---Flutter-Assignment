/// Fallback for an unknown or malformed route.
library;

import 'package:flutter/material.dart';

/// Shown when a route name is unrecognised, or its arguments are the wrong
/// type.
///
/// Exists so a routing mistake degrades to a screen the user can back out of
/// rather than an exception. A thrown route error in release is a crash; this
/// is a dead end with an exit.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({required this.routeName, super.key});

  /// The route that could not be resolved, echoed for debugging.
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
              Icon(Icons.wrong_location_outlined,
                  size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text("That screen doesn't exist",
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                routeName == null ? 'Unknown route.' : 'Route: $routeName',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context)
                    .popUntil((Route<dynamic> r) => r.isFirst),
                child: const Text('Back to users'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
