module Arkham.Types.Location.Cards.CongregationalChurch_208
  ( congregationalChurch_208
  , CongregationalChurch_208(..)
  ) where

import Arkham.Prelude

import qualified Arkham.Location.Cards as Cards (congregationalChurch_208)
import Arkham.Types.Ability
import Arkham.Types.Card
import Arkham.Types.Classes
import Arkham.Types.GameValue
import Arkham.Types.Location.Attrs
import Arkham.Types.Matcher
import Arkham.Types.Message hiding (RevealLocation)
import qualified Arkham.Types.Timing as Timing
import Arkham.Types.Trait

newtype CongregationalChurch_208 = CongregationalChurch_208 LocationAttrs
  deriving anyclass (IsLocation, HasModifiersFor env)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

congregationalChurch_208 :: LocationCard CongregationalChurch_208
congregationalChurch_208 = location
  CongregationalChurch_208
  Cards.congregationalChurch_208
  1
  (PerPlayer 1)
  Diamond
  [Plus, Triangle, Squiggle]

instance HasAbilities env CongregationalChurch_208 where
  getAbilities iid window (CongregationalChurch_208 attrs) = do
    rest <- withDrawCardUnderneathAction iid window attrs
    pure
      $ [ mkAbility attrs 1
          $ ForcedAbility
          $ RevealLocation Timing.After Anyone
          $ LocationWithId
          $ toId attrs
        | locationRevealed attrs
        ]
      <> rest

instance LocationRunner env => RunMessage env CongregationalChurch_208 where
  runMessage msg l@(CongregationalChurch_208 attrs) = case msg of
    UseCardAbility iid source _ 1 _ | isSource attrs source -> do
      l <$ push
        (FindEncounterCard iid (toTarget attrs)
        $ CardWithType EnemyType
        <> CardWithTrait Humanoid
        )
    FoundEncounterCard _iid target card | isTarget attrs target -> do
      villageCommonsId <- fromJustNote "missing village commons"
        <$> getId (LocationWithTitle "Village Commons")
      l <$ push (SpawnEnemyAt (EncounterCard card) villageCommonsId)
    _ -> CongregationalChurch_208 <$> runMessage msg attrs
