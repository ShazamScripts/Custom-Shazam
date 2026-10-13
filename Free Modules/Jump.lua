-- Jump da TyrLivre: Auto Jump + Jump on Walk, independente.
-- Tecla F para saltos marcados; Insert/Delete para salto manual.
local configData = {jump = {}, jumpOnWalk = {}}
local range = {};
for x = -15, 15 do
	for y = -15, 15 do
		table["insert"](range, {x=x,y=y});
	end
end

local flags = {
	 
	 
	 
	ignoreCost=true
};

local scanIndex = 1;
local worldName = g_game["getWorldName"]():trim();
local FREE_VERSION = false;
local SUB_ZERO = false;
local rootPanel = g_ui["getRootWidget"]():recursiveGetChildById("gameRootPanel");

local millis = (_G or modules["_G"])["g_clock"]["millis"];

local event;
local addEvent = (_G or modules["_G"])["addEvent"];
local removeEvent = (_G or modules["_G"])["removeEvent"];
local scheduleEvent = (_G or modules["_G"])["scheduleEvent"];

local jumpInfo = {};
local jumpBySave = {};

local config;

local addPosition = function(pos, data)
	local string_pos = jumpBySave["posToString"](pos);
	local current_data = config[string_pos];
	if (current_data ~= nil) then
		return;
	end
	
	
	player:setAndClear(tr("%s\nSaved as Jump %s.", string_pos, data["jumpTo"]));
	
	data["added"] = true;
	config[string_pos] = data;
end

local removePosition = function(pos)
	local string_pos = jumpBySave["posToString"](pos);
	local current_data = config[string_pos];
	if (current_data == nil) then
		return;
	end
	
	player:setAndClear(tr("%s\nRemoved.", string_pos));
	
	current_data["removed"] = true;
	config[string_pos] = current_data;
end

jumpBySave["doCasting"] = function(parameter)
	
	if (not config["jumpSpell"]) then
		say(
			("Jump " .. parameter):lower()
		);
		say(
			("Jump \"" .. parameter):lower()
		);
	else
		local cast = config["jumpSpell"] .. parameter;
		say(cast:lower());
	end
end


jumpBySave["extraJumpDirections"] = {
	["W"] = {x = 0, y = -1, dir = 0},
	["D"] = {x = 1, y = 0, dir = 1},
	["S"] = {x = 0, y = 1, dir = 2},
	["A"] = {x = -1, y = 0, dir = 3}
}

local arrowXkey = {
	["W"] = "Up",
	["S"] = "Down",
	["D"] = "Right",
	["A"] = "Left"
};

for KEY, ARROW in pairs(arrowXkey) do
	jumpBySave["extraJumpDirections"][ARROW] = table["copy"](jumpBySave["extraJumpDirections"][KEY]);
end

jumpBySave["standingTime"] = now;

onPlayerPositionChange(function(newPos, oldPos)
	jumpBySave["standingTime"] = now
end)

jumpBySave["standTime"] = function()
	return now - jumpBySave["standingTime"];
end

local isMobile = modules["_G"]["g_app"]["isMobile"]();
if (isMobile) then
	local keypad = g_ui["getRootWidget"]():recursiveGetChildById("keypad");
	jumpBySave["pointer"] = keypad["pointer"];

	local North = {
		highest = {x = -16, y = 29},
		lowest = {x = -75, y = -30},
		info = {
			dir = 0,
			x = 0,
			y = -1
		};
	};
	local East = {
		highest = {x = 29, y = 75},
		lowest = {x = -30, y = 15},
		info = {
			dir = 1,
			x = 1,
			y = 0
		};
	};
	local South = {
		highest = {x = 75, y = 29},
		lowest = {x = 16, y = -30},
		info = {
			dir = 2,
			x = 0,
			y = 1
		};
	};
	local West = {
		highest = {x = 29, y = -15},
		lowest = {x = -30, y = -75},
		info = {
			dir = 3,
			x = -1,
			y = 0
		};
	}
	jumpBySave["DIRS"] = {North, East, South, West};
