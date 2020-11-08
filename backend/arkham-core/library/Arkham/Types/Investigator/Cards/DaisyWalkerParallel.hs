{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.Investigator.Cards.DaisyWalkerParallel
  ( DaisyWalkerParallel(..)
  , daisyWalkerParallel
  )
where

import Arkham.Import

import Arkham.Types.Investigator.Attrs
import Arkham.Types.Investigator.Runner
import Arkham.Types.Stats
import Arkham.Types.Trait

newtype DaisyWalkerParallel = DaisyWalkerParallel Attrs
  deriving newtype (Show, ToJSON, FromJSON)

daisyWalkerParallel :: DaisyWalkerParallel
daisyWalkerParallel = DaisyWalkerParallel
  $ baseAttrs "90001" "Daisy Walker" Seeker stats [Miskatonic]
 where
  stats = Stats
    { health = 5
    , sanity = 7
    , willpower = 1
    , intellect = 5
    , combat = 2
    , agility = 2
    }

instance InvestigatorRunner env => HasModifiersFor env DaisyWalkerParallel where
  getModifiersFor source target@(InvestigatorTarget iid) (DaisyWalkerParallel attrs@Attrs {..})
    | iid == investigatorId
    = do
      tomeCount <- asks $ unAssetCount . getCount (investigatorId, [Tome])
      baseModifiers <- getModifiersFor source target attrs
      pure
        $ SkillModifier SkillWillpower tomeCount
        : SanityModifier tomeCount
        : baseModifiers
  getModifiersFor source target (DaisyWalkerParallel attrs) =
    getModifiersFor source target attrs

ability :: Attrs -> Ability
ability attrs = (mkAbility (toSource attrs) 1 (FastAbility FastPlayerWindow))
  { abilityLimit = PerGame
  }

instance InvestigatorRunner env => HasTokenValue env DaisyWalkerParallel where
  getTokenValue (DaisyWalkerParallel attrs) iid token
    | iid == investigatorId attrs = case drawnTokenFace token of
      ElderSign -> pure $ TokenValue token (PositiveModifier 0)
      _other -> getTokenValue attrs iid token
  getTokenValue (DaisyWalkerParallel attrs) iid token =
    getTokenValue attrs iid token

instance ActionRunner env => HasActions env DaisyWalkerParallel where
  getActions iid FastPlayerWindow (DaisyWalkerParallel attrs)
    | iid == investigatorId attrs = do
      baseActions <- getActions iid FastPlayerWindow attrs
      let ability' = (iid, ability attrs)
      unused <- asks $ notElem ability' . map unUsedAbility . getList ()
      pure
        $ [ uncurry ActivateCardAbilityAction ability' | unused ]
        <> baseActions
  getActions i window (DaisyWalkerParallel attrs) = getActions i window attrs

instance InvestigatorRunner env => RunMessage env DaisyWalkerParallel where
  runMessage msg i@(DaisyWalkerParallel attrs@Attrs {..}) = case msg of
    UseCardAbility iid _ _ 1 -> do
      tomeAssets <- filterM
        (asks . (elem Tome .) . getSet)
        (setToList investigatorAssets)
      pairs' <- traverse (getActions iid NonFast) tomeAssets
      i <$ unshiftMessage
        (Ask iid . ChooseOneAtATime . map (chooseOne iid) $ filter
          (not . null)
          pairs'
        )
    UseCardAbility iid (TokenEffectSource ElderSign) _ 2 ->
      i <$ unshiftMessage (SearchDiscard iid (InvestigatorTarget iid) [Tome])
    ResolveToken ElderSign iid | iid == investigatorId -> i <$ unshiftMessage
      (chooseOne
        iid
        [ UseCardAbility iid (TokenEffectSource ElderSign) Nothing 2
        , Continue "Do not use Daisy's ability"
        ]
      )
    _ -> DaisyWalkerParallel <$> runMessage msg attrs
