import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../../design_system/aonw_tokens.dart';
import '../../features/map/read_model/map_view.dart';
import '../presentation/flame_scene_patch.dart';
import 'gameplay_map_layers.dart';
import 'map_combat_feedback.dart';
import 'map_interaction_geometry.dart';
import 'map_movement_presentation.dart';
import 'map_unit_combat_presentation.dart';
import 'static_map_layers.dart';

part 'map_combat_intent.dart';
part 'map_observed_effect_sequence.dart';
part 'map_effect_participants.dart';
part 'map_unit_movement_intent.dart';

typedef MapEffectActivitySink = void Function(bool active);

final class MapEffectHostComponent extends Component {
  MapEffectHostComponent({required MapUnitLayerComponent units})
    : _units = units,
      super(priority: 70);

  static const _movementDurationSeconds = 0.6;
  static const _combatDurationSeconds = 1.28;
  static const _maximumCombatEffects = 4;

  final MapUnitLayerComponent _units;
  final _movements = <String, _ActiveUnitMovement>{};
  final _preparedCombats = <FlameCombatTransition, MapUnitCombatPresentation>{};
  final _preparedMovements =
      <FlameUnitMovementTransition, MapUnitPresentationLease>{};
  final _observedTransitions = Queue<FlameCommandTransition>();
  MapStaticRenderCache? _observedCache;
  int? _observedRevision;
  bool _observedSequenceActive = false;
  void Function(int? eventIndex)? onObservedEvent;
  final _combatPool = List.generate(
    _maximumCombatEffects,
    (_) => _ActiveCombatIntent(),
  );
  MapEffectActivitySink? onActivityChanged;
  MapMovementPresentation? Function(
    FlameUnitMovementTransition movement,
    MapUnitComponent unit,
  )?
  onMovementStart;
  var _reducedMotion = false;
  var _movementAnimationsEnabled = true;
  var _combatAnimationsEnabled = true;

  bool get movementAnimationsEnabled => _movementAnimationsEnabled;
  bool get combatAnimationsEnabled => _combatAnimationsEnabled;
  bool get _staticCombat => _reducedMotion || !_combatAnimationsEnabled;
  var _playbackSpeed = 1.0;
  var _activeUpdateCount = 0;
  var _completedMovementCount = 0;

  @visibleForTesting
  int get debugActiveEffectCount =>
      _movements.length + debugActiveCombatEffectCount;

  @visibleForTesting
  int get debugActiveCombatEffectCount =>
      _combatPool.where((effect) => effect.active).length;

  @visibleForTesting
  int get debugActiveDamageLabelCount => _combatPool.fold(
    0,
    (count, effect) =>
        count +
        (effect.active && effect.elapsed < 1.08
            ? effect.feedback.labelCount
            : 0),
  );

  @visibleForTesting
  int get debugActiveParticleCount => _combatPool.fold(
    0,
    (count, effect) =>
        count +
        (effect.active
            ? effect.feedback.activeParticleCount(effect.elapsed)
            : 0),
  );

  @visibleForTesting
  int get debugMaximumCombatEffectCount => _maximumCombatEffects;

  @visibleForTesting
  ({ui.Offset attacker, ui.Offset defender})? get debugCombatEndpoints {
    for (final effect in _combatPool) {
      if (effect.active) {
        return (
          attacker: effect.attackerCenter,
          defender: effect.defenderCenter,
        );
      }
    }
    return null;
  }

  @visibleForTesting
  double? get debugCombatPulse {
    for (final effect in _combatPool) {
      if (effect.active) return effect.pulse;
    }
    return null;
  }

  @visibleForTesting
  int get debugActiveUpdateCount => _activeUpdateCount;

  @visibleForTesting
  int get debugCompletedMovementCount => _completedMovementCount;

  @visibleForTesting
  double get debugPlaybackSpeed => _playbackSpeed;

  @visibleForTesting
  bool get debugReducedMotion => _reducedMotion;

