import 'dart:math' as math;

import '../presentation/flame_command_transition.dart';
import 'static_map_layers.dart';
import 'unit_map_layer.dart';

/// Presents disclosed combat participants independently of snapshot lifetime.
final class MapUnitCombatPresentation {
  MapUnitCombatPresentation(this._units, this.combat) {
    retainAvailableParticipants();
  }

  static const duration = 0.72;
  final MapUnitLayerComponent _units;
  final FlameCombatTransition combat;
  MapUnitPresentationLease? _attacker;
  MapUnitPresentationLease? _defender;
  var _elapsed = 0.0;
  var _started = false;
  var _released = false;

  bool involves(Set<String> unitIds) =>
      unitIds.contains(combat.attackerUnitId) ||
      unitIds.contains(combat.defenderUnitId);

  void retainAvailableParticipants() {
    if (_released) return;
    _attacker ??= _units.retainForPresentation(combat.attackerUnitId);
    _defender ??= _units.retainForPresentation(combat.defenderUnitId);
  }

  void start(MapStaticRenderCache cache) {
    if (_released) return;
    _started = true;
    final attacker = _attacker?.unit;
    final defender = _defender?.unit;
    final attackerCenter = _units.centerFor(cache, combat.attacker);
    final defenderCenter = _units.centerFor(cache, combat.defender);
    attacker?.beginCombat(
      this,
      coordinate: combat.attacker,
      center: attackerCenter,
      toward: defender?.presentationCenterAt(combat.defender, defenderCenter),
      attack: true,
    );
    defender?.beginCombat(
      this,
      coordinate: combat.defender,
      center: defenderCenter,
      toward: attacker?.visualCenter,
      attack: combat.defenderRetaliated,
    );
  }

  void advance(double dt) {
    if (_released || !_started || !dt.isFinite || dt <= 0) return;
    final next = math.min(duration, _elapsed + dt);
    _advancePose(
      _attacker,
      combat.attackerKilled ? duration * 0.72 : null,
      next,
    );
    _advancePose(
      _defender,
      combat.defenderKilled ? duration * 0.48 : null,
      next,
    );
    _elapsed = next;
    if (_elapsed + 1e-9 >= duration) complete();
  }

  void _advancePose(
    MapUnitPresentationLease? lease,
    double? deathAt,
    double next,
  ) {
    final unit = lease?.unit;
    if (unit == null) return;
    if (deathAt != null && _elapsed < deathAt && next >= deathAt) {
      unit.advanceCombat(this, deathAt - _elapsed);
      unit.playCombatDeath(this);
      unit.advanceCombat(this, next - deathAt);
    } else {
      unit.advanceCombat(this, next - _elapsed);
    }
  }

  void complete() {
    if (_released) return;
    _released = true;
    _attacker?.unit.finishCombat(this, killed: combat.attackerKilled);
    _defender?.unit.finishCombat(this, killed: combat.defenderKilled);
    _attacker?.release();
    _defender?.release();
  }
}
