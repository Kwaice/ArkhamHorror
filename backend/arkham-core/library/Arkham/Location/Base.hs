module Arkham.Location.Base where

import Arkham.Prelude

import Arkham.Card
import Arkham.Cost
import Arkham.Direction
import Arkham.GameValue
import Arkham.Id
import Arkham.Json
import Arkham.Key
import Arkham.Location.Brazier
import Arkham.LocationSymbol
import Arkham.Matcher (LocationMatcher (..))
import Arkham.SkillType

data LocationAttrs = LocationAttrs
  { locationId :: LocationId
  , locationCardCode :: CardCode
  , locationCardId :: CardId
  , locationLabel :: Text
  , locationRevealClues :: GameValue
  , locationClues :: Int
  , locationDoom :: Int
  , locationHorror :: Int
  , locationResources :: Int
  , locationShroud :: Int
  , locationRevealed :: Bool
  , locationInvestigators :: Set InvestigatorId
  , locationEnemies :: Set EnemyId
  , locationSymbol :: LocationSymbol
  , locationRevealedSymbol :: LocationSymbol
  , locationConnectedMatchers :: [LocationMatcher]
  , locationRevealedConnectedMatchers :: [LocationMatcher]
  , locationTreacheries :: Set TreacheryId
  , locationEvents :: Set EventId
  , locationAssets :: Set AssetId
  , locationDirections :: Map Direction LocationId
  , locationConnectsTo :: Set Direction
  , locationCardsUnderneath :: [Card]
  , locationCostToEnterUnrevealed :: Cost
  , locationCanBeFlipped :: Bool
  , locationInvestigateSkill :: SkillType
  , locationInFrontOf :: Maybe InvestigatorId
  , locationKeys :: Set ArkhamKey
  , locationBrazier :: Maybe Brazier
  , -- We need to track if a location has no clues because timings will interact
    -- with the location being revealed and claim there are no clues before they
    -- are placed. TODO: this could be a hasBeenRevealed bool
    locationWithoutClues :: Bool
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON LocationAttrs where
  toJSON = genericToJSON $ aesonOptions $ Just "location"

instance FromJSON LocationAttrs where
  parseJSON = genericParseJSON $ aesonOptions $ Just "location"
