{-# LANGUAGE OverloadedStrings #-}
module Lib
    ( someFunc
    , someFuncWithChans
    , readWithinNSecs
    , readWithinNSecsBinary
    ) where


import           Control.Concurrent
import           Control.Exception.Base
import           Control.Monad
import           Data.String.Utils

import           Network

import qualified Data.ByteString.Char8     as C
import           Network.Socket            hiding (recv, recvFrom, send, sendTo)
import           Network.Socket.ByteString

import           Control.Concurrent.Async

import           System.IO

import           Control.Monad.Extra

readWithinNSecsBinary :: IO ()
readWithinNSecsBinary = withSocketsDo $ do
  addrinfos <- getAddrInfo Nothing (Just "") (Just "9090")
  let serveraddr = head addrinfos
  sock <- socket (addrFamily serveraddr) Stream defaultProtocol
  connect sock (addrAddress serveraddr)
  readerTid <- forkIO $ sockReader sock
  threadDelay (3 * 10^6)
  putStrLn "Killing the binary reader"
  putStrLn "Closing the socket"
  close sock
  putStrLn "Socket closed!"
  killThread readerTid
  putStrLn "Binary reader thread killed"
  where
    sockReader sock = do
      putStrLn "Receiving ..."
      msg <- recv sock 1024
      putStr "Received "
      C.putStrLn msg


readWithinNSecs :: IO ()
readWithinNSecs = withSocketsDo $ do
  h <- connectTo "localhost" (PortNumber 9090)
  hSetBuffering h NoBuffering
  readerTid <- forkIO $ reader h
--  readerTid <- forkIO $ readerAsync h
--  readerTid <- forkIO $ politeReader h
  threadDelay (2 * 10^6)
  putStrLn "Killing the reader"
  killThread readerTid
  putStrLn "Reader thread killed"

  -- These won't work:
  --
  -- > throwTo readerTid UserInterrupt
  --
  -- > putStrLn "Closing the handle"
  -- > hClose h -- <-- It will block here!!!
  --
  -- > -- Removing @withSocketsDo@ won't help either.
  --
  -- Using something more low-level won't work either.
  --
  -- > let hints = defaultHints
  -- > addr:_ <- getAddrInfo (Just hints) (Just "127.0.0.1") (Just "9090")
  -- > sock <- socket (addrFamily addr) (addrSocketType addr) (addrProtocol addr)
  -- > connect sock (addrAddress addr)
  -- > h <- socketToHandle sock ReadMode
  --

  where
    reader h = do
      line <- strip <$> hGetLine h
      putStrLn $ "Got " ++ line

    readerAsync h = do
      a <- async $ strip <$> hGetLine h
      line <- wait a
      putStrLn $ "Got " ++ line

    politeReader h = forever $ do
      info <- hShow h
      putStrLn info
      line <- ifM (hWaitForInput h (10^6)) (hGetLine h) (return "Nothing!")
      putStrLn $ "Got " ++ line

someFunc :: IO ()
someFunc = withSocketsDo $ do
    h <- connectTo "localhost" (PortNumber 9090)
    hSetBuffering h NoBuffering
    cmdsHandler h
    putStrLn "Closing the handle"
    hClose h
    where
      cmdsHandler h = do
        line <- strip <$> hGetLine h
        case line of
            "quit" -> putStrLn "Bye bye"
            _      -> do
              hPutStrLn h (reverse line)
              cmdsHandler h

someFuncWithChans :: IO ()
someFuncWithChans = withSocketsDo $ do
    h <- connectTo "localhost" (PortNumber 9090)
    hSetBuffering h NoBuffering
    ch <- newChan
    putStrLn "Starting the handler reader"
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
      Line line -> do
            hPutStrLn h (reverse line)
            cmdsHandler h ch

handleReader :: Handle -> Chan Action -> IO ()
handleReader h ch = forever $ do
    line <- strip <$> hGetLine h
    case line of
        "quit" -> writeChan ch Quit
        _      -> writeChan ch (Line line)

data Action = Quit | Line String
