{-# LANGUAGE OverloadedStrings #-}
module Lib
    ( someFunc
    ) where

import           Control.Concurrent.Async
import           Control.Exception
import           Control.Monad
import           Data.Text                (unpack)
import           System.Info
import           System.IO
import qualified System.Process           as Process
import           Turtle

someFunc :: IO ()
someFunc = do
  hSetBuffering System.IO.stdout NoBuffering
  -- internalExample
  -- procExample
  -- forkAsyncExample
  sysProcExceptionExample

mkExample :: IO () -> IO ()
mkExample otherProc =  otherProc `race` sayBye >>= print

internalExample :: IO ()
internalExample = mkExample haskellProc
  where haskellProc = forever $ putStrLn "Still alive (internal)" >> sleep 1.0

procExample :: IO ()
procExample = mkExample highlander

highlander :: IO ()
highlander = void (proc "java" ["-cp", "src", "SayHi"] empty)

forkAsyncExample :: IO ()
forkAsyncExample = mkExample forkAsyncHighlander
  where forkAsyncHighlander = sh $ using $ do
          a <- fork highlander
          Turtle.wait a

sysProcExceptionExample :: IO ()
sysProcExceptionExample = mkExample aMereMortalProc
  where aMereMortalProc = do
          mJavaPath <-  which (fromText javaCmd)
          case toText <$> mJavaPath of
            Nothing -> putStrLn "I cannot find the java executable"
            Just (Left _) -> putStrLn "I cannot decode the java executable path"
            Just (Right jPath) -> do
              ph <- Process.spawnProcess (unpack jPath) ["-cp", "src", "SayHi"]
              waitForProcess `onException` Process.terminateProcess ph
            where waitForProcess =
                    forever (sleep 2.0) >> putStrLn "Waiting for process"

addExeSuffix :: Text -> Text
addExeSuffix path = if os == "mingw32" then path <> ".exe" else path

javaCmd :: Text
javaCmd = addExeSuffix "java"

sayBye :: IO ()
sayBye = sleep 3.0 >> putStrLn "Bye!"

