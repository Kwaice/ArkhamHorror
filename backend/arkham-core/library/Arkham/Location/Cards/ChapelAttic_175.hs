module Arkham.Location.Cards.ChapelAttic_175
  ( chapelAttic_175
  , ChapelAttic_175(..)
  )
where

import Arkham.Prelude

import Arkham.GameValue
import Arkham.Location.Cards qualified as Cards
import Arkham.Location.Runner

newtype ChapelAttic_175 = ChapelAttic_175 LocationAttrs
  deriving anyclass (IsLocation, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

chapelAttic_175 :: LocationCard ChapelAttic_175
chapelAttic_175 = location ChapelAttic_175 Cards.chapelAttic_175 4 (Static 0)

instance HasAbilities ChapelAttic_175 where
  getAbilities (ChapelAttic_175 attrs) =
    getAbilities attrs
    -- withRevealedAbilities attrs []

instance RunMessage ChapelAttic_175 where
  runMessage msg (ChapelAttic_175 attrs) =
    ChapelAttic_175 <$> runMessage msg attrs
