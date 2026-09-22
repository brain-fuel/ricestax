-- Tangled from site.md.
-- Edit the specification, not this file.
-- Every comment below is generated from the prose there.

-- | The site: every project's pages rendered by canon under one root, an index naming the
-- projects, and the pay page copied beside them over a snapshot of the first project's
-- obligations, so ricestax.org is one directory a static host serves. ref:DEC-site
--
-- Specified by site S1.
module RicesTax.Site
  ( renderSites
  , projectNameOf
  ) where

import Canon (renderSite)
import Canon.Project (loadProject, renderProjectError)
import Canon.Weave (escape, style)
import Control.Monad (forM, forM_, when)
import Data.Aeson (encode)
import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import RicesTax.Core (assemble, gather)
import System.Directory (copyFile, createDirectoryIfMissing, doesDirectoryExist, listDirectory, withCurrentDirectory)
import System.FilePath (takeFileName, (</>))

-- | A project is named by its directory, as its payload names it.
--
-- Specified by site S2.
projectNameOf :: FilePath -> Text
projectNameOf root = T.pack (takeFileName (dropSlash root))
  where
    dropSlash p = if length p > 1 && last p == '/' then init p else p

-- | Renders each root's pages under the output directory by the project's name, writes the index,
--
-- and, given the page directory, copies the pay page to pay/ with the first root's obligations
-- as
--
-- a static snapshot. Returns the number of pages.
--
-- Specified by site S3.
renderSites :: FilePath -> [FilePath] -> Maybe FilePath -> IO (Either Text Int)
renderSites out roots pageDir = do
  rendered <- forM roots $ \root -> do
    loaded <- loadProject root
    case loaded of
      Left err -> pure (Left (T.pack root <> ": " <> renderProjectError err))
      Right project -> withCurrentDirectory root $ do
        let name = projectNameOf root
        result <- renderSite project name (out </> T.unpack name)
        pure (fmap (\n -> (name, n)) result)
  case sequence rendered of
    Left err -> pure (Left err)
    Right pages -> do
      createDirectoryIfMissing True out
      TIO.writeFile (out </> "index.html") (indexPage pages)
      demo <- case (pageDir, roots) of
        (Just dir, first : _) -> do
          present <- doesDirectoryExist dir
          when present $ do
            createDirectoryIfMissing True (out </> "pay")
            files <- listDirectory dir
            forM_ files (\f -> copyFile (dir </> f) (out </> "pay" </> f))
            loaded <- loadProject first
            case loaded of
              Right project -> withCurrentDirectory first $ do
                payload <- gather project >>= assemble
                LBS.writeFile (out </> "pay" </> "obligations") (encode payload)
              Left _ -> pure ()
          pure present
        _ -> pure False
      pure (Right (sum (map snd pages) + (if demo then 1 else 0)))

-- | The index of the site: one entry per project, and the pay page when it is there.
--
-- Specified by site S4.
indexPage :: [(Text, Int)] -> Text
indexPage pages =
  T.unlines
    ( [ "<!doctype html>"
      , "<html lang=\"en\">"
      , "<head>"
      , "<meta charset=\"utf-8\">"
      , "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
      , "<title>Rice&#39;s Tax</title>"
      , "<style>" <> style <> "</style>"
      , "</head>"
      , "<body>"
      , "<header><span class=\"home\">Rice&#39;s Tax</span></header>"
      , "<main>"
      , "<p>What remains after the compiler, the property tests, and the mutation testing have done what they can is a tax a person pays. These are the projects that pay it, each with its tutorials, how-to guides, reference, and explanation.</p>"
      , "<ul>"
      ]
        ++ ["<li><a href=\"" <> escape name <> "/index.html\">" <> escape name <> "</a> <span class=\"quadrant\">" <> T.pack (show n) <> " pages</span></li>" | (name, n) <- pages]
        ++ [ "<li><a href=\"pay/index.html\">pay</a> <span class=\"quadrant\">the review page, over a snapshot</span></li>"
           , "</ul>"
           , "</main>"
           , "</body>"
           , "</html>"
           ]
    )
