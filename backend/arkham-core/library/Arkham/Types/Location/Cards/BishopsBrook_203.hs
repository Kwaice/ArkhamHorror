module Arkham.Types.Location.Cards.BishopsBrook_203
  ( bishopsBrook_203
  , BishopsBrook_203(..)
  )
where

import Arkham.Prelude

import qualified Arkham.Location.Cards as Cards (bishopsBrook_203)
import Arkham.Types.Classes
import Arkham.Types.Game.Helpers
import Arkham.Types.GameValue
import Arkham.Types.Location.Attrs
import Arkham.Types.Location.Runner
import Arkham.Types.LocationSymbol
import Arkham.Types.Modifier
import Arkham.Types.Source

newtype BishopsBrook_203 = BishopsBrook_203 LocationAttrs
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

bishopsBrook_203 :: LocationCard BishopsBrook_203
bishopsBrook_203 = location
  BishopsBrook_203
  Cards.bishopsBrook_203
  3
  (Static 2)
  Square
  [Plus, Circle, Triangle]

instance HasModifiersFor env BishopsBrook_203 where
  getModifiersFor (InvestigatorSource iid) target (BishopsBrook_203 attrs@LocationAttrs {..})
    | isTarget attrs target
    = pure $ toModifiers
      attrs
      [ Blocked
      | iid `notElem` locationInvestigators && not (null locationInvestigators)
      ]
  getModifiersFor _ _ _ = pure []

instance ActionRunner env => HasActions env BishopsBrook_203 where
  getActions = withDrawCardUnderneathAction

instance LocationRunner env => RunMessage env BishopsBrook_203 where
  runMessage msg (BishopsBrook_203 attrs) =
    BishopsBrook_203 <$> runMessage msg attrs
