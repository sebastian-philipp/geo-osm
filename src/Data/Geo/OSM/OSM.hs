{-# LANGUAGE MultiParamTypeClasses, TypeSynonymInstances, FlexibleInstances #-}

-- | The @osm@ element of a OSM file, which is the root element. <http://wiki.openstreetmap.org/wiki/API_v0.6/DTD>
module Data.Geo.OSM.OSM
(
  OSM
, osmVersion
, osmGenerator
, osmBounds
, osmChildren
--, osmNote
, readOsmFile
, readOsmFiles
, interactOSMIO
, interactsOSMIO
, interactOSMIO'
, interactsOSMIO'
, interactOSM
, interactsOSM
, interactOSM'
, interactsOSM'
) where

import Prelude hiding (mapM, foldr)

import Text.XML.HXT.Core
import Control.Monad hiding (mapM)
import Data.Foldable
import Data.Traversable
import Data.Geo.OSM.Children
import Data.Geo.OSM.Bound
import Data.Geo.OSM.Bounds
import Data.Geo.OSM.BoundOption
import Data.Lens.Common
import Control.Comonad.Trans.Store
import Data.Geo.OSM.Lens.VersionL
import Data.Geo.OSM.Lens.GeneratorL
import Data.Geo.OSM.Lens.BoundsL
import Data.Geo.OSM.Lens.ChildrenL
import Data.Monoid

-- | The @osm@ element of a OSM file, which is the root element.
data OSM = OSM {
    osmVersion :: String -- ^ The @version@ attribute.
  , osmGenerator :: (Maybe String) -- ^ The @generator@ attribute.
  , osmBounds :: (Maybe (Either Bound Bounds)) -- ^ The @bound@ or @bounds@ elements.
  , osmChildren :: Children -- ^ The child elements.
--  , osmNote :: Maybe String -- ^ A note from the generator
--  , osmBase :: Maybe String -- ^ A timestamp
} deriving Eq

--instance XmlPickler OSM where
--  xpickle =
--    xpElem "osm" (xpWrap (\(version', generator', bound', nwr', note', base') -> OSM version' generator' bound' nwr' note' base', \(OSM version' generator' bound' nwr' note' base') -> (version', generator', bound', nwr', note', base'))
--      (xp6Tuple (xpAttr "version" xpText)
--                (xpOption (xpAttr "generator" xpText))
--                (xpOption (xpAlt (either (const 0) (const 1)) [xpWrap (Left, \(Left b) -> b) xpickle, xpWrap (Right, \(Right b) -> b) xpickle]))
--                xpickle
--                (xpOption $ xpElem "note" xpText)
--                (xpOption $ xpElem "meta" $ xpAttr "osm_base" $ xpText)))

instance XmlPickler OSM where
  xpickle =
    xpElem "osm" (xpWrap (\(version', generator', bound', nwr') -> OSM version' generator' bound' nwr', \(OSM version' generator' bound' nwr') -> (version', generator', bound', nwr'))
      (xp4Tuple (xpAttr "version" xpText)
                (xpOption (xpAttr "generator" xpText))
                (xpOption (xpAlt (either (const 0) (const 1)) [xpWrap (Left, \(Left b) -> b) xpickle, xpWrap (Right, \(Right b) -> b) xpickle]))
                xpickle))


instance Show OSM where
  show =
    showPickled []

instance VersionL OSM String where
  versionL =
    Lens $ \(OSM version generator bounds children) -> store (\version -> OSM version generator bounds children) version

instance BoundsL OSM where
  boundsL =
    Lens $ \(OSM version generator bounds children) -> store (\bounds -> OSM version generator (foldBoundOption (Just . Left) (Just . Right) Nothing bounds) children) $
      case bounds of
        Nothing        -> optionEmptyBound
        Just (Left b)  -> optionBound b
        Just (Right b) -> optionBounds b

instance GeneratorL OSM where
  generatorL =
    Lens $ \(OSM version generator bounds children) -> store (\generator -> OSM version generator bounds children) generator

instance ChildrenL OSM where
  childrenL =
    Lens $ \(OSM version generator bounds children) -> store (\children -> OSM version generator bounds children) children

-- | Constructs a osm with a version, bound or bounds, and node attributes and way or relation elements.
osm ::
  String -- ^ The @version@ attribute.
  -> Maybe String -- ^ The @generator@ attribute.
  -> Maybe (Either Bound Bounds) -- ^ The @bound@ or @bounds@ elements.
  -> Children -- ^ The child elements.
  -> OSM
osm =
  OSM

-- | Reads an OSM file into a list of @OSM@ values removing whitespace.
readOsmFile ::
  FilePath
  -> IO [OSM]
readOsmFile =
  runX . xunpickleDocument (xpickle :: PU OSM) ([withRemoveWS yes, withFileMimeType v_1]) -- FIXME v_1?

-- | Reads 0 or more OSM files into a list of @OSM@ values removing whitespace.
readOsmFiles ::
  [FilePath]
  -> IO [OSM]
readOsmFiles =
  fmap join . mapM readOsmFile

-- | Reads a OSM file, executes the given function on the XML, then writes the given file.
interactOSMIO' ::
  (OSM -> IO OSM) -- ^ The function to execute on the XML that is read.
  -> SysConfigList -- ^ The options for reading the OSM file.
  -> FilePath -- ^ The OSM file to read.
  -> SysConfigList -- ^ The options for writing the OSM file.
  -> FilePath -- ^ The OSM file to write.
  -> IO ()
interactOSMIO' f froma from toa to =
  runX (xunpickleDocument (xpickle :: PU OSM) froma from >>> arrIO f >>> xpickleDocument (xpickle :: PU OSM) toa to) >> return ()

-- | Reads a OSM file, executes the given functions on the XML, then writes the given file.
interactsOSMIO' ::
  Foldable t =>
  t (OSM -> IO OSM) -- ^ The function to execute on the XML that is read.
  -> SysConfigList -- ^ The options for reading the OSM file.
  -> FilePath -- ^ The OSM file to read.
  -> SysConfigList -- ^ The options for writing the OSM file.
  -> FilePath -- ^ The OSM file to write.
  -> IO ()
interactsOSMIO' =
  interactOSMIO' . sumM

-- | Reads a OSM file removing whitespace, executes the given function on the XML, then writes the given file with indentation.
interactOSMIO ::
  (OSM -> IO OSM) -- ^ The function to execute on the XML that is read.
  -> FilePath -- ^ The OSM file to read.
  -> FilePath -- ^ The OSM file to write.
  -> IO ()
interactOSMIO f from =
  interactOSMIO' f [withRemoveWS yes, withFileMimeType v_1] from [withIndent yes, withFileMimeType v_1]

-- | Reads a OSM file removing whitespace, executes the given functions on the XML, then writes the given file with indentation.
interactsOSMIO ::
  Foldable t =>
  t (OSM -> IO OSM) -- ^ The function to execute on the XML that is read.
  -> FilePath -- ^ The OSM file to read.
  -> FilePath -- ^ The OSM file to write.
  -> IO ()
interactsOSMIO =
  interactOSMIO . sumM

-- | Reads a OSM file, executes the given function on the XML, then writes the given file.
interactOSM' ::
  (OSM -> OSM) -- ^ The function to execute on the XML that is read.
  -> SysConfigList -- ^ The options for reading the OSM file.
  -> FilePath -- ^ The OSM file to read.
  -> SysConfigList -- ^ The options for writing the OSM file.
  -> FilePath -- ^ The OSM file to write.
  -> IO ()
interactOSM' f =
  interactOSMIO' (return . f)

-- | Reads a OSM file, executes the given functions on the XML, then writes the given file.
interactsOSM' ::
  Foldable t =>
  t (OSM -> OSM) -- ^ The functions to execute on the XML that is read.
  -> SysConfigList -- ^ The options for reading the OSM file.
  -> FilePath -- ^ The OSM file to read.
  -> SysConfigList -- ^ The options for writing the OSM file.
  -> FilePath -- ^ The OSM file to write.
  -> IO ()
interactsOSM' =
  interactOSM' . sum'

-- | Reads a OSM file removing whitespace, executes the given function on the XML, then writes the given file with indentation.
interactOSM ::
  (OSM -> OSM) -- ^ The function to execute on the XML that is read.
  -> FilePath -- ^ The OSM file to read.
  -> FilePath -- ^ The OSM file to write.
  -> IO ()
interactOSM f =
  interactOSMIO (return . f)

-- | Reads a OSM file removing whitespace, executes the given functions on the XML, then writes the given file with indentation.
interactsOSM ::
  Foldable t =>
  t (OSM -> OSM) -- ^ The function to execute on the XML that is read.
  -> FilePath -- ^ The OSM file to read.
  -> FilePath -- ^ The OSM file to write.
  -> IO ()
interactsOSM =
  interactOSM . sum'

-- not exported

sum' ::
  Foldable t =>
  t (a -> a)
  -> a
  -> a
sum' =
  appEndo . foldMap Endo

sumM ::
  (Monad m, Foldable t) =>
  t (a -> m a)
  -> a
  -> m a
sumM =
  foldr (>=>) return
