local shazamGlobal = (type(_G) == "table" and _G) or modules["_G"];
shazamGlobal.configData = shazamGlobal.configData or {};
local configData = shazamGlobal.configData;
configData["followTarget"] = {};


local FollowAttack = {
    targetId = nil,
    
    obstaclesQueue = {},

    
    obstacleWalkTime = 0,
    currentTargetId = nil,
    keyToClearTarget = "Escape",

    
    walkDirTable = {
        [0] = {"y", -1},
        [1] = {"x", 1},
        [2] = {"y", 1},
        [3] = {"x", -1},
    },

    
    flags = {
        ignoreNonPathable = true,
        precision = 0,
        ignoreCreatures = true
    },


    jumpSpell = {
        up = "jump up",
        down = "jump down"
    },

    
    defaultItem = 1111,
    
    defaultSpell = "skip",


    
    customIds = {
        {
            id = 1948,
            castSpell = false
        },
        {
            id = 595,
            castSpell = false
        },
        {
            id = 1067,
            castSpell = false
        },
        {
            id = 1080,
            castSpell = false
        },
        {
            id = 386,
            castSpell = true
        },
    }
};



FollowAttack["distanceFromPlayer"] = function(position)
    local distx = math["abs"](posx() - position["x"]);
    local disty = math["abs"](posy() - position["y"]);

    return math["sqrt"](distx * distx + disty * disty);
end


FollowAttack["walkToPathDir"] = function(path)
    if (path) then
        g_game["walk"](path[1], false);
    end
end


FollowAttack["getDirection"] = function(playerPos, direction)
    local walkDir = FollowAttack["walkDirTable"][direction];
    if (walkDir) then
        playerPos[walkDir[1]] = playerPos[walkDir[1]] + walkDir[2];
    end
    return playerPos;
end


FollowAttack["checkItemOnTile"] = function(tile, table)
    if (not tile) then return nil end;
    for _, item in ipairs(tile:getItems()) do
        local itemId = item:getId();
        for _, itemSelected in ipairs(table) do
            if (itemId == itemSelected["id"]) then
                return itemSelected;
            end
        end
    end
    return nil;
end

 

