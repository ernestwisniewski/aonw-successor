import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../design_system/assets/sprite_animation_adjustments.dart';
import '../../design_system/assets/sprite_frame_id.dart';
import '../../design_system/assets/sprite_frame_repository.dart';
import '../../design_system/assets/sprite_frames.dart';
import '../../features/map/read_model/player_map_view.dart';
import 'map_sprite_catalog.dart';

enum MapUnitSpriteAction { idle, walk, work, attack, die }

/// Owns unit poses, direction and authored frame geometry.
final class MapUnitSpriteAnimation {
  MapUnitSpriteAnimation({
    required VisibleUnitKind kind,
    required this.onLoaded,
    double Function()? idlePauseDuration,
  }) : _kind = kind,
       _idlePauseDuration = idlePauseDuration ?? math.Random().nextDouble;

  final void Function() onLoaded;
  final double Function() _idlePauseDuration;
  VisibleUnitKind _kind;
  var _framesScope = SpriteFrames.createScope();
  final _frames = <MapUnitSpriteAction, List<SpriteFrame>>{};
  final _pending = <MapUnitSpriteAction, Future<void>>{};
  var _adjustments = SpriteAnimationAdjustments.empty;
  var _generation = 0;
  var _disposed = false;
  var _action = MapUnitSpriteAction.idle;
  var _index = 0;
  var _elapsed = 0.0;
  var _mirrored = false;
  var _idlePausesEnabled = true;
  var _idlePauseRemaining = 0.0;
  SpriteFrame? _geometryFrame;
  ui.Rect? _geometryDestination;
  SpriteFrameGeometry? _geometry;

  MapUnitSpriteAction get action => _action;
  bool get mirrored => _mirrored;
  int get index => _index;
  double get frameDelay => _idlePauseRemaining + frameDuration - _elapsed;

  void setIdlePausesEnabled(bool enabled) {
    _idlePausesEnabled = enabled;
    if (!enabled) _idlePauseRemaining = 0;
  }

  SpriteSequenceId get _sequence => _sequenceFor(_action);
  SpriteFrame? get frame => _frames[_action]?[_index];
  double get frameDuration =>
      _adjustments.frameDuration(_sequence, switch (_action) {
        MapUnitSpriteAction.idle => 0.9,
        MapUnitSpriteAction.walk => 0.14,
        MapUnitSpriteAction.work => 0.22,
        MapUnitSpriteAction.attack => 0.13,
        MapUnitSpriteAction.die => 0.18,
      });

  Future<void> load() async {
    await Future.wait([
      _loadAction(MapUnitSpriteAction.idle),
      _loadAction(MapUnitSpriteAction.walk),
      if (_supportsWork) _loadAction(MapUnitSpriteAction.work),
      if (!_supportsWork) _loadAction(MapUnitSpriteAction.attack),
      _loadAction(MapUnitSpriteAction.die),
    ]);
  }

  void setKind(VisibleUnitKind kind) {
    if (_kind == kind || _disposed) return;
    _generation++;
    _kind = kind;
    _frames.clear();
    _geometryFrame = null;
    _pending.clear();
    _framesScope.dispose();
    _framesScope = SpriteFrames.createScope();
    _action = MapUnitSpriteAction.idle;
    _index = 0;
    _elapsed = 0;
    _idlePauseRemaining = 0;
    _mirrored = false;
    unawaited(load());
  }

  void playIdle() => _play(MapUnitSpriteAction.idle);

  void playWork() => _play(
    _supportsWork ? MapUnitSpriteAction.work : MapUnitSpriteAction.idle,
  );

  bool get _supportsWork => switch (_kind) {
    VisibleUnitKind.settler ||
    VisibleUnitKind.worker ||
    VisibleUnitKind.merchant => true,
    _ => false,
  };

  void playAttack() => _play(
    _supportsWork ? MapUnitSpriteAction.idle : MapUnitSpriteAction.attack,
  );

  void playAttackToward(ui.Offset from, ui.Offset to) {
    _faceToward(from, to);
    playAttack();
  }

  void playDie() => _play(MapUnitSpriteAction.die);

  void playWalkToward(ui.Offset from, ui.Offset to) {
    _faceToward(from, to);
    _play(MapUnitSpriteAction.walk);
  }

  void _faceToward(ui.Offset from, ui.Offset to) {
    final dx = to.dx - from.dx;
    if (dx.abs() > 0.001) _mirrored = dx < 0;
  }

