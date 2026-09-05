part of 'map_effect_host.dart';

extension _ObservedEffectSequence on MapEffectHostComponent {
  void _replaceObservedSequence(
    FlameScenePatch patch,
    MapStaticRenderCache cache,
  ) {
    _observedCache = cache;
    _observedRevision = patch.snapshot.player.stamp.revision;
    _observedSequenceActive = true;
    final transitions = <FlameCommandTransition>[
      ...patch.movements,
      ...patch.combats,
    ]..sort((left, right) => left.eventIndex.compareTo(right.eventIndex));
    _observedTransitions.addAll(transitions);
    _startNextObservedEffect();
  }

  void _startNextObservedEffect() {
    final cache = _observedCache;
    if (cache == null) return;
    while (_observedTransitions.isNotEmpty && !_hasActiveVisualEffects) {
      final transition = _observedTransitions.removeFirst();
      onObservedEvent?.call(transition.eventIndex);
      switch (transition) {
        case final FlameUnitMovementTransition movement:
          _startMovement(movement, cache);
        case final FlameCombatTransition combat:
          _startCombat(_availableCombatEffect()!, combat, cache);
      }
    }
    if (_observedTransitions.isEmpty && !_hasActiveVisualEffects) {
      if (_observedSequenceActive) onObservedEvent?.call(null);
      _observedSequenceActive = false;
      _observedCache = null;
    }
  }

  void _finishPendingObservedMovements() {
    final cache = _observedCache;
    if (cache != null) {
      for (final movement
          in _observedTransitions.whereType<FlameUnitMovementTransition>()) {
        _units
            .componentForUnit(movement.unitId)
            ?.finishMovement(
              movement.to,
              _units.settledCenterFor(cache, movement.unitId, movement.to),
            );
        _completedMovementCount += 1;
        _preparedMovements.remove(movement)?.release();
      }
    }
    _observedTransitions.clear();
    _observedSequenceActive = false;
    _observedCache = null;
  }
}