FollowAttack["checkIfWentToCustomId"] = function(creature, newPos, oldPos, scheduleTime)
    local tile = g_map["getTile"](oldPos);

    local customId = FollowAttack["checkItemOnTile"](tile, FollowAttack["customIds"]);

    if (not customId) then return; end

    if (not scheduleTime) then
        scheduleTime = 0;
    end

    schedule(scheduleTime, function()
        if (oldPos["z"] == posz() or #FollowAttack["obstaclesQueue"] > 0) then
            table["insert"](FollowAttack["obstaclesQueue"], {
                oldPos = oldPos,
                newPos = newPos,
                tilePos = oldPos,
                customId = customId,
                tile = g_map["getTile"](oldPos),
                isCustom = true
            });
        end
    end);
end
 

FollowAttack["checkIfWentToStair"] = function(creature, newPos, oldPos, scheduleTime)

    if (g_map["getMinimapColor"](oldPos) ~= 210) then return; end
    local tile = g_map["getTile"](oldPos);

    if (tile == nil or tile:isPathable()) then return; end

    if (not scheduleTime) then
        scheduleTime = 0;
    end

    schedule(scheduleTime, function()
        if (oldPos["z"] == posz() or #FollowAttack["obstaclesQueue"] > 0) then
            table["insert"](FollowAttack["obstaclesQueue"], {
                oldPos = oldPos,
                newPos = newPos,
                tilePos = oldPos,
                tile = tile,
                isStair = true
            });
        end
    end);
end



FollowAttack["checkIfWentToDoor"] = function(creature, newPos, oldPos)
    if (FollowAttack["obstaclesQueue"][1] and FollowAttack["distanceFromPlayer"](newPos) < FollowAttack["distanceFromPlayer"](oldPos)) then return; end

    if (math["abs"](newPos["x"] - oldPos["x"]) == 2 or math["abs"](newPos["y"] - oldPos["y"]) == 2) then
            

        local doorPos = {
            z = oldPos["z"]
        }

        local directionX = oldPos["x"] - newPos["x"]
        local directionY = oldPos["y"] - newPos["y"]

        if math["abs"](directionX) > math["abs"](directionY) then

            if directionX > 0 then
                doorPos["x"] = newPos["x"] + 1
                doorPos["y"] = newPos["y"]
            else
                doorPos["x"] = newPos["x"] - 1
                doorPos["y"] = newPos["y"]
            end
        else
            if directionY > 0 then
                doorPos["x"] = newPos["x"]
                doorPos["y"] = newPos["y"] + 1
            else
                doorPos["x"] = newPos["x"]
                doorPos["y"] = newPos["y"] - 1
            end
        end

        local doorTile = g_map["getTile"](doorPos);

        if (doorTile:isPathable() or doorTile:isWalkable()) then return; end

        table["insert"](FollowAttack["obstaclesQueue"], {
            newPos = newPos,
            tilePos = doorPos,
            tile = doorTile,
            isDoor = true,
        });
    end
end




-- RTS Ultimate floor-change support used by Follow Target jump recovery.
-- Keeps the original jump spell behavior, but also uses the same nearby
-- floor-change/rope logic as Follow RTS when the map requires it.
local RTS_FloorChangers = {
    RopeSpots = {
        Up = {386, 12202, 211966},
        Down = {}
    },
    Use = {
        Up = {1948, 14559, 5542, 16693, 16692, 1723, 7771, 28906, 20474, 33770, 33985, 5129, 5111, 16277, 37001},
        Down = {435, 28906, 1648, 1646, 8912, 8911, 32642, 5952, 1644, 25054, 1764, 1968}
    }
};

local function RTS_hasId(list, id)
    for _, value in ipairs(list) do
        if value == id then
            return true
        end
    end
    return false
end

local function RTS_executeFloorChanger(direction)
    if not g_game then
        return false
    end

    local p = pos()
    if not p then return false end

    local candidates = {}
    local range = 1

    local function addCandidate(changer, tilePos)
        table.insert(candidates, {
            pos = tilePos,
            changer = changer
        })
    end

    for x = -range, range do
        for y = -range, range do
            local tilePos = {x = p.x + x, y = p.y + y, z = p.z}
            local tile = g_map.getTile(tilePos)

            if tile and tile:getTopUseThing() then
                local thing = tile:getTopUseThing()
                local id = thing:getId()

                if RTS_hasId(RTS_FloorChangers.Use[direction], id) then
                    addCandidate("use", tilePos)
                elseif RTS_hasId(RTS_FloorChangers.RopeSpots[direction], id) then
                    addCandidate("rope", tilePos)
                end
            end

            if tile and tile:getGround() then
                local groundId = tile:getGround():getId()
                if RTS_hasId(RTS_FloorChangers.RopeSpots[direction], groundId) then
                    addCandidate("rope", tilePos)
                end
            end
        end
    end

    local closest
    local closestDistance = 99999

    for _, candidate in ipairs(candidates) do
        local d = math.abs(p.x - candidate.pos.x) + math.abs(p.y - candidate.pos.y)
        if d < closestDistance then
            closestDistance = d
            closest = candidate
        end
    end

    if not closest then
        return false
    end

    local tile = g_map.getTile(closest.pos)
    if not tile then return false end

    if closest.changer == "rope" then
        local top = tile:getTopUseThing()
        if top then
            useWith(9596, top)
            return true
        end
    else
        local top = tile:getTopUseThing()
        if top then
            use(top)
            return true
        end
    end

    return false
end

FollowAttack["checkifWentToJumpPos"] = function(creature, newPos, oldPos)
    local pos1 = { x = oldPos["x"] - 1, y = oldPos["y"] - 1 };
    local pos2 = { x = oldPos["x"] + 1, y = oldPos["y"] + 1 };

    local hasStair = nil
    for x = pos1["x"], pos2["x"] do
        for y = pos1["y"], pos2["y"] do
            local tilePos = { x = x, y = y, z = oldPos["z"] };
            if (g_map["getMinimapColor"](tilePos) == 210) then
                hasStair = true;
                goto continue;
            end
        end
    end
    ::continue::

    if (hasStair) then return; end

    local spell = newPos["z"] > oldPos["z"] and FollowAttack["jumpSpell"]["down"] or FollowAttack["jumpSpell"]["up"];
    -- Corrige direção do jump: usa a direção do deslocamento do alvo.
    local dir = creature:getDirection();
    if newPos.x > oldPos.x then dir = East
    elseif newPos.x < oldPos.x then dir = West
    elseif newPos.y > oldPos.y then dir = South
    elseif newPos.y < oldPos.y then dir = North end

    if (newPos["z"] > oldPos["z"]) then
        spell = FollowAttack["jumpSpell"]["down"];
    end

    table["insert"](FollowAttack["obstaclesQueue"], {
        oldPos = oldPos,
        oldTile = g_map["getTile"](oldPos),
        spell = spell,
        dir = dir,
        isJump = true,
    });
end

onCreaturePositionChange(function(creature, newPos, oldPos)
    if (FollowAttack["mainMacro"]["isOff"]()) then return; end

    if creature:getId() == FollowAttack["currentTargetId"] and newPos and oldPos and oldPos["z"] == newPos["z"] then
        FollowAttack["checkIfWentToDoor"](creature, newPos, oldPos);
    end
end);


onCreaturePositionChange(function(creature, newPos, oldPos)
    if (FollowAttack["mainMacro"]["isOff"]()) then return; end

    if creature:getId() == FollowAttack["currentTargetId"] and newPos and oldPos and oldPos["z"] == posz() and oldPos["z"] ~= newPos["z"] then
        FollowAttack["checkifWentToJumpPos"](creature, newPos, oldPos);
    end
end);


onCreaturePositionChange(function(creature, newPos, oldPos)
    if (FollowAttack["mainMacro"]["isOff"]()) then return; end

    if creature:getId() == FollowAttack["currentTargetId"] and oldPos and g_map["getMinimapColor"](oldPos) == 210 then
        local scheduleTime = oldPos["z"] == posz() and 0 or 250;

        FollowAttack["checkIfWentToStair"](creature, newPos, oldPos, scheduleTime);
    end
end);



onCreaturePositionChange(function(creature, newPos, oldPos)
    if (FollowAttack["mainMacro"]["isOff"]()) then return; end
    if creature:getId() == FollowAttack["currentTargetId"] and oldPos and oldPos["z"] == posz() and (not newPos or oldPos["z"] ~= newPos["z"]) then
        FollowAttack["checkIfWentToCustomId"](creature, newPos, oldPos);
    end
end);



macro(100, function()
    if (not FollowAttack["mainMacro"] or FollowAttack["mainMacro"]["isOff"]()) then return; end

    if (FollowAttack["obstaclesQueue"][1] and ((not FollowAttack["obstaclesQueue"][1]["isJump"] and FollowAttack["obstaclesQueue"][1]["tilePos"]["z"] ~= posz()) or (FollowAttack["obstaclesQueue"][1]["isJump"] and FollowAttack["obstaclesQueue"][1]["oldPos"]["z"] ~= posz()))) then
        table["remove"](FollowAttack["obstaclesQueue"], 1);
    end
end);





macro(100, function()
    if (FollowAttack["mainMacro"]["isOff"]()) then return; end
	if (not modules["corelib"]["g_keyboard"]["isKeyPressed"](configData["followTarget"]["actionKey"])) then
		return;
	end

    if (FollowAttack["obstaclesQueue"][1] and FollowAttack["obstaclesQueue"][1]["isStair"]) then
        local start = now
        local playerPos = pos();
        local walkingTile = FollowAttack["obstaclesQueue"][1]["tile"];
        local walkingTilePos = FollowAttack["obstaclesQueue"][1]["tilePos"];

        if (FollowAttack["distanceFromPlayer"](walkingTilePos) < 2) then
            if (FollowAttack["obstacleWalkTime"] < now) then
                local nextFloor = g_map["getTile"](walkingTilePos);
                if (nextFloor and nextFloor:isPathable()) then
                    FollowAttack["obstacleWalkTime"] = now + 250;
                    use(nextFloor:getTopUseThing());
                else
                    FollowAttack["obstacleWalkTime"] = now + 250;
                    FollowAttack["walkToPathDir"](findPath(playerPos, walkingTilePos, 1, { ignoreCreatures = false, precision = 0, ignoreNonPathable = true }));
                end
                table["remove"](FollowAttack["obstaclesQueue"], 1);
                return 
            end
        end
        local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false });
        if (path == nil or #path <= 1) then
            if (path == nil) then
                use(walkingTile:getTopUseThing());
            end
            return
        end
        
        local tileToUse = playerPos;
        for i, value in ipairs(path) do
            if (i > 5) then break; end
            tileToUse = FollowAttack["getDirection"](tileToUse, value);
        end
        tileToUse = g_map["getTile"](tileToUse);
        if (tileToUse) then
            use(tileToUse:getTopUseThing());
        end
    end
end);


macro(100, function()
    if (FollowAttack["mainMacro"]["isOff"]()) then return; end
	if (not modules["corelib"]["g_keyboard"]["isKeyPressed"](configData["followTarget"]["actionKey"])) then
		return;
	end

    if (FollowAttack["obstaclesQueue"][1] and FollowAttack["obstaclesQueue"][1]["isDoor"]) then
        local playerPos = pos();
        local walkingTile = FollowAttack["obstaclesQueue"][1]["tile"];
        local walkingTilePos = FollowAttack["obstaclesQueue"][1]["tilePos"];
        if (table["compare"](playerPos, FollowAttack["obstaclesQueue"][1]["newPos"])) then
            FollowAttack["obstacleWalkTime"] = 0;
            table["remove"](FollowAttack["obstaclesQueue"], 1);
            local attackingCreature = g_game["getAttackingCreature"]()
            local otherPath = attackingCreature and findPath(playerPos, attackingCreature:getPosition(), 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false }) or nil;

            if (otherPath and #otherPath > 0) then
                g_game["walk"](otherPath[1], false);
            end
            return;
        end
        
        local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false });
        if (path == nil or #path <= 1) then
            if (path == nil) then

                if (FollowAttack["obstacleWalkTime"] < now) then
                    g_game["use"](walkingTile:getTopThing());
                    FollowAttack["obstacleWalkTime"] = now + 500;
                end
            end
            return
        end
    end
end);


