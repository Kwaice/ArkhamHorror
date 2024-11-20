module Arkham.Treachery.Cards.Tekelili_229 (tekelili_229, Tekelili_229 (..)) where

import Arkham.Scenario.Deck
import Arkham.Treachery.Cards qualified as Cards
import Arkham.Treachery.Import.Lifted

newtype Tekelili_229 = Tekelili_229 TreacheryAttrs
  deriving anyclass (IsTreachery, HasModifiersFor, HasAbilities)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

tekelili_229 :: TreacheryCard Tekelili_229
tekelili_229 = treachery Tekelili_229 Cards.tekelili_229

instance RunMessage Tekelili_229 where
  runMessage msg t@(Tekelili_229 attrs) = runQueueT $ case msg of
    Revelation iid (isSource attrs -> True) -> do
      chooseAndDiscardAsset iid attrs
      putOnBottomOfDeck iid TekeliliDeck attrs
      pure t
    _ -> Tekelili_229 <$> liftRunMessage msg attrs
