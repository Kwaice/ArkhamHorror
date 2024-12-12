{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE ImplicitParams #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE NoFieldSelectors #-}

module Arkham.Text where

import Arkham.I18n
import Arkham.Json
import Arkham.Prelude
import Data.Aeson.TH

newtype Tooltip = Tooltip Text
  deriving stock Data
  deriving newtype (Show, Eq, ToJSON, FromJSON, Ord)

data FlavorTextModifier = BlueEntry | RightAligned | PlainText | InvalidEntry | ValidEntry
  deriving stock (Show, Eq, Ord, Data)

data FlavorTextEntry
  = BasicEntry {text :: Text}
  | I18nEntry {key :: Text, variables :: Map Text Value}
  | ModifyEntry
      { modifiers :: [FlavorTextModifier]
      , entry :: FlavorTextEntry
      }
  | CompositeEntry
      { entries :: [FlavorTextEntry]
      }
  deriving stock (Show, Eq, Ord, Data)

data FlavorText = FlavorText
  { flavorTitle :: Maybe Text
  , flavorBody :: [FlavorTextEntry]
  }
  deriving stock (Show, Eq, Ord, Data)

addFlavorEntry :: FlavorTextEntry -> FlavorText -> FlavorText
addFlavorEntry entry' (FlavorText title entries) =
  FlavorText title (entries <> [entry'])

instance Semigroup FlavorText where
  FlavorText mTitle1 body1 <> FlavorText mTitle2 body2 = FlavorText (mTitle1 <|> mTitle2) (body1 <> body2)

instance Monoid FlavorText where
  mempty = FlavorText Nothing []

i18n :: HasI18n => Text -> FlavorText
i18n = FlavorText Nothing . pure . i18nEntry

i18nEntry :: HasI18n => Scope -> FlavorTextEntry
i18nEntry t = I18nEntry (intercalate "." (?scope <> [t])) ?scopeVars

i18nWithTitle :: HasI18n => Text -> FlavorText
i18nWithTitle t = FlavorText (Just $ toI18n $ t <> ".title") [i18nEntry $ t <> ".body"]

toI18n :: HasI18n => Text -> Text
toI18n = ("$" <>) . ikey

instance IsString FlavorText where
  fromString s = FlavorText Nothing [fromString s]

instance IsString FlavorTextEntry where
  fromString s = BasicEntry (fromString s)

$(deriveJSON defaultOptions ''FlavorTextModifier)
$(deriveToJSON defaultOptions ''FlavorTextEntry)

instance FromJSON FlavorTextEntry where
  parseJSON (String s) = pure $ BasicEntry s
  parseJSON o = $(mkParseJSON defaultOptions ''FlavorTextEntry) o

$(deriveJSON (aesonOptions $ Just "flavor") ''FlavorText)
