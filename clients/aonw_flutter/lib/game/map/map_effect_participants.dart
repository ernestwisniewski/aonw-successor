part of 'map_effect_host.dart';

extension MapEffectParticipants on MapEffectHostComponent {
  /// Reserve existing markers before the authoritative patch removes them.
  void preparePatch(FlameScenePatch patch) {
    if (patch.hasOrderedEffects ||
        (_observedRevision != null &&
            _observedRevision != patch.snapshot.player.stamp.revision)) {
      skipAll();
      _observedRevision = null;
    }
    final changedIds = {
      ...patch.removedUnitIds,
      for (final unit in patch.unitUpserts) unit.id,
    };
    for (final effect in _combatPool) {
      if (effect.revision != patch.snapshot.player.stamp.revision &&
          (effect.markers?.involves(changedIds) ?? false)) {
        effect.markers?.complete();
        effect.markers = null;
      }
    }
    if (!_staticCombat) {
      for (final combat in patch.combats) {
        _preparedCombats[combat] = MapUnitCombatPresentation(_units, combat);
      }
    }
    _retainMovementParticipants(patch);
  }

  void _retainIntroducedParticipants(FlameScenePatch patch) {
    for (final combat in _preparedCombats.values) {
      combat.retainAvailableParticipants();
    }
    _retainMovementParticipants(patch);
  }

  void _retainMovementParticipants(FlameScenePatch patch) {
    for (final movement in patch.movements) {
      if (_preparedMovements.containsKey(movement)) continue;
      final lease = _units.retainForPresentation(movement.unitId);
      if (lease != null) _preparedMovements[movement] = lease;
    }
  }

  void _startCombat(
    _ActiveCombatIntent effect,
    FlameCombatTransition combat,
    MapStaticRenderCache cache,
  ) {
    final participants = {combat.attackerUnitId, ?combat.defenderUnitId};
    for (final previous in _combatPool) {
      if (previous.markers?.involves(participants) ?? false) {
        previous.markers?.complete();
        previous.markers = null;
      }
    }
    effect.start(
      combat,
      cache,
      reducedMotion: _staticCombat,
      participants: _preparedCombats.remove(combat),
    );
  }

  void _releaseUnstartedParticipants(FlameScenePatch patch) {
    for (final combat in patch.combats) {
      _preparedCombats.remove(combat)?.complete();
    }
    for (final movement in patch.movements) {
      _preparedMovements.remove(movement)?.release();
    }
  }

  void _releasePreparedCombats() {
    for (final combat in _preparedCombats.values) {
      combat.complete();
    }
    _preparedCombats.clear();
  }

  void _releasePreparedParticipants() {
    _releasePreparedCombats();
    for (final lease in _preparedMovements.values) {
      lease.release();
    }
    _preparedMovements.clear();
  }
}
