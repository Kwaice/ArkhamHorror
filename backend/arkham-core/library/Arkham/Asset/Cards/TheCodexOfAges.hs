module Arkham.Asset.Cards.TheCodexOfAges (
  theCodexOfAges,
  TheCodexOfAges (..),
) where

import Arkham.Prelude

import Arkham.Ability
import Arkham.Asset.Cards qualified as Cards
import Arkham.Asset.Runner
import Arkham.ChaosToken
import Arkham.Matcher
import Arkham.SkillType
import Arkham.Timing qualified as Timing
import Arkham.Window qualified as Window

newtype TheCodexOfAges = TheCodexOfAges AssetAttrs
  deriving anyclass (IsAsset)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity, NoThunks)

theCodexOfAges :: AssetCard TheCodexOfAges
theCodexOfAges = asset TheCodexOfAges Cards.theCodexOfAges

instance HasModifiersFor TheCodexOfAges where
  getModifiersFor (InvestigatorTarget iid) (TheCodexOfAges a) | controlledBy a iid = do
    pure $ toModifiers a [SkillModifier SkillWillpower 1 | notNull (assetSealedChaosTokens a)]
  getModifiersFor _ _ = pure []

instance HasAbilities TheCodexOfAges where
  getAbilities (TheCodexOfAges a) =
    [ restrictedAbility a 1 ControlsThis
        $ ReactionAbility (WouldRevealChaosToken Timing.When You) Free
    ]

instance RunMessage TheCodexOfAges where
  runMessage msg a@(TheCodexOfAges attrs) = case msg of
    UseCardAbility iid source 1 _ _ | isSource attrs source -> do
      let mElderSignToken = find ((== ElderSign) . chaosTokenFace) (assetSealedChaosTokens attrs)
      case mElderSignToken of
        Nothing -> error "impossible"
        Just token -> do
          -- TODO: Try to batch this
          -- This is sort of a pain because we need to replace revealing a
          -- token which means we have to cancel a bunch of steps. It is
          -- possible this won't work well if the elder sign effect is
          -- something other than pass skill test
          -- A solution might be to make the skill test more of a state machine
          -- that tracks the current step, but we may need to synchronize with
          -- the chaos bag
          let
            removeWindow window = case Window.windowType window of
              Window.WouldRevealChaosToken {} -> True
              _ -> False
          popMessageMatching_ $ \case
            RunWindow _ windows' -> any removeWindow windows'
            _ -> False
          popMessageMatching_ $ \case
            EndCheckWindow -> True
            _ -> False
          popMessageMatching_ $ \case
            NextChaosBagStep {} -> True
            _ -> False
          popMessageMatching_ $ \case
            RunBag {} -> True
            _ -> False
          popMessageMatching_ $ \case
            RunSkillTest {} -> True
            _ -> False
          pushAll
            [Will (ResolveChaosToken token ElderSign iid), toDiscardBy iid (toAbilitySource attrs 1) attrs]
          pure a
    _ -> TheCodexOfAges <$> runMessage msg attrs
