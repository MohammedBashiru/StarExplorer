
local composer = require( "composer" )

local scene = composer.newScene()

-- -----------------------------------------------------------------------------------
-- Code outside of the scene event functions below will only be executed ONCE unless
-- the scene is removed entirely (not recycled) via "composer.removeScene()"
-- -----------------------------------------------------------------------------------

local physics = require( "physics" )
physics.start()

physics.setGravity( 0, 0 ) -- Removes gravity

-- Configure image sheets
local sheetInfo = {}
sheetInfo.sheetOptions = 
{
    frames = 
    {
        {   -- 1) asteroid 1
            x = 0,
            y = 0,
            width = 102,
            height = 85
        },
        {   -- 2) asteroid 2
            x = 0,
            y = 85,
            width = 90,
            height = 83
        },
        {   -- 3) asteroid 3
            x = 0,
            y = 168,
            width = 100,
            height = 97
        },
        {   -- 4) ship
            x = 0,
            y = 265,
            width = 98,
            height = 79
        },
        {   -- 5) laser
            x = 98,
            y = 265,
            width = 14,
            height = 40
        },
    },
}
sheetInfo.frameIndex = 
{
    ["asteriod1"] = 1,
    ["asteriod2"] = 2,
    ["asteriod3"] = 3,
    ["ship"] = 4,
    ["laser"] = 5,
}

function sheetInfo:getSheet()
    return sheetInfo.sheetOptions;
end

function sheetInfo:getFrameIndex(name)
    return sheetInfo.frameIndex[name]
end

local objectSheet = graphics.newImageSheet("assets/gameObjects.png", sheetInfo.getSheet());

-- Initialize variables
local lives = 3;
local score = 0;
local died = false;
local asteroidsTable = {}
local ship;
local gameLoopTimer;
local livesText;
local scoreText;

-- Set up display groups
local backGroup;
local mainGroup;
local uiGroup;


local function updateText()
    livesText.text = "Lives: " .. lives;
    scoreText.text = "Score: " .. score;
end

-- Implement createAsteroids
local function createAsteroid()
    local newAsteroid = display.newImageRect(mainGroup, objectSheet, sheetInfo:getFrameIndex("asteriod1"), 102, 85);
    table.insert( asteroidsTable, newAsteroid );
    physics.addBody(newAsteroid, "dynamic", {radius=40, bounce=0.8});
    newAsteroid.myName = "asteroid";

    local whereFrom = math.random(3)

    if ( whereFrom == 1 ) then 
        -- We make the asteroid appear from top left
        newAsteroid.x = -60;
        newAsteroid.y = math.random(500);
        newAsteroid:setLinearVelocity(math.random(40, 120), math.random( 20, 60 ))
    
    elseif ( whereFrom == 2 ) then 
        -- We make asteroid appear from Top
        newAsteroid.x = math.random( display.contentWidth );
        newAsteroid.y = -60;
        newAsteroid:setLinearVelocity(math.random(-40, 40), math.random(40, 120) );
    
    elseif( whereFrom == 3 ) then
        --  We make asteroid appear right
        newAsteroid.x = math.random( display.contentWidth + 60 );
        newAsteroid.y = math.random( 500 );
        newAsteroid:setLinearVelocity( math.random(-120, -40), math.random(20, 60) );
    end

    -- apply torque (rotational force to asteroids)
    newAsteroid:applyTorque( math.random( -6, 6));
end

-- Implement fireLaser
local function fireLaser()
    local newLaser = display.newImageRect( mainGroup, objectSheet, sheetInfo:getFrameIndex("laser"), 14, 50);
    physics.addBody(newLaser, "dynamic", {isSensor=true} );
    newLaser.isBullet = true;
    newLaser.myName = "laser";

    newLaser.x = ship.x;
    newLaser.y = ship.y;

    newLaser:toBack();

    transition.to( newLaser, { y=-40, time=500,
        onComplete = function() 
            display.remove(newLaser)
        end
    } )

end

-- Implement dragShip
local function dragShip(event)
    local ship = event.target
    local phase = event.phase
    if ( phase == "began" ) then
        -- Set touch focus on the ship
        display.currentStage:setFocus(ship);
        -- Store the initial offset position
        ship.tourchOffsetX = event.x - ship.x
    
    elseif( phase == "moved" ) then 
        -- Move the ship to the new tourcn position
        ship.x = event.x - ship.tourchOffsetX
    elseif( phase == "ended" or phase == "cancelled" ) then
        -- Remove the focus from the ship
        display.currentStage:setFocus(nil)
    end

    return true; -- Prevents tourch propagation to the underlying objects
end

