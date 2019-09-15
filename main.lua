-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------

local composer = require("composer");

-- Hide status bar
display.setStatusBar( display.HiddenStatusBar );

-- See the random number generator
-- This is important when we need to generate random numbers in the game using math.random()
-- This is required only once
math.randomseed(os.time());

-- Go to the menu scene
composer.gotoScene("scenes.menu", { time=800, effect="crossFade" });