part of 'map_effect_host.dart';

final class _ActiveCombatIntent {
  final feedback = MapCombatFeedback();
  MapUnitCombatPresentation? markers;
  int revision = -1;
  var active = false;
  var attackerCenter = ui.Offset.zero;
  var defenderCenter = ui.Offset.zero;
  var attackerPath = ui.Path();
  var defenderPath = ui.Path();
  var reducedMotion = false;
  var elapsed = 0.0;
  final _curve = ui.Path();
  final _dash = ui.Path();
  var _control = ui.Offset.zero;
  final _threadPaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.65
    ..strokeCap = ui.StrokeCap.round
    ..color = AonwColorTokens.danger.withAlpha(238);
  final _dashPaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 2.15
    ..strokeCap = ui.StrokeCap.round
    ..color = AonwColorTokens.textBright;
  final _attackerFillPaint = ui.Paint()..style = ui.PaintingStyle.fill;
  final _attackerBloomPaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeJoin = ui.StrokeJoin.round
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6.4);
  final _defenderGlowPaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeJoin = ui.StrokeJoin.round
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.2);
  final _defenderStrokePaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;

  void start(
    FlameCombatTransition combat,
    MapStaticRenderCache cache, {
    required bool reducedMotion,
    MapUnitCombatPresentation? participants,
  }) {
    markers = participants;
    revision = combat.revision;
    active = true;
    attackerCenter = mapProjectedTopFaceCenter(cache, combat.attacker);
    defenderCenter = mapProjectedTopFaceCenter(cache, combat.defender);
    attackerPath = mapProjectedTopFacePath(cache, combat.attacker, scale: 0.98);
    defenderPath = mapProjectedTopFacePath(cache, combat.defender, scale: 0.98);
    final attacker = cache.projection.hexCenter(combat.attacker);
    final defender = cache.projection.hexCenter(combat.defender);
    feedback.start(
      attacker: ui.Offset(attacker.x, attacker.y),
      defender: ui.Offset(defender.x, defender.y),
      outgoingDamage: combat.outgoingDamage,
      retaliationDamage: combat.retaliationDamage,
      attackerKilled: combat.attackerKilled,
      defenderKilled: combat.defenderKilled,
      defenderIsCity: combat.defenderIsCity,
      seed: combat.revision,
      reducedMotion: reducedMotion,
    );
    setReducedMotion(reducedMotion);
    elapsed = 0;
    markers?.start(cache);
    _rebuildCurve();
  }

  void setReducedMotion(bool enabled) {
    reducedMotion = enabled;
    if (enabled) {
      feedback.clearParticles();
      markers?.complete();
      markers = null;
    }
  }

  void complete() {
    markers?.complete();
    markers = null;
    feedback.clear();
    active = false;
    elapsed = 0;
  }

  double get pulse {
    if (reducedMotion) return 0.55;
    final radians = (elapsed / 0.92) * math.pi * 2;
    return (0.5 + math.sin(radians) * 0.5).clamp(0.0, 1.0);
  }

  void render(ui.Canvas canvas) {
    _rebuildDash();
    canvas
      ..drawPath(_curve, _threadPaint)
      ..drawPath(_dash, _dashPaint);
    _renderAttackerAlert(canvas);
    _renderDefenderAlert(canvas);
    feedback.render(canvas, elapsed, reducedMotion: reducedMotion);
  }

  void _renderAttackerAlert(ui.Canvas canvas) {
    final value = pulse;
    final coreAlpha = reducedMotion ? 60 : (60 + value * 26).round();
    final glowAlpha = reducedMotion ? 60 : (30 + value * 28).round();
    final bounds = attackerPath.getBounds();
    _attackerFillPaint.shader = ui.Gradient.radial(
      attackerCenter,
      math.max(bounds.width, bounds.height) / 2,
      [
        AonwColorTokens.danger.withAlpha(coreAlpha),
        AonwColorTokens.danger.withAlpha(30),
        AonwColorTokens.danger.withAlpha(0),
      ],
      const [0, 0.48, 1],
    );
    _attackerBloomPaint
      ..strokeWidth = _maskWidth(11 + value * 2.8)
      ..color = AonwColorTokens.danger.withAlpha(glowAlpha);
    canvas
      ..save()
      ..clipPath(attackerPath)
      ..drawPath(attackerPath, _attackerFillPaint)
      ..drawPath(attackerPath, _attackerBloomPaint)
      ..restore();
  }

  void _renderDefenderAlert(ui.Canvas canvas) {
    final value = pulse;
    final glowAlpha = reducedMotion ? 90 : (60 + value * 130).round();
    final strokeAlpha = reducedMotion ? 180 : (130 + value * 125).round();
    _defenderGlowPaint
      ..strokeWidth = _maskWidth(6.2 + value * 2)
      ..color = AonwColorTokens.danger.withAlpha(glowAlpha);
    _defenderStrokePaint
      ..strokeWidth = reducedMotion ? 2 : 2.8 + value * 1.15
      ..color = AonwColorTokens.danger.withAlpha(strokeAlpha);
    canvas
      ..drawPath(defenderPath, _defenderGlowPaint)
      ..drawPath(defenderPath, _defenderStrokePaint);
  }

  void _rebuildCurve() {
    final delta = defenderCenter - attackerCenter;
    final distance = delta.distance;
    final bend = math.min(30.0, math.max(8.0, distance * 0.13));
    final perpendicular = distance <= 0.001
        ? const ui.Offset(0, -1)
        : ui.Offset(-delta.dy / distance, delta.dx / distance);
    _control = (attackerCenter + defenderCenter) / 2 + perpendicular * bend;
    _curve
      ..reset()
      ..moveTo(attackerCenter.dx, attackerCenter.dy)
      ..quadraticBezierTo(
        _control.dx,
        _control.dy,
        defenderCenter.dx,
        defenderCenter.dy,
      );
  }

  // Quarter-pixel soft masks keep the GPU cache bounded as the pulse changes.
  double _maskWidth(double width) => (width * 4).round() / 4;

  void _rebuildDash() {
    final progress = reducedMotion ? 0.72 : (elapsed / 0.82) % 1;
    final inverse = 1 - progress;
    final point =
        attackerCenter * (inverse * inverse) +
        _control * (2 * inverse * progress) +
        defenderCenter * (progress * progress);
    final tangent =
        (_control - attackerCenter) * (2 * inverse) +
        (defenderCenter - _control) * (2 * progress);
    final half = tangent.distance <= 0.001
        ? const ui.Offset(5, 0)
        : tangent * (5 / tangent.distance);
    _dash
      ..reset()
      ..moveTo(point.dx - half.dx, point.dy - half.dy)
      ..lineTo(point.dx + half.dx, point.dy + half.dy);
  }
}
