import 'package:flutter/material.dart';

import '../models/app_analysis_result.dart';
import '../services/database_service.dart';
import '../widgets/restriction_card.dart';

/// Screen listing all detected AI-service restrictions.
class RestrictionListScreen extends StatefulWidget {
  const RestrictionListScreen({super.key});

  @override
  State<RestrictionListScreen> createState() => _RestrictionListScreenState();
}

class _RestrictionListScreenState extends State<RestrictionListScreen> {
  List<RestrictionInfo> _restrictions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final restrictions =
        await DatabaseService.instance.getAllRestrictions(limit: 50);
    setState(() {
      _restrictions = restrictions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('AI制限履歴')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _restrictions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_off,
                          size: 64,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text(
                        '制限履歴がありません',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AIサービスのスクリーンショットを解析すると\n制限情報がここに表示されます',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _restrictions.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child:
                            RestrictionCard(restriction: _restrictions[index]),
                      );
                    },
                  ),
                ),
    );
  }
}
