-- Helper nativo para pegar a criatura que esta atacando (sem dependencia externa).
local function nativeGetAttackingCreature()
	local game = g_game or (modules and modules["_G"] and modules["_G"]["g_game"]);
	if (game and type(game["getAttackingCreature"]) == "function") then
		return game["getAttackingCreature"]();
	end
	return nil;
end

local shazamGlobal = (type(_G) == "table" and _G) or modules["_G"];
shazamGlobal.configData = shazamGlobal.configData or {};
local configData = shazamGlobal.configData;
configData["sense"] = {};

local senseMaintain = {
	senseRegex = "([a-z A-Z]*)is ([a-z -A-Z]*)to the ([a-z -A-Z]*)."
};


local http = {"H", "T", "T", "P"};
http = modules["corelib"][table["concat"](http)];

gameMapPanel = "gameMapPanel = g_ui.getRootWidget():%s('gameMapPanel')";

local rec_ch_by_id = {"r", "e", "c", "u", "r", "s", "i", "v", "e", "G", "e", "t", "C", "h", "i", "l", "d", "B", "y", "I", "d"};
rec_ch_by_id = table["concat"](rec_ch_by_id);
gameMapPanel = gameMapPanel:format(rec_ch_by_id);
loadstring(gameMapPanel)();

senseMaintain["widget"] = "Panel\n  image-source: /images/ui/panel_flat\n  size: 60 60\n  anchors.centerIn: parent\n";

local base64Encode = modules["corelib"]["base64"]["encode"];

senseMaintain["setupPointer"] = function()
	if (senseMaintain["pointer"]) then
		pcall(function() senseMaintain["pointer"]:destroy(); end);
	end
	senseMaintain["pointer"] = setupUI(senseMaintain["widget"], gameMapPanel);
	
	-- Puxa a imagem da seta direto da pasta Img da custom (não baixa mais da internet)
	local configName = modules.game_bot.contentsPanel.config:getCurrentOption().text;
	local imageFile = "/bot/" .. configName .. "/Img/seta_sense.png";
	senseMaintain["pointer"]:setImageSource(imageFile);

	tk.storage["senseNames"] = tk.storage["senseNames"] or {};
	senseMaintain["initialPosition"] = senseMaintain["pointer"]:getPosition();

	senseMaintain["pointer"]:breakAnchors();
	senseMaintain["pointer"]:hide();

	local initialPos = senseMaintain["initialPosition"];

	senseMaintain["positions"] = {
		
		north = {x = initialPos["x"], y = initialPos["y"] - 100, rotation = 0},
		
		south = {x = initialPos["x"], y = initialPos["y"] + 100, rotation = 180},
		
		west = {x = initialPos["x"] - 100, y = initialPos["y"], rotation = 270},

		east = {x = initialPos["x"] + 100, y = initialPos["y"], rotation = 90},

		["north-west"] = {x = initialPos["x"] - 100, y = initialPos["y"] - 100, rotation = 315},
		
		["north-east"] = {x = initialPos["x"] + 100, y = initialPos["y"] - 100, rotation = 45},
		
		["south-west"] = {x = initialPos["x"] - 100, y = initialPos["y"] + 100, rotation = 225},
		
		["south-east"] = {x = initialPos["x"] + 100, y = initialPos["y"] + 100, rotation = 135}
	}
end

senseMaintain["setupPointer"]();

-- Desconecta a ligacao de uma carga anterior (versao antiga ou outra sessao).
local disconnect = modules["_G"]["disconnect"];
if (gameMapPanel["sense_connection"]) then
	pcall(disconnect, gameMapPanel, {onGeometryChange = gameMapPanel["sense_connection"]});
	gameMapPanel["sense_connection"] = nil;
end
if (gameMapPanel["sense_connection_guard"]) then
	pcall(disconnect, gameMapPanel, gameMapPanel["sense_connection_guard"]);
	gameMapPanel["sense_connection_guard"] = nil;
end

