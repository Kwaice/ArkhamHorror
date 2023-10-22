module Arkham.Asset.Cards.SergeantMonroe (
  sergeantMonroe,
  SergeantMonroe (..),
)
where

import Arkham.Prelude

import Arkham.Ability
import Arkham.Asset.Cards qualified as Cards
import Arkham.Asset.Runner
import Arkham.DamageEffect
import Arkham.Investigator.Types (Field (..))
import Arkham.Matcher
import Arkham.Projection
import Arkham.Trait (Trait (Innocent))
import Arkham.Window (Window (..))
import Arkham.Window qualified as Window

newtype SergeantMonroe = SergeantMonroe AssetAttrs
  deriving anyclass (IsAsset)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

sergeantMonroe :: AssetCard SergeantMonroe
sergeantMonroe = ally SergeantMonroe Cards.sergeantMonroe (3, 3)

instance HasModifiersFor SergeantMonroe where
  getModifiersFor (InvestigatorTarget iid) (SergeantMonroe a)
    | not (controlledBy a iid) = do
        locationId <- field InvestigatorLocation iid
        assetLocationId <- field AssetLocation (toId a)
        pure
          $ toModifiers a
          $ guard (locationId == assetLocationId && isJust locationId)
          *> [CanAssignDamageToAsset (toId a), CanAssignHorrorToAsset (toId a)]
  getModifiersFor _ _ = pure []

instance HasAbilities SergeantMonroe where
  getAbilities (SergeantMonroe attrs) =
    [ restrictedAbility
        attrs
        1
        (OnSameLocation <> exists (EnemyAt YourLocation <> EnemyWithoutTrait Innocent))
        $ ReactionAbility (AssetDealtDamage #when AnySource $ AssetWithId $ toId attrs) (exhaust attrs)
    ]

getDamage :: [Window] -> Int
getDamage ((windowType -> Window.DealtDamage _ _ _ n) : _) = n
getDamage (_ : rest) = getDamage rest
getDamage [] = error "Invalid window"

instance RunMessage SergeantMonroe where
  runMessage msg a@(SergeantMonroe attrs) = case msg of
    UseCardAbility iid (isSource attrs -> True) 1 (getDamage -> n) _ -> do
      enemies <- selectList $ EnemyAt (locationWithAsset $ toId attrs) <> EnemyWithoutTrait Innocent
      player <- getPlayer iid
      push
        $ chooseOrRunOne player
        $ targetLabels enemies
        $ only
        . (`EnemyDamage` nonAttack (toAbilitySource attrs 1) n)
      pure a
    _ -> SergeantMonroe <$> runMessage msg attrs
