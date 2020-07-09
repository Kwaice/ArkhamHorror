{-# LANGUAGE NamedFieldPuns #-}
module Arkham.Internal.Scenario
  ( toInternalScenario
  , drawCard
  )
where

import Arkham.Constructors
import Arkham.Entity.ArkhamGame
import Arkham.Internal.Act
import Arkham.Internal.ChaosToken
import Arkham.Internal.EncounterCard
import Arkham.Internal.Location
import Arkham.Internal.Types
import Arkham.Types
import Arkham.Types.Act
import Arkham.Types.Card
import Arkham.Types.ChaosToken
import Arkham.Types.Difficulty
import Arkham.Types.Enemy
import Arkham.Types.GameState
import Arkham.Types.Location
import Arkham.Types.Player
import Arkham.Types.Scenario
import Arkham.Types.Trait
import Base.Lock
import ClassyPrelude
import Control.Monad.Random
import qualified Data.HashMap.Strict as HashMap
import qualified Data.HashSet as HashSet
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NE
import Lens.Micro
import Lens.Micro.Platform ()
import Safe hiding (at)

locationEnemies :: HasEnemies a => a -> ArkhamLocation -> [ArkhamEnemy]
locationEnemies g l = map
  (fromJustNote "could not lookup enemy" . flip HashMap.lookup (g ^. enemies))
  (HashSet.toList $ l ^. enemyIds)

countTraitMatch :: HasTraits a => ArkhamTrait -> [a] -> Int
countTraitMatch trait' cards' =
  length . filter (trait' `elem`) $ cards' ^.. each . traits

toInternalScenario :: ArkhamGame -> ArkhamScenarioInternal
toInternalScenario g =
  fromJustNote "missing scenario"
    $ HashMap.lookup (asScenarioCode scenario') allScenarios
    <*> pure difficulty'
 where
  scenario' = g ^. scenario
  difficulty' = g ^. difficulty

allScenarios
  :: HashMap ArkhamScenarioCode (ArkhamDifficulty -> ArkhamScenarioInternal)
allScenarios =
  HashMap.fromList [(ArkhamScenarioCode "theGathering", theGathering)]

defaultTokenMap :: HashMap ArkhamChaosToken ArkhamChaosTokenInternal
defaultTokenMap = HashMap.fromList
  [ (PlusOne, plusOneToken)
  , (Zero, zeroToken)
  , (MinusOne, minusOneToken)
  , (MinusTwo, minusTwoToken)
  , (MinusThree, minusThreeToken)
  , (MinusFour, minusFourToken)
  , (MinusFive, minusFiveToken)
  , (MinusSix, minusSixToken)
  , (MinusSeven, minusSevenToken)
  , (MinusEight, minusEightToken)
  , (AutoFail, autoFailToken)
  , (ElderSign, elderSignToken)
  ]

buildTokenMapFrom
  :: HashMap ArkhamChaosToken ArkhamChaosTokenInternal
  -> HashMap ArkhamChaosToken ArkhamChaosTokenInternal
buildTokenMapFrom scenarioTokens = HashMap.union scenarioTokens defaultTokenMap

drawCard :: ArkhamPlayer -> ArkhamPlayer
drawCard p =
  let (drawn, deck') = splitAt 1 (p ^. deck)
  in p & hand %~ (++ drawn) & deck .~ deck'

defaultUpdateObjectives
  :: MonadIO m => Lockable ArkhamGame -> m (Lockable ArkhamGame)
defaultUpdateObjectives = runIgnoreLockedM $ \g ->
  let
    actCard = fromJustNote "Could not find Act" (g ^? topActCardLens)
    ArkhamActInternal { actCanProgress } = toInternalAct actCard
    actCard' = actCard
      { aactCanProgress = actCanProgress (g ^. currentData . gameState)
      }
  in pure $ g & topActCardLens .~ actCard'
  where topActCardLens = stacks . ix "Act" . _ActStack . _TopOfStack

defaultResolveAttacksOfOpportunity
  :: MonadIO m => Lockable ArkhamGame -> m (Lockable ArkhamGame)
defaultResolveAttacksOfOpportunity =
  runOnlyLockedWithLockM ResolveAttacksOfOpportunity
    $ \g currentLock@(_ :| remainingLocks) -> do
        let
          ArkhamGameStateStepAttackOfOpportunityStep step@ArkhamAttackOfOpportunityStep {..}
            = g ^. gameStateStep
          enemies' =
            HashMap.filter ((`elem` aoosEnemyIds) . _enemyId) (g ^. enemies)
          enemyIds' = HashMap.keysSet
            $ HashMap.filter (not . _enemyFinishedAttacking) enemies'
          lockConstructor = maybe Unlocked Locked (NE.nonEmpty remainingLocks)
        if null enemyIds'
          then
            pure
            . lockConstructor
            $ g
            & (lock .~ NE.nonEmpty remainingLocks)
            & (gameStateStep .~ aoosNextStateStep)
            & (enemies . mapped . finishedAttacking .~ False)
          else
            pure
            . addLock currentLock
            $ g
            & (gameStateStep .~ ArkhamGameStateStepAttackOfOpportunityStep
                (step { aoosEnemyIds = enemyIds' })
              )

defaultUpdateAccessibleLocationsOnPlayers
  :: MonadIO m => Lockable ArkhamGame -> m (Lockable ArkhamGame)
defaultUpdateAccessibleLocationsOnPlayers = runIgnoreLockedM
  $ \g -> pure $ g & players . mapped %~ updateAccessibleLocations g

updateAccessibleLocations :: ArkhamGame -> ArkhamPlayer -> ArkhamPlayer
updateAccessibleLocations g p = p
  { _accessibleLocations = map alCardCode accessibleLocations
  }
 where
  scenario' = toInternalScenario g
  investigatorLocationId =
    alCardCode $ locationFor p (g ^. currentData . gameState)
  accessibleLocationIds =
    scenarioLocationGraph scenario' g investigatorLocationId
  currentLocations = HashMap.elems (g ^. locations)
  accessibleLocations =
    filter
        (\l -> aliCanEnter (toLocationInternal l) (g ^. currentData . gameState)
        )
      $ filter ((`elem` accessibleLocationIds) . alCardCode) currentLocations

defaultMythosPhase :: ArkhamMythosPhaseInternal
defaultMythosPhase = ArkhamMythosPhaseInternal
  { mythosPhaseOnEnter = pure
  , mythosPhaseAddDoom = runLockedM AddDoom
    $ \g -> pure . Unlocked $ g & stacks . at "Agenda" . _Just . doom +~ 1
  , mythosPhaseCheckAdvance = pure
  , mythosPhaseDrawEncounter = runLockedM DrawEncounter $ \g -> do
    let (card : deck') = g ^. encounterDeck
    Unlocked
      <$> (g & encounterDeck .~ deck' & traverseOf
            (currentData . gameState)
            (aeiResolve (toInternalEncounterCard card) (g ^. activePlayer))
          )
  , mythosPhaseOnExit = pure
  }

defaultInvestigationPhase :: ArkhamInvestigationPhaseInternal
defaultInvestigationPhase = ArkhamInvestigationPhaseInternal
  { investigationPhaseOnEnter = runOnlyUnlockedM $ \g ->
    pure
      . Unlocked
      $ g
      & gameStateStep
      .~ ArkhamGameStateStepInvestigatorActionStep
  , investigationPhaseTakeActions = runLockedM InvestigationTakeActions $ \g ->
    if and (g ^.. players . each . endedTurn)
      then pure $ Unlocked g
      else pure $ addLock (pure InvestigationTakeActions) g
  , investigationPhaseOnExit = pure
  }

defaultEnemyPhase :: ArkhamEnemyPhaseInternal
defaultEnemyPhase = ArkhamEnemyPhaseInternal
  { enemyPhaseOnEnter = pure
  , enemyPhaseResolveHunters = pure
  , enemyPhaseResolveEnemies = runLockedM ResolveEnemies $ \g -> do
    let
      enemyIds' = HashMap.keysSet
        $ HashMap.filter (not . _enemyFinishedAttacking) (g ^. enemies)
    if null enemyIds'
      then pure . Unlocked $ g
      else
        pure
        . addLock (pure ResolveEnemies)
        $ g
        & (gameStateStep .~ resolveEnemies enemyIds')
  , enemyPhaseOnExit = runOnlyUnlockedM
    (pure . Unlocked . (enemies . mapped . finishedAttacking .~ False))
  }
 where
  resolveEnemies =
    ArkhamGameStateStepResolveEnemiesStep . ArkhamResolveEnemiesStep

defaultUpkeepPhase :: ArkhamUpkeepPhaseInternal
defaultUpkeepPhase = ArkhamUpkeepPhaseInternal
  { upkeepPhaseOnEnter = pure
  , upkeepPhaseResetActions = runLockedM UpkeepResetActions $ \g ->
    pure
      . Unlocked
      $ g
      & (players . each . actions .~ 3)
      & (players . each . endedTurn .~ False)
  , upkeepPhaseReadyExhausted = pure
  , upkeepPhaseDrawCardsAndGainResources =
    runLockedM DrawAndGainResources $ \g ->
      pure
        . Unlocked
        $ g
        & (players . mapped %~ drawCard)
        & (players . each . resources +~ 1)
  , upkeepPhaseCheckHandSize = pure
  , upkeepPhaseOnExit = pure
  }

defaultScenarioRun :: MonadIO m => ArkhamGame -> m ArkhamGame
defaultScenarioRun g = do
  result <- firstPass
  if isLocked result
    then pure (withoutLock result)
    else withoutLock <$> go result
 where
  firstPass = go (buildLock g)
  scenario' = toInternalScenario g
  ArkhamMythosPhaseInternal {..} = scenarioMythosPhase scenario'
  ArkhamInvestigationPhaseInternal {..} = scenarioInvestigationPhase scenario'
  ArkhamEnemyPhaseInternal {..} = scenarioEnemyPhase scenario'
  ArkhamUpkeepPhaseInternal {..} = scenarioUpkeepPhase scenario'
  go =
    scenarioUpdateObjectives scenario'
      >=> scenarioUpdateAccessibleLocationsOnPlayers scenario'
      >=> scenarioResolveAttacksOfOpportunity scenario'
      >=> mythosPhaseOnEnter
      >=> mythosPhaseAddDoom
      >=> mythosPhaseCheckAdvance
      >=> mythosPhaseDrawEncounter
      >=> mythosPhaseOnExit
      >=> investigationPhaseOnEnter
      >=> investigationPhaseTakeActions
      >=> investigationPhaseOnExit
      >=> enemyPhaseOnEnter
      >=> enemyPhaseResolveHunters
      >=> enemyPhaseResolveEnemies
      >=> enemyPhaseOnExit
      >=> upkeepPhaseOnEnter
      >=> upkeepPhaseResetActions
      >=> upkeepPhaseReadyExhausted
      >=> upkeepPhaseDrawCardsAndGainResources
      >=> upkeepPhaseCheckHandSize
      >=> upkeepPhaseOnExit

-- TODO: validate card code
defaultScenarioFindAct :: ArkhamCardCode -> ArkhamGame -> ArkhamAct
defaultScenarioFindAct code' game' =
  fromJustNote ("Could not find act in scenario with id " <> tcode)
    $ game'
    ^? stacks
    . ix "Act"
    . _ActStack
    . _TopOfStack
  where tcode = unpack $ unArkhamCardCode code'

defaultLocationGraph :: ArkhamGame -> ArkhamCardCode -> [ArkhamCardCode]
defaultLocationGraph g k =
  [ alCardCode l
  | l <- HashMap.elems (g ^. locations)
  , maybe False (`elem` connectedLocationSymbols) (alLocationSymbol l)
  ]
 where
  connectedLocationSymbols =
    maybe [] alConnectedLocationSymbols (g ^. locations . at k)


defaultScenario :: Text -> ArkhamScenarioInternal
defaultScenario name = ArkhamScenarioInternal
  { scenarioName = name
  , scenarioSetup = error "you must set the setup step for scenarios"
  , scenarioUpdateObjectives = defaultUpdateObjectives
  , scenarioUpdateAccessibleLocationsOnPlayers =
    defaultUpdateAccessibleLocationsOnPlayers
  , scenarioResolveAttacksOfOpportunity = defaultResolveAttacksOfOpportunity
  , scenarioMythosPhase = defaultMythosPhase
  , scenarioInvestigationPhase = defaultInvestigationPhase
  , scenarioEnemyPhase = defaultEnemyPhase
  , scenarioUpkeepPhase = defaultUpkeepPhase
  , scenarioRun = defaultScenarioRun
  , scenarioFindAct = defaultScenarioFindAct
  , scenarioTokenMap = buildTokenMapFrom mempty
  , scenarioLocationGraph = defaultLocationGraph
  }

theGathering :: ArkhamDifficulty -> ArkhamScenarioInternal
theGathering difficulty' = (defaultScenario "TheGathering")
  { scenarioSetup = theGatheringSetup
  , scenarioTokenMap = buildTokenMapFrom $ HashMap.fromList
    [ (Skull, theGatheringSkullToken difficulty')
    , (Cultist, theGatheringCultistToken difficulty')
    , (Tablet, theGatheringTabletToken difficulty')
    ]
  }

isEasyStandard :: ArkhamDifficulty -> Bool
isEasyStandard difficulty' =
  difficulty' == ArkhamEasy || difficulty' == ArkhamStandard

reveal :: ArkhamGameState -> ArkhamLocation -> ArkhamLocation
reveal g l = aliOnReveal (toLocationInternal l) g l

theGatheringSetup :: MonadRandom m => ArkhamGameState -> m ArkhamGameState
theGatheringSetup game = do
  agenda <- theGatheringAgenda
  act <- theGatheringAct
  let stacks' = HashMap.fromList [("Agenda", agenda), ("Act", act)]
  pure $ game & locations .~ locations' & stacks .~ stacks'
 where
  investigators' = HashMap.keysSet (agsPlayers game)
  locations' = HashMap.fromList
    [(alCardCode study, reveal game $ study & investigators .~ investigators')]

theGatheringAgenda :: MonadRandom m => m ArkhamStack
theGatheringAgenda = pure $ AgendaStack $ NE.fromList
  [ ArkhamAgenda "01105" "https://arkhamdb.com/bundles/cards/01105.jpg" 0
  , ArkhamAgenda "01106" "https://arkhamdb.com/bundles/cards/01106.jpg" 0
  , ArkhamAgenda "01107" "https://arkhamdb.com/bundles/cards/01107.jpg" 0
  ]

theGatheringAct :: MonadRandom m => m ArkhamStack
theGatheringAct = pure $ ActStack $ NE.fromList
  [ ArkhamAct "01108" "https://arkhamdb.com/bundles/cards/01108.jpg" False
  , ArkhamAct "01109" "https://arkhamdb.com/bundles/cards/01109.jpg" False
  , ArkhamAct "01110" "https://arkhamdb.com/bundles/cards/01110.jpg" False
  ]

unrevealedLocation :: ArkhamLocation
unrevealedLocation = ArkhamLocation
  { alName = error "Missing location name"
  , alCardCode = error "Missing card code"
  , alLocationSymbol = Nothing
  , alConnectedLocationSymbols = []
  , alShroud = 0
  , alImage = error "Missing card image"
  , alInvestigators = mempty
  , alEnemies = mempty
  , alClues = 0
  , alDoom = 0
  , alStatus = Unrevealed
  }

study :: ArkhamLocation
study = unrevealedLocation
  { alName = "Study"
  , alCardCode = "01111"
  , alLocationSymbol = Just Circle
  , alShroud = 2
  , alImage = "https://arkhamdb.com/bundles/cards/01111.png"
  }

theGatheringSkullToken :: ArkhamDifficulty -> ArkhamChaosTokenInternal
theGatheringSkullToken difficulty' = if isEasyStandard difficulty'
  then (token Skull)
    { tokenToResult = \g p ->
      Modifier . countTraitMatch Ghoul . locationEnemies g $ locationFor p g
    }
  else (token Skull)
    { tokenToResult = modifier (-2)
    , tokenOnFail = \_ _ -> error "TODO: Draw a ghoul"
    }

theGatheringCultistToken :: ArkhamDifficulty -> ArkhamChaosTokenInternal
theGatheringCultistToken difficulty' = if isEasyStandard difficulty'
  then (token Cultist)
    { tokenToResult = modifier (-1)
    , tokenOnFail = \g _ -> g & activePlayer . sanityDamage +~ 1
    }
  else (token Cultist)
    { tokenOnReveal = \_ _ -> error "TODO: Reveal another"
    , tokenOnFail = \g _ -> g & activePlayer . sanityDamage +~ 2
    }

theGatheringTabletToken :: ArkhamDifficulty -> ArkhamChaosTokenInternal
theGatheringTabletToken difficulty' = if isEasyStandard difficulty'
  then (token Tablet)
    { tokenToResult = modifier (-2)
    , tokenOnReveal = \g p ->
      if countTraitMatch Ghoul (locationEnemies g (locationFor p g)) > 0
        then g & activePlayer . healthDamage +~ 1
        else g
    }
  else (token Tablet)
    { tokenToResult = modifier (-4)
    , tokenOnReveal = \g p ->
      if countTraitMatch Ghoul (locationEnemies g (locationFor p g)) > 0
        then
          g
          & activePlayer
          . healthDamage
          +~ 1
          & activePlayer
          . sanityDamage
          +~ 1
        else g
    }
