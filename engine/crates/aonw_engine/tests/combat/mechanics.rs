use aonw_domain::{ArtifactId, WorldArtifact, WorldArtifactLocation, WorldArtifactType};

use super::*;

#[test]
fn surviving_units_gain_separate_typed_experience_events() {
    let actor = player("player_1");
    let defender_owner = player("player_2");
    let attacker_id = unit_id("attacker");
    let defender_id = unit_id("defender");
    let state = state(
        vec![
            unit(
                "attacker",
                &actor,
                UnitKind::Warrior,
                HexCoord::new(0, 0),
                None,
            ),
            unit(
                "defender",
                &defender_owner,
                UnitKind::Warrior,
                HexCoord::new(1, 0),
                None,
            ),
        ],
        Vec::new(),
        FogOfWar::default(),
        Diplomacy::default(),
    );
    let map = map();
    let transition = GameEngine::apply_player_owned(
        state,
        EngineContext::canonical(&actor, &map, RulesetDefinition::standard()),
        PlayerCommand::AttackHex(AttackHexCommand::new(11, &attacker_id, HexCoord::new(1, 0))),
    )
    .expect("attack");

    assert_eq!(
        transition
            .state()
            .unit(&attacker_id)
            .expect("attacker")
            .experience_points(),
        1
    );
    assert_eq!(
        transition
            .state()
            .unit(&defender_id)
            .expect("defender")
            .experience_points(),
        1
    );
    let subjects = transition
        .events()
        .iter()
        .filter_map(|event| match event {
            DomainEvent::UnitGainedExperience(value) => value.subject_unit_id(),
            _ => None,
        })
        .collect::<Vec<_>>();
    assert_eq!(subjects, [&attacker_id, &defender_id]);
    let Some(ExecutionEvidence::Combat(execution)) = transition.evidence() else {
        panic!("combat evidence")
    };
    assert_eq!(execution.rolls.len(), 2);
    assert!(execution.outcome.retaliation_damage > 0);
}

#[test]
fn retreat_consumes_defender_movement_without_a_retaliation_roll() {
    let actor = player("player_1");
    let defender_owner = player("player_2");
    let attacker_id = unit_id("archer");
    let defender_id = unit_id("defender");
    let state = state(
        vec![
            unit(
                "archer",
                &actor,
                UnitKind::Archer,
                HexCoord::new(0, 0),
                None,
            ),
            unit(
                "defender",
                &defender_owner,
                UnitKind::Warrior,
                HexCoord::new(1, 0),
                Some(2),
            ),
        ],
        Vec::new(),
        FogOfWar::default(),
        Diplomacy::default(),
    );
    let map = map();
    let transition = GameEngine::apply_player_owned(
        state,
        EngineContext::canonical(&actor, &map, RulesetDefinition::standard()),
        PlayerCommand::AttackHex(AttackHexCommand::new(11, &attacker_id, HexCoord::new(1, 0))),
    )
    .expect("attack");
    let Some(ExecutionEvidence::Combat(execution)) = transition.evidence() else {
        panic!("combat evidence")
    };
    assert!(execution.outcome.defender_retreat.is_some());
    assert_eq!(execution.rolls.len(), 1);
    assert_eq!(
        transition
            .state()
            .unit(&defender_id)
            .expect("retreated defender")
            .movement_units(),
        MovementUnits::ZERO
    );
    assert!(matches!(
        transition.events().get(2),
        Some(DomainEvent::UnitRetreated(_))
    ));
}

