module Arkham.Types.Treachery.Cards.LockedDoor
  ( LockedDoor(..)
  , lockedDoor
  )
where

import Arkham.Prelude

import qualified Arkham.Treachery.Cards as Cards
import Arkham.Types.Ability
import Arkham.Types.Card
import Arkham.Types.Classes
import Arkham.Types.Cost
import Arkham.Types.Id
import Arkham.Types.Message
import Arkham.Types.Modifier
import Arkham.Types.Query
import Arkham.Types.SkillType
import Arkham.Types.Source
import Arkham.Types.Target
import Arkham.Types.Treachery.Attrs
import Arkham.Types.Treachery.Helpers
import Arkham.Types.Treachery.Runner
import Arkham.Types.Window

newtype LockedDoor = LockedDoor TreacheryAttrs
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

lockedDoor :: TreacheryCard LockedDoor
lockedDoor = treachery LockedDoor Cards.lockedDoor

instance HasModifiersFor env LockedDoor where
  getModifiersFor _ (LocationTarget lid) (LockedDoor attrs) =
    pure $ toModifiers
      attrs
      [ CannotInvestigate | treacheryOnLocation lid attrs ]
  getModifiersFor _ _ _ = pure []

instance ActionRunner env => HasActions env LockedDoor where
  getActions iid NonFast (LockedDoor a) = do
    investigatorLocationId <- getId @LocationId iid
    pure
      [ UseAbility
          iid
          (mkAbility (toSource a) 1 (ActionAbility Nothing $ ActionCost 1))
      | treacheryOnLocation investigatorLocationId a
      ]
  getActions _ _ _ = pure []

instance (TreacheryRunner env) => RunMessage env LockedDoor where
  runMessage msg t@(LockedDoor attrs@TreacheryAttrs {..}) = case msg of
    Revelation iid source | isSource attrs source -> do
      exemptLocations <- getSet @LocationId
        (TreacheryCardCode $ toCardCode attrs)
      targetLocations <-
        setToList . (`difference` exemptLocations) <$> getSet @LocationId ()
      locations <- for
        targetLocations
        (traverseToSnd $ (unClueCount <$>) . getCount)
      case maxes locations of
        [] -> pure ()
        [x] -> pushAll [AttachTreachery treacheryId (LocationTarget x)]
        xs -> push
          (chooseOne
            iid
            [ AttachTreachery treacheryId (LocationTarget x) | x <- xs ]
          )
      LockedDoor <$> runMessage msg attrs
    UseCardAbility iid (TreacherySource tid) _ 1 _ | tid == treacheryId ->
      t <$ push
        (chooseOne
          iid
          [ BeginSkillTest
            iid
            (toSource attrs)
            (toTarget attrs)
            Nothing
            SkillCombat
            4
          , BeginSkillTest
            iid
            (toSource attrs)
            (toTarget attrs)
            Nothing
            SkillAgility
            4
          ]
        )
    PassedSkillTest _ _ source _ _ _ | isSource attrs source ->
      t <$ push (Discard $ toTarget attrs)
    _ -> LockedDoor <$> runMessage msg attrs