  @visibleForTesting
  int get debugPendingCommandEffectCount => _observedTransitions.length;

  void applyPatch(FlameScenePatch patch, MapStaticRenderCache cache) {
    _retainIntroducedParticipants(patch);
    if (patch.hasOrderedEffects) {
      _replaceObservedSequence(patch, cache);
      _notifyActivity();
      return;
    }
    _discardInterruptedMovements(patch);
    _startMovements(patch, cache);
    _startCombats(patch, cache);
    _releaseUnstartedParticipants(patch);
    _notifyActivity();
  }

  void _startCombats(FlameScenePatch patch, MapStaticRenderCache cache) {
    for (final combat in patch.combats) {
      final effect = _availableCombatEffect();
      if (effect == null) return;
      _startCombat(effect, combat, cache);
    }
  }

  _ActiveCombatIntent? _availableCombatEffect() {
    for (final effect in _combatPool) {
      if (!effect.active) return effect;
    }
    return null;
  }

  void setReducedMotion(bool enabled) {
    if (_reducedMotion == enabled) return;
    _reducedMotion = enabled;
    if (enabled) _releasePreparedCombats();
    for (final combat in _combatPool) {
      combat.setReducedMotion(_staticCombat);
    }
    if (enabled) {
      _finishMovements();
      _startNextObservedEffect();
    }
    _notifyActivity();
  }

  void setMovementAnimations(bool enabled) {
    if (_movementAnimationsEnabled == enabled) return;
    _movementAnimationsEnabled = enabled;
    if (!enabled) {
      _finishMovements();
      _startNextObservedEffect();
    }
    _notifyActivity();
  }

  void setCombatAnimations(bool enabled) {
    if (_combatAnimationsEnabled == enabled) return;
    _combatAnimationsEnabled = enabled;
    if (!enabled) _releasePreparedCombats();
    for (final combat in _combatPool) {
      combat.setReducedMotion(_staticCombat);
    }
  }

  void setPlaybackSpeed(double speed) {
    if (!speed.isFinite || speed <= 0) {
      throw ArgumentError.value(speed, 'speed', 'must be finite and positive');
    }
    _playbackSpeed = speed;
  }

  void skipAll() {
    _finishMovements();
    _clearCombatEffects();
    _finishPendingObservedMovements();
    _releasePreparedParticipants();
    _notifyActivity();
  }

  void clearEffects() {
    _finishMovements();
    _finishPendingObservedMovements();
    _observedRevision = null;
    _clearCombatEffects(dispose: true);
    _releasePreparedParticipants();
    _notifyActivity();
  }

  void _clearCombatEffects({bool dispose = false}) {
    for (final combat in _combatPool) {
      combat.complete();
      if (dispose) combat.feedback.dispose();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_hasActiveEffects) return;
    _activeUpdateCount += 1;
    final movementCompleted = _updateMovements(dt);
    final combatCompleted = _updateCombats(dt);
    if (movementCompleted || combatCompleted) {
      _startNextObservedEffect();
      _notifyActivity();
    }
  }

  bool _updateCombats(double dt) {
    var completed = false;
    for (final combat in _combatPool) {
      if (!combat.active) continue;
      combat.elapsed += dt * _playbackSpeed;
      combat.markers?.advance(dt * _playbackSpeed);
      if (combat.elapsed >= _combatDurationSeconds) {
        combat.complete();
        completed = true;
      }
    }
    return completed;
  }

  @override
  void render(ui.Canvas canvas) {
    for (final combat in _combatPool) {
      if (!combat.active) continue;
      combat.render(canvas);
    }
  }

  bool get _hasActiveEffects =>
      _observedTransitions.isNotEmpty || _hasActiveVisualEffects;

  bool get _hasActiveVisualEffects =>
      _movements.isNotEmpty || _combatPool.any((effect) => effect.active);

  void _notifyActivity() => onActivityChanged?.call(_hasActiveEffects);
}