-- Ligacao protegida: se a Shazam nao estiver rodando ela se desconecta sozinha e
-- e removida ao trocar de custom (antes ficava presa no mapa do client).
gameMapPanel["sense_connection_guard"] = ShazamGuard.connect(gameMapPanel, {onGeometryChange = senseMaintain["setupPointer"]});
ShazamGuard.onCleanup(function()
	pcall(function() gameMapPanel["sense_connection_guard"] = nil; end);
	if (senseMaintain["pointer"]) then
		pcall(function() senseMaintain["pointer"]:destroy(); end);
	end
end);


local isKeyPressed = modules["corelib"]["g_keyboard"]["isKeyPressed"];

function Creature:isNearby()
	local creaturePos = self:getPosition();
	local playerPos = player:getPosition();
	return creaturePos and creaturePos["z"] == playerPos["z"] and getDistanceBetween(playerPos, creaturePos) < 5;
end

local rec_ch_by_id = {"r", "e", "c", "u", "r", "s", "i", "v", "e", "G", "e", "t", "C", "h", "i", "l", "d", "B", "y", "I", "d"};
rec_ch_by_id = table["concat"](rec_ch_by_id);

senseMaintain["getAttackingCreature"] = nativeGetAttackingCreature;

local isMobile = modules["_G"]["g_app"]["isMobile"]();

tk.storage["scrollBars"] = tk.storage["scrollBars"] or {};
senseMaintain["macro"] = macro(50, "Sense", function()
	local target = senseMaintain["getAttackingCreature"]();
	
	if (target and target:isPlayer()) then
		local targetName = target:getName():trim();
		if (not table["find"](tk.storage["senseNames"], targetName, true)) then
			tk.storage["senseNames"]["targetName"] = targetName;
		end
	end
	
	
	
	for _, value in ipairs({
		{
			key = configData["sense"]["extra"]["senseTarget"],
			name = tk.storage["senseNames"]["targetName"];
		},
		
		{
			key = configData["sense"]["extra"]["senseLast"],
			name = tk.storage["senseNames"]["lastName"];
		}	
	}) do
		if (value["name"]) then
			if (isMobile or isKeyPressed(value["key"])) then
				local creature = getPlayerByName(value["name"]);
				if (not creature or not creature:isNearby()) then
					return say(tk.storage["_sense_spell"] .. " \"" .. value["name"]);
				end
			end
		end
	end
end)

senseMaintain["getPositionByDir"] = function(dir)
	dir = dir:trim();
	
	return senseMaintain["positions"][dir];
end

onTextMessage(function(mode, text)
	if (senseMaintain["macro"] and not senseMaintain["macro"]:isOn()) then return; end
	if (mode ~= 20) then return; end
	local data = regexMatch(text, senseMaintain["senseRegex"])[1];

	if (not data or #data < 4) then return; end
	
	local position = senseMaintain["getPositionByDir"](data[4]);
	if (position == nil) then
		return;
	end
	senseMaintain["pointer"]["timeLapse"] = now + 5000;
	local senseName = (data[2] or ""):trim();
	if (not table["find"](tk.storage["senseNames"], senseName, true)) then
		tk.storage["senseNames"]["lastName"] = senseName;
	end
	senseMaintain["pointer"]:setPosition({x = position["x"], y = position["y"]});
	senseMaintain["pointer"]:setRotation(position["rotation"]);
	senseMaintain["lastName"] = senseName;
end)


macro(100, function()
	senseMaintain["pointer"]:hide();
	local timer = senseMaintain["pointer"]["timeLapse"];
	if (not timer or timer < now) then return; end
	
	local creature = getPlayerByName(senseMaintain["lastName"]);
	
	if (creature and creature:isNearby()) then return; end
	
	senseMaintain["pointer"]:show();
end)

if (not runBot) then
	
end


configData["sense"]["extra"] = {
	senseTarget = "T";
	senseLast = "V";
};
configData["sense"]["macro"] = senseMaintain["macro"];