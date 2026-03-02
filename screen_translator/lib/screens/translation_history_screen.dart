import 'package:flutter/material.dart';

import '../models/translation_history_entry.dart';
import '../services/database_service.dart';
import '../widgets/translation_history_tile.dart';
import 'translation_detail_screen.dart';

class TranslationHistoryScreen extends StatefulWidget {
  const TranslationHistoryScreen({super.key});

  @override
  State<TranslationHistoryScreen> createState() =>
      _TranslationHistoryScreenState();
}

class _TranslationHistoryScreenState extends State<TranslationHistoryScreen> {
  final List<TranslationHistoryEntry> _entries = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    final entries = await DatabaseService.instance.getTranslationHistory(
      limit: _pageSize,
      offset: 0,
    );

    if (!mounted) return;
    setState(() {
      _entries.clear();
      _entries.addAll(entries);
      _hasMore = entries.length == _pageSize;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;

    final entries = await DatabaseService.instance.getTranslationHistory(
      limit: _pageSize,
      offset: _entries.length,
    );

    if (!mounted) {
      _isLoadingMore = false;
      return;
    }
    setState(() {
      _entries.addAll(entries);
      _hasMore = entries.length == _pageSize;
      _isLoadingMore = false;
    });
  }

  Future<void> _deleteEntry(int index) async {
    final entry = _entries[index];
    if (entry.id == null) return;

    await DatabaseService.instance.deleteTranslation(entry.id!);
    if (!mounted) return;
    setState(() => _entries.removeAt(index));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('履歴を削除しました')),
    );
  }

  void _openDetail(TranslationHistoryEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TranslationDetailScreen(entry: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '翻訳履歴がありません',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '翻訳タブで画像を選択して翻訳すると\nここに履歴が表示されます',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.separated(
        itemCount: _entries.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _entries.length) {
            // Load more trigger
            _loadMore();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final entry = _entries[index];
          return TranslationHistoryTile(
            entry: entry,
            onTap: () => _openDetail(entry),
            onDismissed: () => _deleteEntry(index),
          );
        },
      ),
    );
  }
}