macro(100, function()
    if (FollowAttack["mainMacro"]["isOff"]()) then return; end
	if (not modules["corelib"]["g_keyboard"]["isKeyPressed"](configData["followTarget"]["actionKey"])) then
		return;
	end
    
    if (FollowAttack["obstaclesQueue"][1] and FollowAttack["obstaclesQueue"][1]["isJump"]) then
        local playerPos = pos();
        local walkingTilePos = FollowAttack["obstaclesQueue"][1]["oldPos"];
        local distance = FollowAttack["distanceFromPlayer"](walkingTilePos);
        if (playerPos["z"] ~= walkingTilePos["z"]) then
            table["remove"](FollowAttack["obstaclesQueue"], 1);
        end

        local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false });
        
        if (distance == 0) then
            local jumpData = FollowAttack["obstaclesQueue"][1];
            g_game["turn"](jumpData["dir"]);
            schedule(20, function()
                g_game["turn"](jumpData["dir"]);
            end)
            schedule(50, function()
                if (FollowAttack["obstaclesQueue"][1] == jumpData) then
                    say(jumpData["spell"]);
                end
            end)

            -- RTS Ultimate fallback: if this floor is reached through a
            -- use/rope changer instead of the jump spell, trigger it too.
            schedule(150, function()
                if FollowAttack["obstaclesQueue"][1] == jumpData and posz() == jumpData["oldPos"]["z"] then
                    local direction = jumpData["newPos"] and jumpData["newPos"]["z"] > jumpData["oldPos"]["z"] and "Down" or "Up";
                    RTS_executeFloorChanger(direction);
                end
            end)
            return;
        elseif (distance < 2) then
            local nextFloor = g_map["getTile"](walkingTilePos); 
            if (FollowAttack["obstacleWalkTime"] < now) then
                FollowAttack["walkToPathDir"](findPath(playerPos, walkingTilePos, 1, { ignoreCreatures = false, precision = 0, ignoreNonPathable = true }));
                FollowAttack["obstacleWalkTime"] = now + 500;
            end
            return 
        elseif (distance >= 2 and distance < 5 and path) then
            local jumpData = FollowAttack["obstaclesQueue"][1];
            local direction = jumpData["newPos"] and jumpData["newPos"]["z"] > jumpData["oldPos"]["z"] and "Down" or "Up";
            if not RTS_executeFloorChanger(direction) then
                local oldTile = jumpData["oldTile"];
                if oldTile and oldTile:getTopUseThing() then
                    use(oldTile:getTopUseThing());
                end
            end
        elseif (path) then
            local tileToUse = playerPos;
            for i, value in ipairs(path) do
                if (i > 5) then break; end
                tileToUse = FollowAttack["getDirection"](tileToUse, value);
            end
            tileToUse = g_map["getTile"](tileToUse);
            if (tileToUse) then
                use(tileToUse:getTopUseThing());
            end
        end
    end
