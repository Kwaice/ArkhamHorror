module Arkham.Enemy.Cards.HuntingHorror (huntingHorror, HuntingHorror (..)) where

import Arkham.Ability
import Arkham.ChaosBag.RevealStrategy
import Arkham.ChaosToken
import Arkham.Classes
import Arkham.Enemy.Cards qualified as Cards
import Arkham.Enemy.Runner
import Arkham.Matcher
import Arkham.Placement
import Arkham.Prelude
import Arkham.RequestedChaosTokenStrategy
import Arkham.Token
import Arkham.Token qualified as Token

newtype HuntingHorror = HuntingHorror EnemyAttrs
  deriving anyclass (IsEnemy, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

huntingHorror :: EnemyCard HuntingHorror
huntingHorror = enemy HuntingHorror Cards.huntingHorror (2, Static 3, 2) (1, 1)

instance HasAbilities HuntingHorror where
  getAbilities (HuntingHorror x) =
    extend
      x
      [ restrictedAbility x 1 (criteria <> exhaustedCriteria) $ forced $ PhaseBegins #when #enemy
      , restrictedAbility x 2 criteria $ forced $ EnemyLeavesPlay #when (be x)
      ]
   where
    exhaustedCriteria = if x.ready then Never else NoRestriction
    criteria = case x.placement of
      OutOfPlay VoidZone -> Never
      _ -> NoRestriction

instance RunMessage HuntingHorror where
  runMessage msg e@(HuntingHorror attrs@EnemyAttrs {..}) = case msg of
    UseThisAbility _ (isSource attrs -> True) 1 -> do
      push $ RequestChaosTokens (toAbilitySource attrs 1) Nothing (Reveal 1) SetAside
      pure e
    RequestedChaosTokens (isSource attrs -> True) _ (map chaosTokenFace -> tokens) -> do
      push $ ResetChaosTokens (toSource attrs)
      pushWhen (any (`elem` tokens) [#skull, #cultist, #tablet, #elderthing, #autofail])
        $ Ready (toTarget attrs)
      pure e
    UseThisAbility _ (isSource attrs -> True) 2 -> do
      push $ PlaceEnemyOutOfPlay VoidZone enemyId
      pure e
    EnemySpawnFromOutOfPlay VoidZone _miid _lid eid | eid == enemyId -> do
      pure
        . HuntingHorror
        $ attrs
        & (tokensL %~ removeAllTokens Doom . removeAllTokens Clue . removeAllTokens Token.Damage)
        & (defeatedL .~ False)
        & (exhaustedL .~ False)
    PlaceEnemyOutOfPlay VoidZone eid | eid == enemyId -> do
      withQueue_ $ mapMaybe (filterOutEnemyMessages eid)
      pure
        . HuntingHorror
        $ attrs
        & (tokensL %~ removeAllTokens Doom . removeAllTokens Clue . removeAllTokens Token.Damage)
        & (placementL .~ OutOfPlay VoidZone)
        & (defeatedL .~ False)
        & (exhaustedL .~ False)
    _ -> HuntingHorror <$> runMessage msg attrs
