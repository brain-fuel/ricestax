-- Tangled from what.md.
-- Edit the specification, not this file.
-- Every comment below is generated from the prose there.

-- | The What queue: one row for every unit that requires a canonical comment, judged on whether
-- its name and signature state, in full words, the fact the unit establishes, with the body as
-- the second side of the digest so a verdict goes stale when any of the three changes. The
-- comment is not an input, so a Why edit never stales a What verdict. ref:DEC-what-queue
-- ref:DEC-what-raised
--
-- Specified by what S1.
module RicesTax.What
  ( whatKey
  , whatFile
  , signatureOf
  , bodyOf
  , whatDigest
  , whatMaterials
  ) where

import Canon.Model
import Canon.Vetting (Material (..), digestOf)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import System.FilePath (makeRelative, normalise, (<.>), (</>))

-- | The ledger key of a unit's What row, the unit key under the kind name. ref:DEC-join-key
--
-- Specified by what S2.
whatKey :: UnitId -> VettingKey
whatKey uid = KindKey "name" (renderUnitId uid)

-- | The shard a What row lives in: the kind directory, then the source path, as comment rows
--
-- mirror the source tree. ref:DEC-subject-granularity
--
-- Specified by what S3.
whatFile :: FilePath -> FilePath
whatFile source = "name" </> makeRelative "/" (normalise source) <.> "yaml"

-- | What the person reads: the name with its signature when the language declares one, else the
--
-- kind and the name.
--
-- Specified by what S4.
signatureOf :: CodeUnit ev -> Text
signatureOf u = case whatSignature w of
  Just sig -> whatName w <> " :: " <> sig
  Nothing -> unitKindText (whatKind w) <> " " <> whatName w
  where
    w = answerValue (unitWhat u)

-- | The body as canon extracted it, or nothing when canon only has its span. A module's body is
--
-- the whole module, which would keep its row stale for ever, so a module has no body side.
--
-- Specified by what S5.
bodyOf :: CodeUnit ev -> Text
bodyOf u
  | unitKindText (whatKind (answerValue (unitWhat u))) `elem` ["module", "file"] = ""
  | otherwise = case answerValue (unitHow u) of
      HowText t -> t
      HowAt _ -> ""

-- | One digest over the name, the signature, and the body, in canon's form.
--
-- Specified by what S6.
whatDigest :: Text -> Maybe Text -> Text -> Text
whatDigest name sig body = digestOf (T.intercalate "\n" [name, fromMaybe "" sig, body])

-- | A material for every unit that requires a comment, which is the set Rule 8 already binds.
--
-- Specified by what S7.
whatMaterials :: [CodeUnit ev] -> [Material]
whatMaterials units =
  [ Material (whatKey (unitId u)) (whatFile (wherePath (answerValue (unitWhere u)))) (whatDigest (whatName w) (whatSignature w) (bodyOf u)) (signatureOf u)
  | u <- units
  , unitRequirement u == Required
  , let w = answerValue (unitWhat u)
  ]
