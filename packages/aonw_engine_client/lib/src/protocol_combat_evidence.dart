part of 'protocol_evidence.dart';

final class AonwCombatEvidence extends AonwClientEvidence {
  const AonwCombatEvidence({required this.execution});

  factory AonwCombatEvidence.fromJson(Map<String, Object?> value) {
    requireKeys(value, const {'type', 'execution'}, 'combat evidence');
    return AonwCombatEvidence(
      execution: AonwCombatExecution.fromJson(value['execution']),
    );
  }

  final AonwCombatExecution execution;
}

final class AonwCombatExecution {
  const AonwCombatExecution({
    required this.seed,
    required this.rolls,
    required this.preview,
    required this.outcome,
  });

  factory AonwCombatExecution.fromJson(Object? source) {
    final value = readObject(source, 'combat execution');
    requireKeys(value, const {
      'seed',
      'rolls',
      'preview',
      'outcome',
    }, 'combat execution');
    return AonwCombatExecution(
      seed: readUnsigned(value['seed'], 'combat seed'),
      rolls: readList(
        value['rolls'],
        'combat rolls',
        (item, _) => AonwCombatRoll.fromJson(item),
      ),
      preview: AonwCombatPreview.fromJson(value['preview']),
      outcome: AonwCombatOutcome.fromJson(value['outcome']),
    );
  }

  final int seed;

  /// The outgoing roll, followed by a retaliation roll when it was performed.
  final List<AonwCombatRoll> rolls;

  bool get defenderRetaliated => switch (rolls.length) {
    1 => false,
    2 => true,
    _ => throw const FormatException('Invalid combat roll count.'),
  };
  final AonwCombatPreview preview;
  final AonwCombatOutcome outcome;
}

final class AonwCombatRoll {
  const AonwCombatRoll({required this.value});

  factory AonwCombatRoll.fromJson(Object? source) {
    final value = readObject(source, 'combat roll');
    requireKeys(value, const {'value'}, 'combat roll');
    return AonwCombatRoll(value: readInt(value['value'], 'combat roll value'));
  }

  final int value;
}

sealed class AonwCombatTarget {
  const AonwCombatTarget();

  factory AonwCombatTarget.fromJson(Object? source) {
    final value = readObject(source, 'combat target');
    return switch (readString(value['type'], 'combat target type')) {
      'unit' => AonwUnitCombatTarget.fromJson(value),
      'city' => AonwCityCombatTarget.fromJson(value),
      _ => throw const FormatException('Unknown AoNW combat target.'),
    };
  }
}

final class AonwUnitCombatTarget extends AonwCombatTarget {
  const AonwUnitCombatTarget({required this.unitId});

  factory AonwUnitCombatTarget.fromJson(Map<String, Object?> value) {
    requireKeys(value, const {'type', 'unitId'}, 'unit combat target');
    return AonwUnitCombatTarget(
      unitId: readString(value['unitId'], 'combat target unit id'),
    );
  }

  final String unitId;
}

final class AonwCityCombatTarget extends AonwCombatTarget {
  const AonwCityCombatTarget({required this.cityId});

  factory AonwCityCombatTarget.fromJson(Map<String, Object?> value) {
    requireKeys(value, const {'type', 'cityId'}, 'city combat target');
    return AonwCityCombatTarget(
      cityId: readString(value['cityId'], 'combat target city id'),
    );
  }

  final String cityId;
}

enum AonwCombatStatTarget {
  attack,
  defense,
  hitPoints;

  factory AonwCombatStatTarget.fromJson(Object? source) =>
      _enum(source, values, 'combat stat target');
}

enum AonwCombatModifierKind {
  terrain,
  fortification,
  technology,
  counter,
  troopComposition,
  veterancy;

  factory AonwCombatModifierKind.fromJson(Object? source) =>
      _enum(source, values, 'combat modifier kind');
}

final class AonwCombatModifier {
  const AonwCombatModifier({
    required this.kind,
    required this.label,
    required this.target,
    required this.delta,
  });

  factory AonwCombatModifier.fromJson(Object? source) {
    final value = readObject(source, 'combat modifier');
    requireKeys(value, const {
      'kind',
      'label',
      'target',
      'delta',
    }, 'combat modifier');
    return AonwCombatModifier(
      kind: AonwCombatModifierKind.fromJson(value['kind']),
      label: readString(value['label'], 'combat modifier label'),
      target: AonwCombatStatTarget.fromJson(value['target']),
      delta: readInt(value['delta'], 'combat modifier delta'),
    );
  }

  final AonwCombatModifierKind kind;
  final String label;
  final AonwCombatStatTarget target;
  final int delta;
}

