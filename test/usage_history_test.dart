import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/config/dashboard.dart';
import 'package:nspanel_app/util/usage_candidates.dart';
import 'package:nspanel_app/util/usage_history.dart';

void main() {
  test('one original gesture is one bounded event with diagnostic context', () {
    var now = 1800000000000;
    final history = UsageHistory(now: () => now);
    final event = history.record('light.desk', 'nspanel-light-card', 2, 'tap');
    expect(event, isNotNull);
    expect(event!.domain, 'light');
    expect(event.result, 'pending');
    history.complete(event, false);
    expect(event.result, 'failure');
    expect(history.counts(), {'light.desk': 1});
    expect(
      history.record('scene.dinner', 'nspanel-light-card', 2, 'tap'),
      isNull,
    );
    expect(
      history.record('light.desk', 'nspanel-light-card', -1, 'tap'),
      isNull,
    );
    expect(jsonDecode(history.encode())['events'][0], containsPair('page', 2));
    now += UsageHistory.windowMs;
    expect(history.counts(), isEmpty);
  });

  test('restore validates records, retains an interaction made during load, and caps events', () {
    const now = 1800000000000;
    final history = UsageHistory(now: () => now);
    history.record(
      'cover.before_load',
      'nspanel-cover-card',
      4,
      'hold',
      result: 'detail',
    );
    final sample = UsageEvent(
      at: now - 1000,
      entity: 'light.desk',
      card: 'nspanel-light-card',
      page: 2,
      gesture: 'tap',
      result: 'success',
    ).toJson();
    final expired = {...sample, 'at': now - UsageHistory.windowMs};
    history.restore(
      jsonEncode({
        'version': 1,
        'events': [
          for (var i = 0; i < UsageHistory.maxEvents + 1; i++)
            {...sample, 'at': now - 20000 + i},
          expired,
          {'at': now, 'entity': 'scene.invalid'},
        ],
      }),
    );
    expect(history.events.length, UsageHistory.maxEvents);
    expect(history.events.last.entity, 'cover.before_load');
    expect(history.counts().containsKey('scene.invalid'), false);
    history.reset();
    expect(history.events, isEmpty);
  });

  test('recommendations exclude the card page and filter only the display', () {
    final pages = [
      PanelPage([
        {'type': 'custom:nspanel-light-card', 'entity': 'light.alpha'},
      ]),
      PanelPage([
        {
          'type': 'custom:nspanel-switch-card',
          'switches': [
            {'entity': 'switch.zeta'},
            {'entity': 'switch.beta'},
          ],
        },
      ]),
      PanelPage([
        {'type': 'custom:nspanel-light-card', 'entity': 'light.alpha'},
        {'type': 'custom:nspanel-frequent-card', 'count': 3},
      ]),
    ];
    final candidates = usageCandidates(pages);
    final counts = {'light.alpha': 10, 'switch.zeta': 2, 'switch.beta': 2};
    expect(
      recommendedCandidates(
        candidates: candidates,
        counts: counts,
        recommendationPage: 2,
        count: 3,
      ).map((c) => c.entity),
      ['switch.beta', 'switch.zeta'],
    );
    expect(
      recommendedCandidates(
        candidates: candidates,
        counts: counts,
        recommendationPage: 2,
        count: 3,
        domains: {'light'},
      ),
      isEmpty,
    );
    expect(
      recommendedCandidates(
        candidates: candidates,
        counts: counts,
        recommendationPage: 1,
        count: 3,
      ).map((c) => c.entity),
      ['light.alpha'],
    );
  });

  test('serialized history stays within its byte limit', () {
    const now = 1800000000000;
    final history = UsageHistory(now: () => now);
    final large = UsageEvent(
      at: now,
      entity: 'light.${'x' * 220}',
      card: 'nspanel-light-card',
      page: 1,
      gesture: 'tap',
      result: 'success',
    ).toJson();
    history.restore(
      jsonEncode({
        'version': 1,
        'events': [
          for (var i = 0; i < 9000; i++) {...large, 'at': now - 9000 + i},
        ],
      }),
    );
    expect(
      utf8.encode(history.encode()).length,
      lessThanOrEqualTo(UsageHistory.maxBytes),
    );
    expect(history.events.length, lessThan(9000));
  });
}