-- Implement GameLoop
local function gameLoop()
    -- Create new asteriod
    createAsteroid()

    -- Remove asteriods which have drifted off the screen
    for i = #asteroidsTable, 1, -1  do
        local thisAsteroid = asteroidsTable[i]

        if ( thisAsteroid.x < -100 or 
             thisAsteroid.x > display.contentWidth + 100 or 
             thisAsteroid.y < -100 or 
             thisAsteroid.y > display.contentHeight + 100 )
        then 
            display.remove(thisAsteroid)
            table.remove(asteroidsTable, i)
        end
    end
end

local function restoreShip()

    ship.isBodyActive = false;
    ship.x = display.contentCenterX;
    ship.y = display.contentHeight - 100;

    --  Fade in the ship
    transition.to( ship, { alpha=1, time=4000,
        onComplete = function() 
            ship.isBodyActive = true;
            died = false;
        end
    })
end

local function endGame()
    composer.gotoScene( "scenes.menu", { time=800, effect="crossFade" } )
end

local function onCollision(event)
    if ( event.phase == "began" ) then 
        local obj1 = event.object1;
        local obj2 = event.object2;
        --  Hanlde collision between laser and asteroids
        if ( ( obj1.myName == "asteroid" and obj2.myName == "laser") or 
             ( obj1.myName == "laser" and obj2.myName == "asteroid") )
        then 
            -- Remove both laster and asteroid
            display.remove(obj1);
            display.remove(obj2);

            for i = #asteroidsTable, 1, -1 do 
                if ( asteroidsTable[i] == obj1 or asteroidsTable[i] == obj2 ) then
                    table.remove( asteroidsTable, i )
                    break;
                end
            end

            -- Increase score
            score = score + 100
            scoreText.text = "Score: " .. score
        
        -- Handle collision between asteroids and ship
        elseif ( (obj1.myName == "ship" and obj2.myName == "asteroid" ) or 
                ( obj1.myName == "asteroid" and obj2.myName == "ship") ) then
            if ( died == false ) then
                died = true

                -- Update lives
                lives = lives - 1
                livesText.text = "Lives: " .. lives

                -- Check if player is out of lives

                if ( lives == 0 ) then 
                    display.remove(ship)
                    timer.performWithDelay( 2000, endGame )
                else 
                    ship.alpha = 0
                    timer.performWithDelay(1000, restoreShip )
                end
            end
        end

    end
end

-- -----------------------------------------------------------------------------------
-- Scene event functions
-- -----------------------------------------------------------------------------------

-- create()
function scene:create( event )

	local sceneGroup = self.view
	-- Code here runs when the scene is first created but has not yet appeared on screen
    
    physics.pause()  -- Temporarily pause the physics engine

    -- Set up display groups
    backGroup = display.newGroup()  -- Display group for the background image
    sceneGroup:insert( backGroup )  -- Insert into the scene's view group
 
    mainGroup = display.newGroup()  -- Display group for the ship, asteroids, lasers, etc.
    sceneGroup:insert( mainGroup )  -- Insert into the scene's view group
 
    uiGroup = display.newGroup()    -- Display group for UI objects like the score
    sceneGroup:insert( uiGroup )    -- Insert into the scene's view group

    -- Load background
    local background = display.newImageRect(backGroup, "assets/background.png", 800, 1400);
    background.x = display.contentCenterX;
    background.y = display.contentCenterY;

    -- Load the ship
    ship = display.newImageRect(mainGroup, objectSheet, sheetInfo:getFrameIndex("ship"), 98, 79);
    ship.x = display.contentCenterX;
    ship.y = display.contentHeight - 100;
    physics.addBody(ship, {radius=30, isSensor=true});
    ship.myName = "ship";

    -- Display lives and score
    livesText = display.newText(uiGroup, "Lives: " .. lives, 200, 80, native.systemFont, 36);
    scoreText = display.newText(uiGroup, "Score: " .. score, 400, 80, native.systemFont, 36);

    -- Register ship events
    ship:addEventListener( "tap", fireLaser )
    ship:addEventListener( "touch", dragShip )
end


-- show()
function scene:show( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is still off screen (but is about to come on screen)

	elseif ( phase == "did" ) then
		-- Code here runs when the scene is entirely on screen
        physics.start();
        Runtime:addEventListener("collision", onCollision)
        gameLoopTimer = timer.performWithDelay( 500, gameLoop, 0)
	end
end


-- hide()
function scene:hide( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is on screen (but is about to go off screen)
        timer.cancel(gameLoopTimer)
	elseif ( phase == "did" ) then
        -- Code here runs immediately after the scene goes entirely off screen
        Runtime:removeEventListener("collission", onCollision)
        physics.pause();
        composer.removeScene( "scenes.game" )
	end
end


-- destroy()
function scene:destroy( event )

	local sceneGroup = self.view
	-- Code here runs prior to the removal of scene's view

end


-- -----------------------------------------------------------------------------------
-- Scene event function listeners
-- -----------------------------------------------------------------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )
-- -----------------------------------------------------------------------------------

return scene