  void _play(MapUnitSpriteAction action) {
    if (_disposed || _action == action) return;
    _action = action;
    _index = 0;
    _elapsed = 0;
    _idlePauseRemaining = 0;
    unawaited(_loadAction(action));
  }

  void advance(double dt) {
    if (_disposed || !dt.isFinite || dt <= 0) return;
    if (_action == MapUnitSpriteAction.idle && _idlePausesEnabled) {
      _advanceIdle(dt);
      return;
    }
    _elapsed += dt;
    final count = (_elapsed / frameDuration).floor();
    _elapsed -= count * frameDuration;
    final next = _index + count;
    _index =
        _action == MapUnitSpriteAction.attack ||
            _action == MapUnitSpriteAction.die
        ? math.min(next, MapSpriteCatalog.unitFrameCount - 1)
        : next % MapSpriteCatalog.unitFrameCount;
  }

  void _advanceIdle(double dt) {
    final activeTime = dt - _idlePauseRemaining;
    _idlePauseRemaining = math.max(0, -activeTime);
    if (activeTime <= 0) return;
    _elapsed += activeTime;
    final count = (_elapsed / frameDuration).floor();
    if (_index + count < MapSpriteCatalog.unitFrameCount) {
      _index += count;
      _elapsed -= count * frameDuration;
      return;
    }
    _index = 0;
    _elapsed = 0;
    final pause = _idlePauseDuration();
    _idlePauseRemaining = pause.isFinite ? pause.clamp(0, 1) : 0;
  }

  void paint(ui.Canvas canvas, ui.Rect destination, {ui.Paint? paint}) {
    final current = frame;
    if (current == null) return;
    final geometry = _geometryFor(current, destination);
    if (geometry.source.isEmpty || geometry.destination.isEmpty) return;
    canvas.save();
    if (_mirrored) {
      canvas
        ..translate(destination.left + destination.right, 0)
        ..scale(-1, 1);
    }
    canvas
      ..clipRect(destination)
      ..drawImageRect(
        current.image,
        geometry.source,
        geometry.destination,
        paint ?? _paint,
      )
      ..restore();
  }

  double? statusTopOffset(ui.Size size) {
    final current = frame;
    if (current == null) return null;
    final metrics = MapSpriteCatalog.unitMetrics(_kind);
    final offset = _adjustments
        .forFrame(_sequence, _index)
        .scaledOffset(ui.Size(metrics.width, metrics.height), size);
    return offset.dy +
        current.statusTop / current.originalSize.height * size.height;
  }

  SpriteFrameGeometry _geometryFor(SpriteFrame current, ui.Rect destination) {
    if (identical(_geometryFrame, current) &&
        _geometryDestination == destination) {
      return _geometry!;
    }
    _geometryFrame = current;
    _geometryDestination = destination;
    final metrics = MapSpriteCatalog.unitMetrics(_kind);
    return _geometry = _adjustments
        .forFrame(_sequence, _index)
        .geometryFor(
          current,
          baseSize: ui.Size(metrics.width, metrics.height),
          destination: destination,
        );
  }

  Future<void> _loadAction(MapUnitSpriteAction action) {
    if (_disposed || _frames.containsKey(action)) return Future.value();
    return _pending[action] ??= _readAction(action);
  }

  Future<void> _readAction(MapUnitSpriteAction action) async {
    final generation = _generation;
    final sequence = _sequenceFor(action);
    try {
      final frames = await Future.wait([
        for (var index = 0; index < MapSpriteCatalog.unitFrameCount; index++)
          _framesScope.load(sequence.frame(index)),
      ]);
      final adjustments = await SpriteAnimationAdjustments.load();
      if (_disposed || generation != _generation) return;
      _adjustments = adjustments;
      _frames[action] = List.unmodifiable(frames);
      if (_action == action) onLoaded();
    } on Object {
      // The unit's vector marker remains available if its atlas cannot load.
    } finally {
      if (generation == _generation) _pending.remove(action);
    }
  }

  SpriteSequenceId _sequenceFor(MapUnitSpriteAction action) =>
      SpriteSequenceId('unit.${_kind.name}.${action.name}');

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _frames.clear();
    _geometryFrame = null;
    _pending.clear();
    _framesScope.dispose();
  }

  static final _paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
}