end);


macro(50, function()
    if (FollowAttack["mainMacro"]["isOff"]()) then return; end
	if (not modules["corelib"]["g_keyboard"]["isKeyPressed"](configData["followTarget"]["actionKey"])) then
		return;
	end
    
    if (FollowAttack["obstaclesQueue"][1] and FollowAttack["obstaclesQueue"][1]["isCustom"]) then
        local playerPos = pos();
        local walkingTile = FollowAttack["obstaclesQueue"][1]["tile"];
        local walkingTilePos = FollowAttack["obstaclesQueue"][1]["tilePos"];
        local distance = FollowAttack["distanceFromPlayer"](walkingTilePos);
        if (playerPos["z"] ~= walkingTilePos["z"]) then
            table["remove"](FollowAttack["obstaclesQueue"], 1);
            return;
        end
        
        if (distance == 0) then
            if (FollowAttack["obstaclesQueue"][1]["customId"]["castSpell"]) then
                say(FollowAttack["defaultSpell"]);
                return;
            end
        elseif (distance < 2) then
            local item = findItem(FollowAttack["defaultItem"])
            if (FollowAttack["obstaclesQueue"][1]["customId"]["castSpell"] or not item) then
                local nextFloor = g_map["getTile"](walkingTilePos); 
                if (FollowAttack["obstacleWalkTime"] < now) then
                    FollowAttack["walkToPathDir"](findPath(playerPos, walkingTilePos, 1, { ignoreCreatures = false, precision = 0, ignoreNonPathable = true }));
                    FollowAttack["obstacleWalkTime"] = now + 500;
                end
            elseif (item) then
                g_game["useWith"](item, walkingTile);
                table["remove"](FollowAttack["obstaclesQueue"], 1);
            end
            return 
        end

        local path = findPath(playerPos, walkingTilePos, 50, { ignoreNonPathable = true, precision = 0, ignoreCreatures = false });
        if (path == nil or #path <= 1) then
            if (path == nil) then
                use(walkingTile:getTopUseThing());
            end
            return
        end
        
        local tileToUse = playerPos;
        for i, value in ipairs(path) do
            if (i > 5) then break; end
            tileToUse = FollowAttack["getDirection"](tileToUse, value);
        end
        tileToUse = g_map["getTile"](tileToUse);
        if (tileToUse) then
            use(tileToUse:getTopUseThing());
        end
    end
end);








FollowAttack["nextPathCheck"] = FollowAttack["nextPathCheck"] or 0
FollowAttack["mainMacro"] = macro(50, "Follow Target", function()
    if (not g_game["isAttacking"]()) then return; end
	if (not modules["corelib"]["g_keyboard"]["isKeyPressed"](configData["followTarget"]["actionKey"])) then
		return;
	end
    if FollowAttack["nextPathCheck"] > now then return end
    FollowAttack["nextPathCheck"] = now + 150

    local playerPos = pos();
    local target = g_game["getAttackingCreature"]();
    if not target then return end
    local targetPosition = target:getPosition();
    if not targetPosition then return end
    if (getDistanceBetween(playerPos, targetPosition) <= 1) then
        return;
    end
    local path = findPath(playerPos, targetPosition, 30, FollowAttack["flags"]);
    if (not path) then
        return;
    end

    g_game["setChaseMode"](1)
    local tileToUse = playerPos;
    for i, value in ipairs(path) do
        if (i > 5) then break; end
        tileToUse = FollowAttack["getDirection"](tileToUse, value);
    end
    tileToUse = g_map["getTile"](tileToUse);
    if (tileToUse) then
        use(tileToUse:getTopUseThing());
    end
end);




macro(150, function() -- PERF: apenas sincroniza o id do alvo
    local target = g_game["getAttackingCreature"]();

    if (target) then
        local targetId = target:getId();

        if (targetId ~= FollowAttack["currentTargetId"]) then
            FollowAttack["currentTargetId"] = targetId; 
        end
    end
end);

onKeyDown(function(key)
    if (key == "Escape") then
        FollowAttack["currentTargetId"] = nil;
    end
end);


configData["followTarget"]["actionKey"] = "Tab";
configData["followTarget"]["macro"] = FollowAttack["mainMacro"];