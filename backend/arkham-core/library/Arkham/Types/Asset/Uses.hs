module Arkham.Types.Asset.Uses where

import ClassyPrelude
import Data.Aeson

data UseType = Ammo | Supply | Secret | Charge | Try | Bounty | Whistle | Resource | Key
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON, FromJSON)

data Uses = NoUses | Uses UseType Int
  deriving stock (Show, Eq, Generic)

use :: Uses -> Uses
use NoUses = NoUses
use (Uses useType n) = Uses useType (max 0 (n - 1))

useCount :: Uses -> Int
useCount NoUses = 0
useCount (Uses _ n) = n

instance ToJSON Uses where
  toJSON NoUses = Null
  toJSON (Uses t n) = object ["type" .= toJSON t, "amount" .= toJSON n]
  toEncoding NoUses = toEncoding Null
  toEncoding (Uses t n) = pairs ("type" .= t <> "amount" .= n)

instance FromJSON Uses where
  parseJSON = \case
    Null -> pure NoUses
    Object o -> Uses <$> o .: "type" <*> o .: "amount"
    _ -> error "no such parse"
