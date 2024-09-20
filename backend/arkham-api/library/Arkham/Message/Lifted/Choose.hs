module Arkham.Message.Lifted.Choose where

import Arkham.Card.CardCode
import Arkham.Classes.HasGame
import Arkham.Classes.HasQueue
import Arkham.Classes.Query
import Arkham.I18n
import Arkham.Id
import Arkham.Message (Message)
import Arkham.Message.Lifted
import Arkham.Prelude
import Arkham.Query
import Arkham.Question
import Arkham.Queue
import Arkham.SkillType
import Arkham.Target
import Control.Monad.State.Strict
import Control.Monad.Writer.Strict

data ChooseState = ChooseState
  { terminated :: Bool
  , label :: Maybe Text
  }

newtype ChooseT m a = ChooseT {unChooseT :: StateT ChooseState (WriterT [UI Message] m) a}
  deriving newtype
    (Functor, Applicative, Monad, MonadWriter [UI Message], MonadState ChooseState, MonadIO)

instance HasGame m => HasGame (ChooseT m) where
  getGame = lift getGame

instance MonadTrans ChooseT where
  lift = ChooseT . lift . lift

runChooseT :: ChooseT m a -> m ((a, ChooseState), [UI Message])
runChooseT = runWriterT . (`runStateT` ChooseState False Nothing) . unChooseT

chooseOneM :: ReverseQueue m => InvestigatorId -> ChooseT m a -> m ()
chooseOneM iid choices = do
  ((_, ChooseState {label}), choices') <- runChooseT choices
  unless (null choices') do
    case label of
      Nothing -> chooseOne iid choices'
      Just l -> questionLabel l iid $ ChooseOne choices'

chooseOneFromEachM :: ReverseQueue m => InvestigatorId -> [ChooseT m a] -> m ()
chooseOneFromEachM iid choices = do
  choices' <- traverse runChooseT choices
  unless (null choices') $ chooseOneFromEach iid $ map snd choices'

chooseOrRunOneM :: ReverseQueue m => InvestigatorId -> ChooseT m a -> m ()
chooseOrRunOneM iid choices = do
  (_, choices') <- runChooseT choices
  unless (null choices') $ chooseOrRunOne iid choices'

chooseNM :: ReverseQueue m => InvestigatorId -> Int -> ChooseT m a -> m ()
chooseNM iid n choices = do
  (_, choices') <- runChooseT choices
  unless (null choices') $ chooseN iid n choices'

chooseUpToNM :: ReverseQueue m => InvestigatorId -> Int -> Text -> ChooseT m a -> m ()
chooseUpToNM iid n done choices = do
  (_, choices') <- runChooseT choices
  unless (null choices') $ chooseUpToN iid n done choices'

chooseOneAtATimeM :: ReverseQueue m => InvestigatorId -> ChooseT m a -> m ()
chooseOneAtATimeM iid choices = do
  (_, choices') <- runChooseT choices
  unless (null choices') $ chooseOneAtATime iid choices'

forcedWhen :: Monad m => Bool -> ChooseT m () -> ChooseT m ()
forcedWhen b action =
  if b
    then do
      censor id action
      modify $ \s -> s {terminated = True}
    else action

unterminated :: ReverseQueue m => ChooseT m () -> ChooseT m ()
unterminated action = do
  ChooseState {terminated} <- get
  unless terminated action

labeled :: ReverseQueue m => Text -> QueueT Message m () -> ChooseT m ()
labeled label action = unterminated do
  msgs <- lift $ evalQueueT action
  tell [Label label msgs]

labeledI18n :: (HasI18n, ReverseQueue m) => Text -> QueueT Message m () -> ChooseT m ()
labeledI18n label action = unterminated do
  msgs <- lift $ evalQueueT action
  tell [Label ("$" <> scope "labels" (ikey label)) msgs]

damageLabeled :: ReverseQueue m => InvestigatorId -> QueueT Message m () -> ChooseT m ()
damageLabeled iid action = unterminated do
  msgs <- lift $ evalQueueT action
  tell [DamageLabel iid msgs]

cardLabeled :: (ReverseQueue m, HasCardCode a) => a -> QueueT Message m () -> ChooseT m ()
cardLabeled a action = unterminated do
  msgs <- lift $ evalQueueT action
  tell [CardLabel (toCardCode a) msgs]

horrorLabeled :: ReverseQueue m => InvestigatorId -> QueueT Message m () -> ChooseT m ()
horrorLabeled iid action = unterminated do
  msgs <- lift $ evalQueueT action
  tell [HorrorLabel iid msgs]

assetDamageLabeled :: ReverseQueue m => AssetId -> QueueT Message m () -> ChooseT m ()
assetDamageLabeled aid action = unterminated do
  msgs <- lift $ evalQueueT action
  tell [AssetDamageLabel aid msgs]

assetHorrorLabeled :: ReverseQueue m => AssetId -> QueueT Message m () -> ChooseT m ()
assetHorrorLabeled aid action = unterminated do
  msgs <- lift $ evalQueueT action
  tell [AssetHorrorLabel aid msgs]

skillLabeled :: ReverseQueue m => SkillType -> QueueT Message m () -> ChooseT m ()
skillLabeled skillType action = unterminated do
  msgs <- lift $ evalQueueT action
  tell [SkillLabel skillType msgs]

targeting :: (ReverseQueue m, Targetable target) => target -> QueueT Message m () -> ChooseT m ()
targeting target action = unterminated do
  msgs <- lift $ evalQueueT action
  tell [targetLabel target msgs]

targets
  :: (ReverseQueue m, Targetable target) => [target] -> (target -> QueueT Message m ()) -> ChooseT m ()
targets ts action = unterminated $ for_ ts \t -> targeting t (action t)

chooseTargetM
  :: (ReverseQueue m, Targetable target)
  => InvestigatorId
  -> [target]
  -> (target -> QueueT Message m ())
  -> m ()
chooseTargetM iid ts action = chooseOneM iid $ unterminated $ for_ ts \t -> targeting t (action t)

chooseFromM
  :: (ReverseQueue m, Query query, Targetable (QueryElement query))
  => InvestigatorId
  -> query
  -> (QueryElement query -> QueueT Message m ())
  -> m ()
chooseFromM iid matcher action = do
  ((_, ChooseState {label}), choices') <-
    runChooseT $ traverse_ (\t -> targeting t (action t)) =<< select matcher
  unless (null choices')
    $ case label of
      Nothing -> chooseOne iid choices'
      Just l -> questionLabel l iid $ ChooseOne choices'

nothing :: Monad m => QueueT Message m ()
nothing = pure ()

questionLabeled :: ReverseQueue m => Text -> ChooseT m ()
questionLabeled label = modify $ \s -> s {Arkham.Message.Lifted.Choose.label = Just label}
