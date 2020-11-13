{-
Welcome to a Spago project!
You can edit this file as you like.
-}
{ name = "webdriver"
, dependencies =
  [ "aff"
  , "aff-reattempt"
  , "aff-promise"
  , "web-html"
  , "web-uievents"
  , "console"
  , "effect"
  , "psci-support"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
}