#[test]
fn stored_city_artifacts_modify_defense_and_drop_only_on_destruction() {
    let actor = player("player_1");
    let defender_owner = player("player_2");
    let attacker_id = unit_id("tank");
    let city_id = city_id("city");
    let artifact_id = ArtifactId::new("crown").expect("artifact id");
    let artifact = WorldArtifact::new(
        artifact_id.clone(),
        WorldArtifactType::AncientImperialCrown,
        WorldArtifactLocation::Stored(city_id.clone()),
    );
    let base = state_with_artifacts(
        vec![unit(
            "tank",
            &actor,
            UnitKind::Tank,
            HexCoord::new(0, 0),
            None,
        )],
        vec![city("city", &defender_owner, HexCoord::new(1, 0), Some(1))],
        vec![artifact],
    );
    let map = map();
    let context = EngineContext::canonical(&actor, &map, RulesetDefinition::standard());
    let QueryResult::CombatPreview(preview) = GameEngine::query(
        &base,
        context,
        GameQuery::CombatPreview(CombatPreviewQuery::new(
            11,
            &attacker_id,
            HexCoord::new(1, 0),
        )),
    )
    .expect("preview") else {
        panic!("combat preview")
    };
    assert_eq!(preview.defender.defense, 3);
    assert_eq!(preview.defender.hit_points, 17);

    let captured = GameEngine::apply_player_owned(
        base.clone(),
        context,
        PlayerCommand::AttackHex(AttackHexCommand::new(11, &attacker_id, HexCoord::new(1, 0))),
    )
    .expect("capture");
    assert!(matches!(
        captured
            .state()
            .artifacts()
            .iter()
            .find(|value| value.id() == &artifact_id)
            .expect("artifact")
            .location(),
        WorldArtifactLocation::Stored(value) if value == &city_id
    ));

    let destroyed = GameEngine::apply_player_owned(
        base,
        context,
        PlayerCommand::AttackHex(
            AttackHexCommand::new(11, &attacker_id, HexCoord::new(1, 0))
                .with_city_conquest_action(CityConquestAction::Destroy),
        ),
    )
    .expect("destroy");
    assert!(matches!(
        destroyed
            .state()
            .artifacts()
            .iter()
            .find(|value| value.id() == &artifact_id)
            .expect("artifact")
            .location(),
        WorldArtifactLocation::Map(value) if *value == HexCoord::new(1, 0)
    ));
}

#[test]
fn surviving_city_keeps_ownership_and_records_remaining_health() {
    let actor = player("player_1");
    let defender = player("player_2");
    let attacker_id = unit_id("warrior");
    let city_id = city_id("city");
    let state = state(
        vec![unit(
            "warrior",
            &actor,
            UnitKind::Warrior,
            HexCoord::new(0, 0),
            None,
        )],
        vec![city("city", &defender, HexCoord::new(1, 0), None)],
        FogOfWar::default(),
        Diplomacy::default(),
    );
    let map = map();
    let transition = GameEngine::apply_player_owned(
        state,
        EngineContext::canonical(&actor, &map, RulesetDefinition::standard()),
        PlayerCommand::AttackHex(AttackHexCommand::new(11, &attacker_id, HexCoord::new(1, 0))),
    )
    .expect("attack");
    let city = transition.state().city(&city_id).expect("surviving city");
    assert_eq!(city.owner_player_id(), &defender);
    assert!(city.hit_points().is_some_and(|value| value < 16));
    assert!(!transition.events().iter().any(|event| matches!(
        event,
        DomainEvent::CityCaptured(_) | DomainEvent::CityDestroyed(_)
    )));
}

fn state_with_artifacts(
    units: Vec<Unit>,
    cities: Vec<City>,
    artifacts: Vec<WorldArtifact>,
) -> GameState {
    let identity = identity();
    let players = identity
        .participants()
        .iter()
        .map(|participant| participant.id().clone())
        .collect::<Vec<_>>();
    let lifecycle = TurnLifecycle::try_new(
        &identity,
        players
            .iter()
            .cloned()
            .map(|id| (id, PlayerTurnState::Active))
            .collect::<BTreeMap<_, _>>(),
        players,
        [],
        BTreeMap::new(),
        [],
        [],
        None,
    )
    .expect("turn lifecycle");
    GameState::builder(
        StateRevision::new(11),
        7,
        map().bounds(),
        UnitOccupancyPolicy::Exclusive,
        units,
    )
    .with_cities(cities)
    .with_artifacts(artifacts)
    .with_match_lifecycle(MatchLifecycle::new(identity, lifecycle))
    .try_build()
    .expect("state")
}
