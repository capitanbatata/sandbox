{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE BangPatterns #-}

module Main where

import           Data.List (find)
import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Crypto.Hash as H
import           Data.ByteString (ByteString)
import qualified Data.ByteArray as BA
import           Data.Serialize (encode)

import           Cardano.Binary (serialize', serializeEncoding', toCBOR)
import           Cardano.Prelude (noUnexpectedThunks)

main :: IO ()
main = do
  thunkInfo <- noUnexpectedThunks [] stakeDist
  print thunkInfo
  print $ result
  where
    n = 10^6
    theHashOf :: Int -> ByteString
    theHashOf i = serializeEncoding' (toCBOR i) -- encode
    result = Map.lookup (theHashOf n) stakeDist
    stakeDist :: Map ByteString Int
    !stakeDist = Map.fromList
              $ zip (theHashOf <$> [0 .. (n :: Int)])
                    (repeat 1)
