module SeleniumWebdriver.Remote where

import Effect (Effect)
import SeleniumWebdriver.Types

foreign import fileDetector ∷ Effect FileDetector
