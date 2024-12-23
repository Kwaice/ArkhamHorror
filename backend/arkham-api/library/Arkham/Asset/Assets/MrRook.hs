module Arkham.Asset.Assets.MrRook (mrRook, MrRook (..)) where

import Arkham.Ability
import Arkham.Asset.Cards qualified as Cards
import Arkham.Asset.Runner
import Arkham.Card
import Arkham.Deck
import {-# SOURCE #-} Arkham.GameEnv
import Arkham.Matcher
import Arkham.Prelude
import Arkham.Taboo

newtype Metadata = Metadata {chosenCards :: [Card]}
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON, FromJSON)

newtype MrRook = MrRook (AssetAttrs `With` Metadata)
  deriving anyclass (IsAsset, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

mrRook :: AssetCard MrRook
mrRook = ally (MrRook . (`with` Metadata [])) Cards.mrRook (2, 2)

instance HasAbilities MrRook where
  getAbilities (MrRook (a `With` _)) =
    [ restrictedAbility a 1 ControlsThis
        $ (if tabooed TabooList20 a then actionAbilityWithCost else FastAbility)
        $ exhaust a
        <> assetUseCost a Secret 1
    ]

instance RunMessage MrRook where
  runMessage msg a@(MrRook (attrs `With` meta)) = case msg of
    UseThisAbility iid (isSource attrs -> True) 1 -> do
      let goSearch n = search iid (attrs.ability 1) iid [fromTopOfDeck n] #any (defer attrs IsDraw)
      player <- getPlayer iid
      push $ chooseOne player [Label ("Top " <> tshow x) [goSearch x] | x <- [3, 6, 9]]
      pure a
    SearchFound iid (isTarget attrs -> True) _ cards | notNull cards -> do
      player <- getPlayer iid
      pushAll
        [ FocusCards cards
        , chooseOne player
            $ [ targetLabel card
                $ [ UnfocusCards
                  , handleTargetChoice iid attrs card
                  , DoStep 1 msg
                  ]
              | card <- cards
              ]
        ]
      pure a
    DoStep 1 msg'@(SearchFound iid (isTarget attrs -> True) _ cards) -> do
      additionalTargets <- getAdditionalSearchTargets iid

      let
        chosenWeakness = any (`cardMatch` WeaknessCard) (chosenCards meta)
        anyWeaknesses = any (`cardMatch` WeaknessCard) cards
        chosenNonWeakness = filter (not . (`cardMatch` WeaknessCard)) (chosenCards meta)
        canChooseMore = length chosenNonWeakness < additionalTargets + 1
        needsToChooseWeakness = not chosenWeakness && anyWeaknesses

      -- if we need to draw weakness, or we need to draw more, repeat step 1
      -- else we go to step 2
      if canChooseMore || needsToChooseWeakness
        then do
          player <- getPlayer iid
          pushAll
            [ FocusCards cards
            , chooseOne player
                $ [ targetLabel
                    (toCardId card)
                    [ UnfocusCards
                    , handleTargetChoice iid attrs card
                    , DoStep 1 msg'
                    ]
                  | card <- cards
                  , card `cardMatch` WeaknessCard || canChooseMore
                  , card `notElem` chosenCards meta
                  ]
            ]
        else push $ DoStep 2 msg'
      pure a
    DoStep 2 (SearchFound iid (isTarget attrs -> True) _ _) -> do
      push $ DrawToHandFrom iid (toDeck iid) (chosenCards meta)
      pure $ MrRook (attrs `with` Metadata [])
    HandleTargetChoice _ (isSource attrs -> True) (CardIdTarget cid) -> do
      card <- getCard cid
      pure $ MrRook $ attrs `with` Metadata {chosenCards = card : chosenCards meta}
    _ -> MrRook . (`with` meta) <$> runMessage msg attrs