end

jumpBySave["getPressedKeys"] = function()
	local wasdWalking = modules["game_walking"]["wsadWalking"];
	
	if (isMobile) then
		local marginTop, marginLeft = jumpBySave["pointer"]:getMarginTop(), jumpBySave["pointer"]:getMarginLeft();
		for index, value in ipairs(jumpBySave["DIRS"]) do
			if (
				(marginTop >= value["lowest"]["x"] and marginTop <= value["highest"]["x"]) and
				(marginLeft >= value["lowest"]["y"] and marginLeft <= value["highest"]["y"])
			) then
				return value["info"];
			end
		end
	else
		for walkKey, value in pairs(jumpBySave["extraJumpDirections"]) do
			if (modules["corelib"]["g_keyboard"]["isKeyPressed"](walkKey)) then
				
				
				if (#walkKey > 1 or wasdWalking) then
					return value;
				end
			end
		end
	end
end

storage["scrollBars"] = storage["scrollBars"] or {};

jumpBySave["onWalkMacro"] = macro(50, "Jump on Walk", function()
	
	if (not rootPanel:isFocused()) then
		jumpBySave["standingTime"] = 0;
		return;
	end
	if (SHZ_JUMP_COMBO_DELAY and SHZ_JUMP_COMBO_DELAY >= now) then return; end
	
	if (player:isWalking() or jumpBySave["standTime"]() <= 200) then return; end
	local values = jumpBySave["getPressedKeys"]();
	if (not values) then return; end
	local pos = pos();
	
	turn(values["dir"]);
	pos["x"] = pos["x"] + values["x"];
	pos["y"] = pos["y"] + values["y"];
	local tile = g_map["getTile"](pos);
	local spell = "Down";
	if (tile and tile:isFullGround()) then
		spell = "Up";
	end
	jumpBySave["doCasting"](spell);
	schedule(50, function()
		jumpBySave["doCasting"](spell == "Up" and "Down" or "Up");
	end)
end)

jumpBySave["posToString"] = function(pos)
	return pos["x"] .. "," .. pos["y"] .. "," .. pos["z"];
end

onPlayerPositionChange(function(newPos, oldPos)
	jumpBySave["lastWalkPos"] = oldPos;
	jumpBySave["actualWalkPos"] = newPos;
end)

function Creature:setAndClear(text, delay)
	self:setText(text);
	delay = delay or 500;
	local time = now + delay;
	self["time"] = time;
	schedule(delay, function()
		if (self["time"] ~= time) then return; end
		self:clearText();
	end)
end

onTalk(function(name, level, mode, text)
	if (not config) then return; end
	if (config["jumpSpell"]) then return; end
	if (name ~= player:getName()) then return; end
	if (mode ~= 44) then return; end
	if (not text:lower():find("jump")) then return; end
	if (text:find("\"") or text:find(":")) then
		config["jumpSpell"] = "Jump \"";
	else
		config["jumpSpell"] = "Jump ";
	end
end)

onTalk(function(name, level, mode, text)
	if (not config) then return; end
	if (FREE_VERSION) then return; end
	if (not storage["saveJumps"]) then return; end
	
	if (name ~= player:getName()) then return; end
	if (mode ~= 44) then return; end
	
	text = text:lower();
	if (not text:find("jump")) then return; end
	
	if (not jumpBySave["actualWalkPos"] or not jumpBySave["lastWalkPos"]) then return; end
	if (jumpBySave["actualWalkPos"]["z"] == jumpBySave["lastWalkPos"]["z"]) then return; end
	
	local jumpVar = text:find("up") and "Up" or "Down";
	local data = {
		direction = jumpBySave["correctDirection"](),
		jumpTo = jumpVar
	};
	addPosition(jumpBySave["lastWalkPos"], data);
end)

jumpBySave["correctDirection"] = function()

	local dir = player:getDirection();
	
	if (dir <= 3) then
		return dir;
	end
	
	return dir < 6 and 1 or 3;
end

local everyPath;
local newFindPath = function(startPos, destPos, maxDist, params)
    if (not destPos or startPos["z"] ~= destPos["z"]) then return; end
    if (type(maxDist) ~= "number") then
        maxDist = 100;
    end
    if (type(params) ~= "table") then
        params = {};
    end
	
    local destPosStr = destPos["x"] .. "," .. destPos["y"] .. "," .. destPos["z"];
	if (everyPath == nil) then
		everyPath = findAllPaths(startPos, maxDist, params);
	end
    local paths = everyPath;
    if (paths[destPosStr] == nil) then
        return nil;
    end

    
	local candidate = paths[destPosStr];
	return candidate[1];
end

local getDistance = function(p1, p2)

    local distx = math["abs"](p1["x"] - p2["x"]);
    local disty = math["abs"](p1["y"] - p2["y"]);

    return math["sqrt"](distx * distx + disty * disty);
end


local getDistanceFromPlayer = function(playerPos, position)
	
	
	local tileDistance = newFindPath(playerPos, position, FREE_VERSION and 6 or 20, flags);
	return tileDistance or -1;
end


jumpBySave["nextPosition"] = {
    {x = 0, y = -1},
    {x = 1, y = 0},
    {x = 0, y = 1},
    {x = -1, y = 0},
    {x = 1, y = -1},
    {x = 1, y = 1},
    {x = -1, y = 1},
    {x = -1, y = -1}
}

jumpBySave["getNextDirection"] = function(pos, dir)
	local offSet = jumpBySave["nextPosition"][dir + 1];
	
	pos["x"] = pos["x"] + offSet["x"];
	pos["y"] = pos["y"] + offSet["y"];
	
	return pos;
end


jumpBySave["doWalk"] = function(pos)
	local playerPos = player:getPosition();
	local path = findPath(playerPos, pos, 20);
	
	if (not path) then return; end
	
	
	local stopped;
	local last_dir;
	for index, dir in ipairs(path) do
		if (index > 7) then
			stopped = true;
			break;
		end
		
		last_dir = dir;
		playerPos = jumpBySave["getNextDirection"](playerPos, dir);
	end
	
	if (not stopped and last_dir) then
		playerPos = jumpBySave["getNextDirection"](playerPos, last_dir);
	end
	
	local tile = g_map["getTile"](playerPos);
	if (tile) then
		local topThing = (tile:getTopUseThing() or tile:getTopThing());
		if (topThing) then
			if (topThing:isMultiUse()) then
				useWith(topThing, player);
			else
				use(topThing);
			end
			return true;
		end
	end
end
	
storage["checkBoxs"] = storage["checkBoxs"] or {};

local isKeyPressed = modules["corelib"]["g_keyboard"]["isKeyPressed"];
jumpBySave["executeMacro"] = macro(20, "Auto Jump", function()
	if (config == nil) then
		return;
	end
	local mainKeyPressed = isKeyPressed(configData["jump"]["actionKey"]);
	if (SUB_ZERO) then
		mainKeyPressed = g_mouse["isPressed"](3);
	end
	
	if (not mainKeyPressed) then
		if (jumpInfo["tile"]) then
			local direction = jumpInfo["jumpTo"];
			if (not direction:lower():find("jump")) then
				direction = "jump " .. direction;
			end
		
			jumpInfo["tile"]:setText(direction:ucwords(), "red");
		end
		
		local playerPos = jumpBySave["posToString"](player:getPosition());
		if (isKeyPressed(configData["jump"]["extra"]["removePosition"])) then
			removePosition(player:getPosition());
		end
		
		if (not storage["saveJumps"] or FREE_VERSION) then
			local jumpTo;
			if (isKeyPressed(configData["jump"]["extra"]["saveUp"])) then
				jumpTo = "Up";
			elseif (isKeyPressed(configData["jump"]["extra"]["saveDown"])) then
				jumpTo = "Down";
			end
			

			if (jumpTo ~= nil) then
				local data = {
					direction = jumpBySave["correctDirection"](),
					jumpTo = jumpTo
				};
				addPosition(player:getPosition(), data);
			end
		end
		return;
	end
	
	if (STAIRS_USING and STAIRS_USING >= now) then 
		return;
	end
	
	local tile = jumpInfo["tile"];
	if (tile == nil) then
		return;
	end
	
	local tilePos = tile:getPosition();
	if (tilePos == nil) then
		return;
	end
	JUMP_USING = now + 500;
	
	
	local direction = jumpInfo["jumpTo"];
	if (not direction:lower():find("jump")) then
		direction = "jump " .. direction;
	end
	
	tile:setText(direction:ucwords(), "green");
	
	
	local distanceFromTile = getDistanceBetween(tilePos, player:getPosition());
	if (distanceFromTile == 0) then
		g_game["turn"](jumpInfo["direction"]);
		local parameter = jumpInfo["jumpTo"]:lower();
		jumpBySave["doCasting"](parameter:find("up") and "Up" or "Down");
		return;
	end
	if (storage["checkBoxs"]["useKunai"] and storage["kunaiId"]) then
		if (tile and tile:canShoot(storage["scrollBars"]["distanceKunai"] or 6)) then
			local topThing = (tile:getTopUseThing() or tile:getTopThing());
			if (topThing) then
				g_game["stop"]();
				potExhaust = now + 300;
				useWith(storage["kunaiId"] or 7382, topThing);
			end
		end
		if (SUB_ZERO) then
			return;
		end
	end
				
	if (not FREE_VERSION or storage["saveJumps"]) then
		if (jumpBySave["doWalk"](tilePos)) then
			return;
		end
		player:autoWalk(tilePos);
		delay(300);
	end
end)

table["sort"](range, function(a, b)
	local _playerPos = {x=0,y=0};
	local axisA = getDistance(_playerPos, a);
	local axisB = getDistance(_playerPos, b);
	
	return axisA < axisB;
end)


jumpBySave["findNearestJump"] = function()
	local nearest = {};
	local playerPos = player:getPosition();
	
	if (jumpInfo["tile"] ~= nil) then
		local actualPos = jumpInfo["tile"]:getPosition();
		if (actualPos ~= nil) then
			local distance = getDistanceFromPlayer(playerPos, actualPos);
			if (distance ~= -1 and actualPos["z"] == playerPos["z"]) then
				nearest["tile"] = jumpInfo["tile"];
				nearest["distance"] = distance;
				nearest["jumpTo"] = jumpInfo["jumpTo"];
				nearest["direction"] = jumpInfo["direction"];
			end
		end
	end
	
	local checkedTiles = 0;
	if (range[scanIndex] == nil) then
		scanIndex = 1;
	end
	while (range[scanIndex] ~= nil and checkedTiles < 30) do
		local currentPos = range[scanIndex];
		local tilePos = {x=playerPos["x"]+currentPos["x"],y=playerPos["y"]+currentPos["y"],z=playerPos["z"]};
		
		scanIndex = scanIndex + 1;
		checkedTiles = checkedTiles + 1;
		
		local stringPos = jumpBySave["posToString"](tilePos);
		local data = config[stringPos];
	
		if (data ~= nil) then
			local distance = getDistanceFromPlayer(playerPos, tilePos);
			if (distance ~= 1) then
				if (nearest["distance"] == nil or distance < nearest["distance"]) then
					local tile = g_map["getTile"](tilePos);
					if (tile and tile:isWalkable(storage["checkBoxs"]["useKunai"] and storage["kunaiId"]) and tile:isPathable()) then
						nearest["tile"] = tile;
						nearest["distance"] = distance;
						nearest["jumpTo"] = data["jumpTo"];
						nearest["direction"] = data["direction"];
					end
				end
			end
		end
	end
	
	if (jumpInfo["tile"] and nearest["tile"] ~= jumpInfo["tile"]) then
		jumpInfo["tile"]:setText("");
	end
	
	jumpInfo = nearest;
	everyPath = nil;
end


macro(1, function()
	if (jumpBySave["executeMacro"]["isOff"]()) then return; end
	
	if (putOnQueue == nil) then
		return addEvent(jumpBySave["findNearestJump"]);
	end
	putOnQueue(jumpBySave["findNearestJump"]);
end)["timeout"] = 1;

macro(1, function()
	if (jumpBySave["executeMacro"]["isOff"]()) then return; end
	if (isKeyPressed(configData["jump"]["jumpUp"])) then
		jumpBySave["doCasting"]("Up");
	elseif (isKeyPressed(configData["jump"]["jumpDown"])) then
		jumpBySave["doCasting"]("Down");
	end
end)

onPlayerPositionChange(function(newPos, oldPos)
	scanIndex = 1;
end)


local event;
local main_file = tr("/shazam_jump_%s.json", g_game.getWorldName());
local readFile = function()
	local ret = {};
	if (g_resources["fileExists"](main_file)) then
		local status, result = pcall(function()
			return json["decode"](g_resources["readFileContents"](main_file));
		end)
		if (not status) then
			error(tr("Erro enquanto carregava o arquivo %s.\n%s", main_file, result));
		else
			ret = result;
		end
	end
	return ret;
end

local saveFile = function(data)
	local status, result = pcall(function()
		return json["encode"](data);
	end)
	
	if (status) then
		g_resources["writeFileContents"](main_file, result);
	end
end

config = readFile();
if type(config) ~= "table" then config = {} end;

if (global_storage == nil) then
	global_storage = storage;
end


if (table["size"](config) == 0 and global_storage and global_storage["jumps"] ~= nil) then
	config = global_storage["jumps"];
	global_storage["jumps"] = nil;
	
	saveFile(config);
end

local checkSaveData = function()
	local new_config = readFile();
if type(config) ~= "table" then config = {} end;
	local current_config = config;
	
	for key, value in pairs(current_config) do
		if (type(value) ~= "table") then
			goto continue;
		end
		
		if (value["removed"]) then
			new_config[key] = nil;
			goto continue;
		end
		
		if (value["added"] == nil) then
			::continue::
		end
		
		new_config[key] = value;
		::continue::
	end
	
	for key, value in pairs(new_config) do
		if (type(value) ~= "table") then
			goto continue;
		end
		
		value["added"] = nil;
		value["removed"] = nil
		
		::continue::
	end
	
	saveFile(new_config);
end

if type(onExitRegister) == "function" then onExitRegister(checkSaveData) end;



local checkBox = setupUI("CheckBox\n  id: checkBox\n  font: cipsoftFont\n  text: Salvar Jumps\n");

if (FREE_VERSION) then
	checkBox:setText("Ir at\233 o jump");
end

checkBox["onCheckChange"] = function(widget, checked)
	if (FREE_VERSION and checked) then
		return widget:setChecked(false);
	end
	storage["saveJumps"] = checked;
end

if (FREE_VERSION) then
	checkBox:setTooltip("Essa fun\231\227o est\225 desativada para a custom free.");
end

if (storage["saveJumps"] == nil) then
	storage["saveJumps"] = true;
end

checkBox:setChecked(storage["saveJumps"]);


configData["jumpOnWalk"]["macro"] = jumpBySave["onWalkMacro"];
configData["jumpOnWalk"]["actionKey"] = "_";

configData["jump"]["actionKey"] = isMobile and "F1" or "F";
configData["jump"]["extra"] = {
	removePosition = "Delete";
	saveUp = "PageUp";
	saveDown = "PageDown";
	jumpUp = "Insert";
	jumpDown = "Delete";
};

configData["jump"]["macro"] = jumpBySave["executeMacro"];
