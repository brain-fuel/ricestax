-- Tangled from sydtest.md.
-- Edit the specification, not this file.
-- Every comment below is generated from the prose there.

-- | wavelet names a mutant by an FNV-1a hash of its anchor, and the probe's observations are
-- keyed
-- by that name, so the same hash is needed here to join them; nothing else in Rice's Tax hashes
-- this way. ref:DEC-mutant-location
--
-- Specified by sydtest S23.
module RicesTax.Fnv
  ( fnv1a64
  , fnv1aHex
  ) where

import Data.Bits (xor)
import Data.Char (ord)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Word (Word64)
import Numeric (showHex)

-- | Each line gets a newline appended, as wavelet's hash does, and a character enters as its code
--
-- point modulo 256 rather than as UTF-8, because that is what the observations were keyed with.
--
-- ref:DEC-mutant-location
--
-- Specified by sydtest S24.
fnv1a64 :: [Text] -> Word64
fnv1a64 = foldl step 14695981039346656037 . concatMap (\l -> T.unpack l ++ "\n")
  where
    step h c = (h `xor` fromIntegral (ord c `mod` 256)) * 1099511628211

-- | Sixteen lower-case hex digits, zero-padded, the form wavelet writes. ref:DEC-mutant-location
--
-- Specified by sydtest S25.
fnv1aHex :: [Text] -> Text
fnv1aHex ls = let h = showHex (fnv1a64 ls) "" in T.pack (replicate (16 - length h) '0' ++ h)
