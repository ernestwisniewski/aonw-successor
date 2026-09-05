use aonw_domain::{CityConquestAction, HexCoord, UnitId};

/// Revision-bound attack command.
#[derive(Clone, Copy, Debug)]
pub struct AttackHexCommand<'command> {
    /// Revision observed by the client.
    pub expected_revision: u64,
    /// Controlled attacking unit.
    pub attacker_unit_id: &'command UnitId,
    /// Target coordinate.
    pub defender: HexCoord,
    /// Disposition used when a city is defeated.
    pub city_conquest_action: CityConquestAction,
}

impl<'command> AttackHexCommand<'command> {
    /// Constructs a capture-by-default attack.
    #[must_use]
    pub const fn new(
        expected_revision: u64,
        attacker_unit_id: &'command UnitId,
        defender: HexCoord,
    ) -> Self {
        Self {
            expected_revision,
            attacker_unit_id,
            defender,
            city_conquest_action: CityConquestAction::Capture,
        }
    }

    /// Selects city disposition without changing any other command input.
    #[must_use]
    pub const fn with_city_conquest_action(mut self, action: CityConquestAction) -> Self {
        self.city_conquest_action = action;
        self
    }
}

/// Revision-bound recipient-safe combat preview query.
#[derive(Clone, Copy, Debug)]
pub struct CombatPreviewQuery<'query> {
    /// Revision observed by the client.
    pub expected_revision: u64,
    /// Controlled attacking unit.
    pub attacker_unit_id: &'query UnitId,
    /// Target coordinate.
    pub defender: HexCoord,
}

impl<'query> CombatPreviewQuery<'query> {
    /// Constructs a preview query.
    #[must_use]
    pub const fn new(
        expected_revision: u64,
        attacker_unit_id: &'query UnitId,
        defender: HexCoord,
    ) -> Self {
        Self {
            expected_revision,
            attacker_unit_id,
            defender,
        }
    }
}

/// Canonical combat target identity disclosed only after visibility validation.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum CombatTarget {
    /// A unit occupies the target coordinate.
    Unit(UnitId),
    /// A city occupies the target coordinate.
    City(aonw_domain::CityId),
}

/// Combat statistic affected by one typed modifier.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CombatStatTarget {
    /// Attack strength.
    Attack,
    /// Defense strength.
    Defense,
    /// Maximum hit points.
    HitPoints,
}

/// Source category for an ordered modifier.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CombatModifierKind {
    /// Map terrain.
    Terrain,
    /// Defended city center.
    Fortification,
    /// Unlocked technology.
    Technology,
    /// Unit matchup.
    Counter,
    /// Commander army composition.
    TroopComposition,
    /// Experience rank.
    Veterancy,
}

/// One exact modifier used by preview and resolution.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CombatModifier {
    /// Source category.
    pub kind: CombatModifierKind,
    /// Stable engine-owned label.
    pub label: Box<str>,
    /// Affected statistic.
    pub target: CombatStatTarget,
    /// Signed additive delta.
    pub delta: i32,
}

/// Effective combat statistics after all ordered modifiers.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct EffectiveCombatStats {
    /// Attack strength.
    pub attack: i32,
    /// Defense strength.
    pub defense: i32,
    /// Maximum hit points.
    pub hit_points: u32,
    /// Attack range.
    pub range: u32,
    /// Retreat mobility.
    pub mobility: u32,
    /// Ordered applied modifiers.
    pub modifiers: Box<[CombatModifier]>,
}

/// Recipient-safe deterministic preview without random seed or rolls.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CombatPreview {
    /// Attacking unit.
    pub attacker_unit_id: UnitId,
    /// Visible target identity.
    pub target: CombatTarget,
    /// Hex distance used by range and retaliation rules.
    pub distance: u32,
    /// Effective attacker statistics.
    pub attacker: EffectiveCombatStats,
    /// Effective defender statistics.
    pub defender: EffectiveCombatStats,
    /// Inclusive outgoing damage bounds.
    pub outgoing_damage: (u32, u32),
    /// Inclusive retaliation bounds, or none when retaliation is impossible.
    pub retaliation_damage: Option<(u32, u32)>,
}

/// One exact deterministic random roll.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct CombatRoll {
    /// Signed deterministic roll value.
    pub value: i32,
}

/// Exact resolved combat outcome.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CombatOutcome {
    /// Attacker health after combat.
    pub attacker_hit_points: i32,
    /// Defender health after combat.
    pub defender_hit_points: i32,
    /// Whether the attacker was defeated.
    pub attacker_killed: bool,
    /// Whether the defender was defeated.
    pub defender_killed: bool,
    /// Defender retreat destination when retreat prevented defeat.
    pub defender_retreat: Option<HexCoord>,
    /// Damage dealt to the defender.
    pub outgoing_damage: u32,
    /// Damage dealt by retaliation.
    pub retaliation_damage: u32,
}

/// Exact execution evidence used for animation and replay verification.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CombatExecution {
    /// Initial deterministic seed.
    pub seed: u32,
    /// Outgoing roll, followed by a retaliation roll when it was performed.
    pub rolls: Box<[CombatRoll]>,
    /// Shared preview inputs used by resolution.
    pub preview: CombatPreview,
    /// Exact outcome.
    pub outcome: CombatOutcome,
}
