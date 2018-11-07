{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TemplateHaskell   #-}
module Rule.Delegation.InterfaceSpec where

import           Control.Arrow               ((&&&))
import           Control.Lens                (makeLenses, (%~), (.~), (^.))
import           Control.Monad.Trans         (lift)
import           Data.Function               ((&))
import qualified Data.Map                    as Map
import           Test.Hspec                  (Spec, it, pending)
import           Test.QuickCheck             (Arbitrary, Gen, Property,
                                              arbitrary, property, shrink,
                                              suchThat, (===))

import           Control.State.TransitionGen
import           Rule.Common
import           Rule.Delegation.Activation
import           Rule.Delegation.Interface
import           Rule.Delegation.Scheduling

data DummyBlock
  = DummyBlock
    { _slot  :: Slot
    , _certs :: [DCert]
    }
  deriving (Show, Eq)

makeLenses ''DummyBlock

dcersAreTriggered
  :: Trace (DSEnv, DIState) DummyBlock
  -> Property
dcersAreTriggered tr =
 lastSt ^. activation . dms === Map.fromList (reverse (fmap (_src &&& _dst) allActiveCerts))
  where lastSt = snd $ head $ traceStates tr
        lastEnv = fst $ head $ traceStates tr
        lastSlot = lastEnv ^. s
        allActiveCerts :: [DCert]
        allActiveCerts = concatMap _certs activeBlocks
        activeBlocks :: [DummyBlock]
        activeBlocks = --filter (\b -> (b ^. slot <= activationSlot)) (traceSigs tr)
          if null (traceSigs tr)
          then []
          else tail (traceSigs tr)
        -- activationSlot :: Slot
        -- activationSlot = lastSlot - ((lastEnv ^. d) `min` lastSlot)


dummyBlock :: SigGen () (DSEnv, DIState) DummyBlock
dummyBlock () (dsEnv, diState) = do
  n <- lift $ arbitraryNat `suchThat` (0 <)
  let
    nextSlot = slotInc n (dsEnv ^. s)
    nextEnv = dsEnv & s .~ nextSlot
  (cs, nextDiState) <- apply nextEnv diState deleg
  let nextBlock = DummyBlock nextSlot cs
  return (nextBlock, (nextEnv, nextDiState))

dummyBlocksGen :: Gen (Trace (DSEnv, DIState) DummyBlock)
dummyBlocksGen = sigsGen () (someDSEnv {_d = 1}, initialDIState) [dummyBlock]

instance Arbitrary (Trace (DSEnv, DIState) DummyBlock) where
  arbitrary = dummyBlocksGen

  shrink = traceShrink

spec :: Spec
spec = it "The delegation map is correctly updated" $
       property dcersAreTriggered
