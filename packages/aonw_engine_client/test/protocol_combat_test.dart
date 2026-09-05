import 'dart:convert';

import 'package:aonw_engine_client/aonw_engine_client.dart';
import 'package:test/test.dart';

void main() {
  test('serializes current combat preview and attack requests exactly', () {
    expect(
      _request(
        AonwClientRequest.combatPreview(
          expectedRevision: 9,
          attackerUnitId: 'attacker',
          defenderCol: 2,
          defenderRow: 3,
        ),
      ),
      {
        'type': 'query',
        'query': {
          'type': 'combatPreview',
          'expectedRevision': 9,
          'attackerUnitId': 'attacker',
          'defender': {'col': 2, 'row': 3},
        },
      },
    );
    expect(
      _request(
        AonwClientRequest.attackHex(
          expectedRevision: 9,
          attackerUnitId: 'attacker',
          defenderCol: 2,
          defenderRow: 3,
          cityConquestAction: AonwCityConquestAction.destroy,
        ),
      ),
      {
        'type': 'dispatch',
        'command': {
          'type': 'attackHex',
          'expectedRevision': 9,
          'attackerUnitId': 'attacker',
          'defender': {'col': 2, 'row': 3},
          'cityConquestAction': 'destroy',
        },
      },
    );
  });

  test('parses a complete recipient-safe combat preview strictly', () {
    final response = AonwClientResponse.parse(
      jsonEncode({
        'apiVersion': aonwClientApiVersion,
        'outcome': {
          'status': 'success',
          'response': {
            'type': 'query',
            'result': {
              'type': 'combatPreview',
              'stamp': _stamp,
              'preview': _preview,
            },
          },
        },
      }),
    );
    final result = response.require<AonwQueryResponse>().result;
    expect(result, isA<AonwCombatPreviewResult>());
    final combat = result as AonwCombatPreviewResult;
    expect(combat.preview.attackerUnitId, 'attacker');
    expect(combat.preview.target, isA<AonwUnitCombatTarget>());
    expect(combat.preview.outgoingDamageMin, 2);
    expect(combat.preview.retaliationDamageMax, 3);
    expect(combat.preview.attacker.modifiers.single.delta, 1);
  });

  test('execution distinguishes retaliation from its damage value', () {
    for (final count in [1, 2]) {
      final execution = _execution(count);
      expect(execution.outcome.retaliationDamage, 0);
      expect(execution.defenderRetaliated, count == 2);
    }
  });

  test('ambiguous combat roll counts cannot drive presentation', () {
    for (final count in [0, 3]) {
      expect(() => _execution(count).defenderRetaliated, throwsFormatException);
    }
  });

  test('combat preview rejects unknown or incomplete wire variants', () {
    final unknownTarget = Map<String, Object?>.from(_preview)
      ..['target'] = {'type': 'army', 'unitId': 'defender'};
    expect(
      () => AonwCombatPreview.fromJson(unknownTarget),
      throwsFormatException,
    );

    final incomplete = Map<String, Object?>.from(_preview)
      ..remove('outgoingDamageMax');
    expect(() => AonwCombatPreview.fromJson(incomplete), throwsFormatException);
  });
}

Map<String, Object?> _request(AonwClientRequest request) =>
    (jsonDecode(request.toJson()) as Map<String, Object?>)['request']!
        as Map<String, Object?>;

const _stamp = <String, Object?>{
  'revision': 9,
  'stateDigest':
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  'mapHash': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'rulesetHash':
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
};

const _preview = <String, Object?>{
  'attackerUnitId': 'attacker',
  'target': {'type': 'unit', 'unitId': 'defender'},
  'distance': 1,
  'attacker': {
    'attack': 7,
    'defense': 4,
    'hitPoints': 10,
    'range': 1,
    'mobility': 4,
    'modifiers': [
      {'kind': 'terrain', 'label': 'plains', 'target': 'attack', 'delta': 1},
    ],
  },
  'defender': {
    'attack': 3,
    'defense': 5,
    'hitPoints': 8,
    'range': 1,
    'mobility': 4,
    'modifiers': <Object?>[],
  },
  'outgoingDamageMin': 2,
  'outgoingDamageMax': 5,
  'retaliationDamageMin': 1,
  'retaliationDamageMax': 3,
};

AonwCombatExecution _execution(int rollCount) => AonwCombatExecution(
  seed: 0,
  rolls: [
    for (var index = 0; index < rollCount; index++)
      const AonwCombatRoll(value: 0),
  ],
  preview: AonwCombatPreview.fromJson(_preview),
  outcome: const AonwCombatOutcome(
    attackerHitPoints: 10,
    defenderHitPoints: 10,
    attackerKilled: false,
    defenderKilled: false,
    defenderRetreat: null,
    outgoingDamage: 0,
    retaliationDamage: 0,
  ),
);
