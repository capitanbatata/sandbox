{-# LANGUAGE OverloadedStrings #-}
module Lib
    ( someFunc
    ) where


import           Control.Concurrent
import           Control.Monad
import           Data.String.Utils
import           Network
import           System.IO

someFunc :: IO ()
someFunc = withSocketsDo $ do
    sock <- listenOn (PortNumber 9090)
    (h, _, _) <- accept sock
    ch <- newChan
    readerTid <- forkIO $ handleReader h ch
    cmdsHandler h ch
    putStrLn "Killing the handler reader"
    killThread readerTid
    putStrLn "Closing the handle"
    hClose h

cmdsHandler :: Handle -> Chan Action -> IO ()
cmdsHandler h ch = do
    act <- readChan ch
    case act of
      Quit      -> putStrLn "Bye bye"
      Line line ->  putStrLn $ "echo \"" ++ line ++ "\""

handleReader :: Handle -> Chan Action -> IO ()
handleReader h ch = forever $ do
    line <- strip <$> hGetLine h
    case line of
        "quit" -> do
            writeChan ch Quit
        _ -> do
            writeChan ch (Line line)

data Action = Quit | Line String
