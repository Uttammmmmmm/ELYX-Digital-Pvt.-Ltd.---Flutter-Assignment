/// Loading indicators.
library;

import 'package:flutter/material.dart';

/// A centered progress indicator for full-screen loading.
class AppLoader extends StatelessWidget {
  const AppLoader({this.label, super.key});

  /// Optional caption under the spinner.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          if (label != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(label!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
