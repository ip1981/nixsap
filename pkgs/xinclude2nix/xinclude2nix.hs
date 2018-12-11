{-# LANGUAGE Arrows #-}

{-
 Takes a list of XML files
 Parses them for xi:xinclude elements
 Extract included files
 Prints list of included files
-}
module Main
  ( main
  ) where

import Data.List (isPrefixOf, stripPrefix)
import Data.Maybe (fromMaybe)
import System.Environment (getArgs)
import Text.XML.HXT.Core
       ((>>>), deep, getAttrValue, hasAttr, hasName, isElem, readDocument,
        returnA, runX)

getXIncludes :: FilePath -> IO [String]
getXIncludes xmlFileName =
  runX $
  readDocument [] xmlFileName >>>
  deep (isElem >>> hasName "xi:include" >>> hasAttr "href") >>>
  proc d ->
  do href <- getAttrValue "href" -< d
     returnA -< href

getFiles :: [String] -> [String]
getFiles = map stripScheme . filter isFile
  where
    fileScheme = "file://"
    isFile s = "/" `isPrefixOf` s || (fileScheme `isPrefixOf` s)
    stripScheme u = fromMaybe u (stripPrefix fileScheme u)

unique :: [String] -> [String]
unique [] = []
unique (x:xs)
  | x `elem` xs = unique xs
  | otherwise = x : unique xs

toNix :: [String] -> String
toNix ss = "[" ++ unwords (map show ss) ++ "]"

main :: IO ()
main = do
  paths <- getArgs
  includedFiles <- unique . getFiles . concat <$> mapM getXIncludes paths
  putStrLn $ toNix includedFiles
