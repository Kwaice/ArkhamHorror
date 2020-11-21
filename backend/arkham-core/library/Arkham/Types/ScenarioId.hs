module Arkham.Types.ScenarioId where

import Arkham.Types.Card
import ClassyPrelude
import Data.Aeson

newtype ScenarioId = ScenarioId CardCode
  deriving newtype (Eq, Hashable, Show, ToJSON, FromJSON, IsString)

newtype CompletedScenarioId = CompletedScenarioId { unCompletedScenarioId :: ScenarioId }
  deriving newtype (Eq, Hashable, Show, ToJSON, FromJSON, IsString)
