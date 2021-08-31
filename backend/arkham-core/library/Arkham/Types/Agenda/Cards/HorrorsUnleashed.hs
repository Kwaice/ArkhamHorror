module Arkham.Types.Agenda.Cards.HorrorsUnleashed
  ( HorrorsUnleashed(..)
  , horrorsUnleashed
  ) where

import Arkham.Prelude

import qualified Arkham.Agenda.Cards as Cards
import Arkham.Types.Ability
import Arkham.Types.Agenda.Attrs
import Arkham.Types.Agenda.Runner
import Arkham.Types.Classes
import Arkham.Types.EnemyId
import Arkham.Types.Game.Helpers
import Arkham.Types.GameValue
import Arkham.Types.Matcher hiding (ChosenRandomLocation)
import Arkham.Types.Message
import Arkham.Types.Modifier
import Arkham.Types.Phase
import Arkham.Types.Resolution
import Arkham.Types.Target
import qualified Arkham.Types.Timing as Timing
import Arkham.Types.Trait

newtype HorrorsUnleashed = HorrorsUnleashed AgendaAttrs
  deriving anyclass IsAgenda
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

horrorsUnleashed :: AgendaCard HorrorsUnleashed
horrorsUnleashed =
  agenda (3, A) HorrorsUnleashed Cards.horrorsUnleashed (Static 7)

instance HasAbilities env HorrorsUnleashed where
  getAbilities _ _ (HorrorsUnleashed x) = pure
    [mkAbility x 1 $ ForcedAbility $ PhaseEnds Timing.When $ PhaseIs EnemyPhase]

instance HasSet Trait env EnemyId => HasModifiersFor env HorrorsUnleashed where
  getModifiersFor _ (EnemyTarget eid) (HorrorsUnleashed attrs) = do
    isAbomination <- member Abomination <$> getSet eid
    if isAbomination
      then pure $ toModifiers attrs [EnemyFight 1, EnemyEvade 1]
      else pure []
  getModifiersFor _ _ _ = pure []

instance AgendaRunner env => RunMessage env HorrorsUnleashed where
  runMessage msg a@(HorrorsUnleashed attrs) = case msg of
    UseCardAbility _ source _ 1 _ | isSource attrs source -> do
      leadInvestigatorId <- getLeadInvestigatorId
      broodOfYogSothoth <- map EnemyTarget
        <$> getSetList (EnemyWithTitle "Brood of Yog-Sothoth")
      a <$ when
        (notNull broodOfYogSothoth)
        (push $ chooseOneAtATime
          leadInvestigatorId
          [ TargetLabel target [ChooseRandomLocation target mempty]
          | target <- broodOfYogSothoth
          ]
        )
    ChosenRandomLocation target@(EnemyTarget _) lid ->
      a <$ push (MoveToward target (LocationWithId lid))
    AdvanceAgenda aid | aid == agendaId attrs && onSide B attrs ->
      a <$ push (ScenarioResolution $ Resolution 1)
    _ -> HorrorsUnleashed <$> runMessage msg attrs