final class AonwCombatStats {
  const AonwCombatStats({
    required this.attack,
    required this.defense,
    required this.hitPoints,
    required this.range,
    required this.mobility,
    required this.modifiers,
  });

  factory AonwCombatStats.fromJson(Object? source) {
    final value = readObject(source, 'combat stats');
    requireKeys(value, const {
      'attack',
      'defense',
      'hitPoints',
      'range',
      'mobility',
      'modifiers',
    }, 'combat stats');
    return AonwCombatStats(
      attack: readInt(value['attack'], 'combat attack'),
      defense: readInt(value['defense'], 'combat defense'),
      hitPoints: readUnsigned(value['hitPoints'], 'combat hit points'),
      range: readUnsigned(value['range'], 'combat range'),
      mobility: readUnsigned(value['mobility'], 'combat mobility'),
      modifiers: readList(
        value['modifiers'],
        'combat modifiers',
        (item, _) => AonwCombatModifier.fromJson(item),
      ),
    );
  }

  final int attack;
  final int defense;
  final int hitPoints;
  final int range;
  final int mobility;
  final List<AonwCombatModifier> modifiers;
}

final class AonwCombatPreview {
  const AonwCombatPreview({
    required this.attackerUnitId,
    required this.target,
    required this.distance,
    required this.attacker,
    required this.defender,
    required this.outgoingDamageMin,
    required this.outgoingDamageMax,
    required this.retaliationDamageMin,
    required this.retaliationDamageMax,
  });

  factory AonwCombatPreview.fromJson(Object? source) {
    final value = readObject(source, 'combat preview');
    requireKeys(value, const {
      'attackerUnitId',
      'target',
      'distance',
      'attacker',
      'defender',
      'outgoingDamageMin',
      'outgoingDamageMax',
      'retaliationDamageMin',
      'retaliationDamageMax',
    }, 'combat preview');
    return AonwCombatPreview(
      attackerUnitId: readString(value['attackerUnitId'], 'attacker unit id'),
      target: AonwCombatTarget.fromJson(value['target']),
      distance: readUnsigned(value['distance'], 'combat distance'),
      attacker: AonwCombatStats.fromJson(value['attacker']),
      defender: AonwCombatStats.fromJson(value['defender']),
      outgoingDamageMin: readUnsigned(
        value['outgoingDamageMin'],
        'minimum outgoing damage',
      ),
      outgoingDamageMax: readUnsigned(
        value['outgoingDamageMax'],
        'maximum outgoing damage',
      ),
      retaliationDamageMin: _nullableUnsigned(
        value['retaliationDamageMin'],
        'minimum retaliation damage',
      ),
      retaliationDamageMax: _nullableUnsigned(
        value['retaliationDamageMax'],
        'maximum retaliation damage',
      ),
    );
  }

  final String attackerUnitId;
  final AonwCombatTarget target;
  final int distance;
  final AonwCombatStats attacker;
  final AonwCombatStats defender;
  final int outgoingDamageMin;
  final int outgoingDamageMax;
  final int? retaliationDamageMin;
  final int? retaliationDamageMax;
}

final class AonwCombatOutcome {
  const AonwCombatOutcome({
    required this.attackerHitPoints,
    required this.defenderHitPoints,
    required this.attackerKilled,
    required this.defenderKilled,
    required this.defenderRetreat,
    required this.outgoingDamage,
    required this.retaliationDamage,
  });

  factory AonwCombatOutcome.fromJson(Object? source) {
    final value = readObject(source, 'combat outcome');
    requireKeys(value, const {
      'attackerHitPoints',
      'defenderHitPoints',
      'attackerKilled',
      'defenderKilled',
      'defenderRetreat',
      'outgoingDamage',
      'retaliationDamage',
    }, 'combat outcome');
    return AonwCombatOutcome(
      attackerHitPoints: readInt(
        value['attackerHitPoints'],
        'attacker hit points',
      ),
      defenderHitPoints: readInt(
        value['defenderHitPoints'],
        'defender hit points',
      ),
      attackerKilled: readBool(value['attackerKilled'], 'attacker killed'),
      defenderKilled: readBool(value['defenderKilled'], 'defender killed'),
      defenderRetreat: value['defenderRetreat'] == null
          ? null
          : AonwCoordinate.fromJson(value['defenderRetreat']),
      outgoingDamage: readUnsigned(value['outgoingDamage'], 'outgoing damage'),
      retaliationDamage: readUnsigned(
        value['retaliationDamage'],
        'retaliation damage',
      ),
    );
  }

  final int attackerHitPoints;
  final int defenderHitPoints;
  final bool attackerKilled;
  final bool defenderKilled;
  final AonwCoordinate? defenderRetreat;
  final int outgoingDamage;
  final int retaliationDamage;
}
