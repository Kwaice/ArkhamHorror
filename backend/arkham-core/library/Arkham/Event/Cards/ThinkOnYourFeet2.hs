module Arkham.Event.Cards.ThinkOnYourFeet2 (
  thinkOnYourFeet2,
  ThinkOnYourFeet2 (..),
) where

import Arkham.Prelude

import Arkham.Classes
import Arkham.Event.Cards qualified as Cards
import Arkham.Event.Runner
import Arkham.Matcher
import Arkham.Message
import Arkham.Movement

newtype ThinkOnYourFeet2 = ThinkOnYourFeet2 EventAttrs
  deriving anyclass (IsEvent, HasModifiersFor, HasAbilities)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

thinkOnYourFeet2 :: EventCard ThinkOnYourFeet2
thinkOnYourFeet2 = event ThinkOnYourFeet2 Cards.thinkOnYourFeet2

instance RunMessage ThinkOnYourFeet2 where
  runMessage msg e@(ThinkOnYourFeet2 attrs) = case msg of
    InvestigatorPlayEvent iid eid _ _ _ | eid == toId attrs -> do
      connectedLocations <- selectList AccessibleLocation
      pushWhen (notNull connectedLocations)
        $ chooseOrRunOne iid
        $ targetLabels connectedLocations (only . Move . move attrs iid)
      pure e
    _ -> ThinkOnYourFeet2 <$> runMessage msg attrs
