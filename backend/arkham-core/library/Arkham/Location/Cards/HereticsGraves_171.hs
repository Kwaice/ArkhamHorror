module Arkham.Location.Cards.HereticsGraves_171 (
  hereticsGraves_171,
  HereticsGraves_171 (..),
)
where

import Arkham.Prelude

import Arkham.GameValue
import Arkham.Location.Cards qualified as Cards
import Arkham.Location.Runner

newtype HereticsGraves_171 = HereticsGraves_171 LocationAttrs
  deriving anyclass (IsLocation, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

hereticsGraves_171 :: LocationCard HereticsGraves_171
hereticsGraves_171 = location HereticsGraves_171 Cards.hereticsGraves_171 7 (Static 0)

instance HasAbilities HereticsGraves_171 where
  getAbilities (HereticsGraves_171 attrs) =
    getAbilities attrs

-- withRevealedAbilities attrs []

instance RunMessage HereticsGraves_171 where
  runMessage msg (HereticsGraves_171 attrs) =
    HereticsGraves_171 <$> runMessage msg attrs
