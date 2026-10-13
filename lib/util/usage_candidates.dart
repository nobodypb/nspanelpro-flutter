import '../config/dashboard.dart';
import 'usage_history.dart';

class UsageCandidate {
  const UsageCandidate(
    this.entity,
    this.card,
    this.config,
    this.page, {
    this.item,
  });
  final String entity;
  final String card;
  final CardConfig config;
  final int page;
  final CardConfig? item;
  String get domain => entity.split('.').first;
}

List<UsageCandidate> usageCandidates(List<PanelPage> pages) {
  final result = <UsageCandidate>[];
  void walk(CardConfig config, int page) {
    final type = cardType(config);
    if (const {'vertical-stack', 'horizontal-stack', 'grid'}.contains(type)) {
      for (final child in config.maps('cards')) {
        walk(child, page);
      }
      return;
    }
    if (!UsageHistory.cardTypes.contains(type)) return;
    if (type == 'nspanel-switch-card') {
      final items = <CardConfig>[];
      if (config.maps('groups').isNotEmpty) {
        for (final group in config.maps('groups')) {
          items.addAll(group.maps('switches'));
        }
      } else if (config['switches'] is List &&
          config.listOr('switches').isNotEmpty) {
        for (final raw in config.listOr('switches').take(6)) {
          if (raw is String) items.add({'entity': raw});
          if (raw is Map) items.add(raw.cast<String, dynamic>());
        }
      } else if (config.str('entity') != null) {
        items.add(config);
      }
      for (final item in items) {
        final entity = item.str('entity');
        if (entity != null && UsageHistory.eligible(entity)) {
          result.add(UsageCandidate(entity, type, config, page, item: item));
        }
      }
    } else {
      final entity = config.str('entity');
      if (entity != null && UsageHistory.eligible(entity)) {
        result.add(UsageCandidate(entity, type, config, page));
      }
    }
  }

  for (var page = 0; page < pages.length; page++) {
    for (final card in pages[page].cards) {
      walk(card, page);
    }
  }
  return result;
}

List<UsageCandidate> recommendedCandidates({
  required List<UsageCandidate> candidates,
  required Map<String, int> counts,
  required int recommendationPage,
  required int count,
  Set<String> domains = const {},
}) {
  final excluded = {
    for (final candidate in candidates)
      if (candidate.page == recommendationPage) candidate.entity,
  };
  final unique = <String, UsageCandidate>{};
  for (final candidate in candidates) {
    if (candidate.page == recommendationPage ||
        excluded.contains(candidate.entity) ||
        (domains.isNotEmpty && !domains.contains(candidate.domain)) ||
        !counts.containsKey(candidate.entity)) {
      continue;
    }
    unique.putIfAbsent(candidate.entity, () => candidate);
  }
  final ranked = unique.values.toList()
    ..sort((a, b) {
      final byUse = counts[b.entity]!.compareTo(counts[a.entity]!);
      return byUse != 0 ? byUse : a.entity.compareTo(b.entity);
    });
  return ranked.take(count.clamp(1, 6)).toList();
}
