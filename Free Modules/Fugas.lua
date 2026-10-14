-- Fugas da TyrLivre adaptada para Custom Shazam (sem TyrBot/Chronic).
local FUGAS_RESTRICTED_MODE = false
local FUGAS_FULL_FEATURES = true -- Mantem todas as funcionalidades habilitadas; nao depende de Chronic.
local shazamFugaStackingCreature, shazamFugaComboDelay
local oldPercent = 0;

local AnchorTop = 1;
local AnchorBottom = 2;
local AnchorLeft = 3;
local AnchorRight = 4;

local stackDirections = {
	["W"] = {keys = {"y"}, signals = {">"}};
	["A"] = {keys = {"x"}, signals = {">"}};
	["S"] = {keys = {"y"}, signals = {"<"}};
	["D"] = {keys = {"x"}, signals = {"<"}};
	["C"] = {keys = {"x", "y"}, signals = {"<", "<"}};
	["Z"] = {keys = {"x", "y"}, signals = {">", "<"}};
	["E"] = {keys = {"x", "y"}, signals = {">", ">"}};
	["Q"] = {keys = {"x", "y"}, signals = {"<", ">"}};
};

local spellsTypes = {
	ESCAPE = "Fugas";
	TRAP = "Traps";
	STACK = "Stack";
	STRAIGHT = "Retas";
	BUFF = "Buffs";
	DEFAULT = "Outros";
};


local spellsLimits = {};
local spellsWidgets = {};
local spellsRespectOrder = {spellsTypes["ESCAPE"]};
local spellsDefaultShowTime = {spellsTypes["ESCAPE"], spellsTypes["TRAP"], spellsTypes["DEFAULT"]};
local spellsOptions = {spellsTypes["ESCAPE"]};


local widgetStartPosition = {x=50,y=50};
local worldName = g_game["getWorldName"]():trim();
local characterName = g_game["getCharacterName"]();
local isMobileApp = (g_app or modules["_G"]["g_app"])["isMobile"]();
local isKeyPressed = modules["corelib"]["g_keyboard"]["isKeyPressed"];
local gameRootPanel = g_ui["getRootWidget"]():recursiveGetChildById("gameRootPanel");


local arrowKeys = {"Up", "Left", "Down", "Right"};
local wasdKeys = {"W", "A", "S", "D", "E", "Z", "Q", "C"};
local numpadKeys = {"Numpad8", "Numpad4", "Numpad2", "Numpad6", "Numpad9", "Numpad1", "Numpad7", "Numpad3"};

local displayOptions = {
	{
		title = "Nome time spell",
		var_name = "showMsg",
		default_value = "spellName"
	},
	{
		title = "Mensagem em laranja",
		var_name = "orangeMsg",
		default_value = "spellName"
	},
	{
		title = "Cooldown da magia",
		var_name = "cooldownTotal",
		range = {min=0,max=600}
	},
	{
		[spellsTypes["STRAIGHT"]] = {
			title = "Tecla para utilizar",
			var_name = "key"
		},
		[spellsTypes["ESCAPE"]] = {
			title = "Tempo imune",
			range = {min=0,max=60}
		},
		[spellsTypes["TRAP"]] = {
			title = "Tempo trapado",
			range = {min=0,max=60}
		},
		[spellsTypes["STACK"]] = {
			title = "Dist\226ncia m\225xima",
			var_name = "distance",
			range = {min=1,max=10}
		},
		title = "Tempo ativo",
		var_name = "activeTotal",
		range = {min=0,max=180},
	},
	{
		[spellsTypes["DEFAULT"]] = {
			title = "Porcentagem do target",
			range = {min=0,max=100}
		},
		title = "Porcentagem",
		var_name = "percent",
		range = {min=0,max=100},
		skip = {spellsTypes["TRAP"], spellsTypes["STACK"], spellsTypes["STRAIGHT"], spellsTypes["BUFF"]}
	},
	{
		[spellsTypes["STACK"]] = {
			title = "Teclas direcionais",
			var_name = "selectedKeys",
			values = {
				table["concat"](wasdKeys, ", "),
				table["concat"](arrowKeys, ", "),
				table["concat"](numpadKeys, ", ");
			},
		},
		[spellsTypes["STRAIGHT"]] = {
			title = "Porcentagem do target",
			var_name = "percent",
			range = {min=0,max=100}
		},
		title = "Tecla para utilizar",
		var_name = "key"
	}
};

local warn;
local config;
local stackData;
local getCastPercent;
local doRefreshSpells;
local doRegisterSpell;

local spellWidget = "UIWidget\n  background-color: black\n  padding: 0 5\n  text-auto-resize: true\n";

local botWidget = setupUI("Panel\n  height: 17\n\n  BotSwitch\n    id: switch\n    anchors.top: parent.top\n    anchors.left: parent.left\n    text-align: center\n    width: 130\n    !text: tr(\"Fugas\")\n\n  Button\n    id: config\n    anchors.top: prev.top\n    anchors.bottom: prev.bottom\n    anchors.left: prev.right\n    anchors.right: parent.right\n    text: Config\n");

local infoCheckBox = setupUI("CheckBox\n  id: checkBox\n  font: cipsoftFont\n  text: Informa\231\245es de batalha\n  margin-top: 3\n");

local entryWidget = "Label\n  background-color: alpha\n  text-offset: 37 4\n  focusable: true\n  height: 16\n  font: verdana-11px-rounded\n\n  CheckBox\n    id: enabled\n    !tooltip: tr(\"Ativar\")\n    anchors.left: parent.left\n    anchors.verticalCenter: parent.verticalCenter\n    width: 15\n    height: 15\n    margin-top: 2\n    margin-left: 3\n\n  CheckBox\n    id: spellTime\n    !tooltip: tr(\"Ativar Time Spell\")\n    anchors.left: prev.right\n    anchors.verticalCenter: prev.verticalCenter\n    width: 15\n    height: 15\n    margin-left: 3\n\n  $focus:\n    background-color: #00000055\n\n  Button\n    id: remove\n    !text: tr('x')\n    anchors.right: parent.right\n    margin-right: 15\n    text-offset: 1 0\n    width: 15\n    height: 15\n    tooltip: Remover magia da lista\n";

local screenWidget = setupUI("MainWindow\n  size: 320 360\n  !text: tr(\"Fugas - Shazam\")\n  color: white\n\n  Panel\n    id: logoPanel\n    anchors.bottom: parent.top\n    anchors.right: parent.right\n    size: 50 50\n\n  Panel\n    id: mainPanel\n    image-source: /images/ui/panel_flat\n    anchors.top: parent.top\n    anchors.bottom: parent.bottom\n    anchors.left: parent.left\n    anchors.right: parent.right\n    image-border: 6\n\n    TextList\n      id: spellsList\n      image-source: /images/ui/textedit\n      anchors.centerIn: parent\n      anchors.left: parent.left\n      anchors.right: parent.right\n      margin-top: 20\n      margin-left: 10\n      margin-right: 10\n      image-border: 6\n      height: 180\n      vertical-scrollbar: spellsListScroll\n\n    VerticalScrollBar\n      id: spellsListScroll\n      anchors.top: spellsList.top\n      anchors.bottom: spellsList.bottom\n      anchors.right: spellsList.right\n      step: 10\n      pixels-scroll: true\n\n    TextEdit\n      id: nameField\n      tooltip: Nome da Magia\n      anchors.bottom: spellsList.top\n      anchors.left: parent.left\n      margin-bottom: 5\n      margin-left: 10\n      width: 185\n\n    Label\n      !text: tr(\"Nome da Magia\")\n      anchors.bottom: prev.top\n      anchors.left: prev.left\n      margin-left: 50\n      margin-bottom: 2\n\n    ComboBox\n      id: configList\n      anchors.top: parent.top\n      anchors.left: spellsList.left\n      text-offset: 3 0\n      margin-top: 5\n      margin-right: 5\n      width: 122\n\n    ComboBox\n      id: typeList\n      anchors.top: prev.top\n      anchors.left: prev.right\n      anchors.right: spellsList.right\n      text-offset: 3 0\n      margin-left: 5\n\n    Button\n      id: addButton\n      !text: tr(\"Adicionar\")\n      anchors.top: nameField.top\n      anchors.bottom: nameField.bottom\n      anchors.left: nameField.right\n      anchors.right: spellsList.right\n      margin-left: 5\n\n    Label\n      anchors.top: spellsList.bottom\n      anchors.right: parent.right\n      anchors.left: parent.left\n      id: message\n      margin-top: 2\n      text-auto-resize: true\n      text-align: center\n      text-wrap: true\n\n    Button\n      id: closeButton\n      !text: tr(\"Fechar\")\n      anchors.bottom: parent.bottom\n      anchors.right: typeList.right\n      anchors.left: configList.left\n      margin-bottom: 1\n", g_ui["getRootWidget"]());

local registerWidget = setupUI("MainWindow\n  size: 320 360\n  !text: tr(\"Fugas - Shazam\")\n  color: white\n\n  Panel\n    id: mainPanel\n    image-source: /images/ui/panel_flat\n    anchors.top: parent.top\n    anchors.bottom: parent.bottom\n    anchors.left: parent.left\n    anchors.right: parent.right\n    image-border: 6\n\n  Button\n    id: addButton\n    !text: tr(\"Adicionar\")\n    anchors.left: mainPanel.left\n    anchors.bottom: mainPanel.bottom\n    margin-bottom: 5\n    margin-left: 1\n    width: 133\n\n  Button\n    id: backButton\n    !text: tr(\"Voltar\")\n    anchors.bottom: mainPanel.bottom\n    anchors.left: addButton.right\n    anchors.right: mainPanel.right\n    margin-bottom: 5\n    margin-right: 2\n    @onClick: self:getParent():hide();\n", g_ui["getRootWidget"]());

local getAllKeys = function()
	local keys = {};
	if (isMobileApp) then
		keys = {"None", "F1", "F2", "Escape"};
	else
		for name, key in pairs(modules["corelib"]["KeyCodeDescs"]) do
			if (key ~= "Unknown") then
				table["insert"](keys, key);
			end
		end
	end
	
	table["sort"](keys);
	table["insert"](keys, 1, "None");
	table["insert"](keys, 1, "AUTO");
	return keys;
end

local isDragKeyPressed = function()
	if (isMobileApp) then
		return isKeyPressed("F2");
	end
	return modules["corelib"]["g_keyboard"]["isCtrlPressed"]();
end

local hasAnyActive = function(type)
	local spells = config["spells"][type];
	for _, entry in ipairs(spells) do
		if (entry["activeTime"] and entry["activeTime"] >= os["time"]()) then
			return true;
		end
	end
end

local getAllScreenWidgets = function()
	local widgets = {};
	for type, data in pairs(spellsWidgets) do
		if (type == "battlingStatus") then
			table["insert"](widgets, data);
			goto continue;
		end
		
		for _, widget in pairs(data) do
			table["insert"](widgets, widget);
		end
		::continue::
	end
	return widgets;
end

local destroyAllWidgets = function()
	screenWidget["mainPanel"]["spellsList"]:destroyChildren();
	
	local widgets = getAllScreenWidgets();
	for _, widget in pairs(widgets) do
		widget:destroy();
	end
	table["clear"](spellsWidgets);
end

local doRemoveMouseMove = function(entry)
	local widget;
	if (entry == "battlingStatus") then
		widget = spellsWidgets[entry];
	else
		widget = spellsWidgets[entry["type"]][entry["spellName"]];
	end
	widget["onDragEnter"] = nil;
	widget["onDragMove"] = nil;
	widget:setFocusable(false);
	widget:setPhantom(true);
	widget:setDraggable(false);
end

local doSetMouseMove = function(entry)
	local widget;
	if (entry == "battlingStatus") then
		widget = spellsWidgets[entry];
	else
		widget = spellsWidgets[entry["type"]][entry["spellName"]];
	end
	widget:setFocusable(true);
	widget:setPhantom(false);
	widget:setDraggable(true);

	widget["onDragEnter"] = function(widget, mousePos)
		widget:breakAnchors();
		widget["movingReference"] = {x = mousePos["x"] - widget:getX(), y = mousePos["y"] - widget:getY()};
		return true;
	end

	widget["onDragMove"] = function(widget, mousePos, moved)
		local parentRect = widget:getParent():getRect();
		local x = math["min"](math["max"](parentRect["x"], mousePos["x"] - widget["movingReference"]["x"]), parentRect["x"] + parentRect["width"] - widget:getWidth());
		local y = math["min"](math["max"](parentRect["y"] - widget:getParent():getMarginTop(), mousePos["y"] - widget["movingReference"]["y"]), parentRect["y"] + parentRect["height"] - widget:getHeight());
		widget:move(x, y);
		local pos = {x = x, y = y};
		if (entry ~= "battlingStatus") then
			entry["pos"] = pos;
		else
			config["battlePos"] = pos;
		end
		return true;
	end
end

local setupWidget = function(entry)
	local widget = setupUI(spellWidget, g_ui["getRootWidget"]());
	local widgetPos;
	if (entry == "battlingStatus") then
		widgetPos = config["battlePos"];
		spellsWidgets[entry] = widget;
	else
		widgetPos = entry["pos"];
		if (spellsWidgets[entry["type"]] == nil) then
			spellsWidgets[entry["type"]] = {};
		end
		spellsWidgets[entry["type"]][entry["spellName"]] = widget;
	end
	widget:setPosition(widgetPos or widgetStartPosition);
	widget["entry"] = entry;
 	
	doRemoveMouseMove(entry);
end

local setBattleStatus = function()
	local widget = spellsWidgets["battlingStatus"];
	if (widget == nil) then return; end
	
	local attackingPlayers = table["size"](config["attackers"]);
	
	local escape_status;
	if (hasAnyActive(spellsTypes["ESCAPE"])) then
		escape_status = "Fuga ativa!";
	else
		local spells = config["spells"][spellsTypes["ESCAPE"]];
		local showPercent;
		for _, entry in ipairs(spells) do
			if (not entry["cooldownTime"] and entry["enabled"] and (entry["percent"] or 0) > 0) then
				showPercent = entry["percent"];
				break
			end
		end
		if (showPercent ~= nil) then
			escape_status = tr("Fuga em %d", getCastPercent(showPercent)) .. "%";
		end
	end
		
	local status = {tr("Oponentes: %d", attackingPlayers), escape_status};
	widget:setText(table["concat"](status, " | "));
	widget:setColor(attackingPlayers == 0 and "white" or "red");
end

local canStack = function(from, to, data)
	for i = 1, table["size"](data["keys"]) do
		local key = data["keys"][i];
		local signal = data["signals"][i];
		local script = tr(
		"\t\t\tlocal args = {...};\n\t\t\tlocal from = args[1];\n\t\t\tlocal to = args[2];\n\t\t\tlocal key = args[3];\n\t\t\tif (from[key] %s to[key]) then\n\t\t\t\treturn true;\n\t\t\telseif (from[key] == to[key]) then\n\t\t\t\tlocal sub_key = key == \"x\" and \"y\" or \"x\";\n\t\t\t\tlocal playerPos = player:getPosition();\n\t\t\t\tlocal currentDistance = math.abs(playerPos[sub_key] - from[sub_key]);\n\t\t\t\tlocal distance = math.abs(playerPos[sub_key] - to[sub_key]);\n\t\t\t\treturn distance < currentDistance;\n\t\t\tend\n\t\t", signal);
		local call_script = load(script);
		local result = call_script(from, to, key);
		if (not result) then
			return false;
		end
	end
	return true;
end

local getStackingCreature = function(key, entry)
	local data = stackDirections[key];
	local playerPos = player:getPosition();
	local spectators = getSpectators();
	
	local result = {pos=playerPos};
	for _, spec in ipairs(spectators) do
		local specPos = spec:getPosition();
		if (specPos ~= nil and spec:isMonster()) then
			local distance = getDistanceBetween(specPos, playerPos);
			if (distance <= entry["distance"]) then
				if (canStack(result["pos"], specPos, data)) then
					if (spec:canShoot()) then
						result["pos"] = specPos;
						result["creature"] = spec;
					end
				end
			end
		end
	end
	return result["creature"];
end

local doCancelStack = function()
	if (not stackData) then return; end
	if (keepTarget ~= nil) then
		keepTarget["isStacking"] = false;
	end
	
	for i = 1, 10 do
		schedule(i * 50, function()
			local creature = (g_game["getAttackingCreature"] or g_game["getAttackingCreature"])();
			if (creature == nil or shazamFugaStackingCreature == nil) then
				shazamFugaStackingCreature = nil;
				return;
			end
			
			if (creature == shazamFugaStackingCreature) then
				g_game["cancelAttack"]();
			end
			
		end)
	end
	
	
	stackData = nil;
end

local doStack = function()
	local entry = stackData["entry"];
	local creature = getStackingCreature(stackData["key"], stackData["entry"]);
	if (not creature) then
		return doCancelStack();
	end
	
	shazamFugaComboDelay = now + 500;
	
	if (keepTarget ~= nil) then
		keepTarget["isStacking"] = true;
	end
	
	stackData["creature"] = creature;
	local target = (g_game["getAttackingCreature"] or g_game["getAttackingCreature"])();
	if (target ~= creature) then
		local doAttack = g_game["attack"];
		if (doAttack == nil) then
			doAttack = g_game["attack"];
		end
		
		shazamFugaStackingCreature = creature;
		doAttack(creature);
		
	end
	
	
		
			
			
		
	
	
	schedule(10, function()
		say(entry["spellName"], table["size"](spellsOptions) - table["find"](spellsOptions, spellsTypes["STACK"]));
	end)
end

local getLowestBetween = function(p1, p2)

	local distx = math["abs"](p1["x"] - p2["x"]);
	local disty = math["abs"](p1["y"] - p2["y"]);
	
	return math["min"](distx, disty);
end

local canUseStraight = function()
	local target = g_game["getAttackingCreature"]();
	if (target == nil) then
		return false;
	end
	
	local targetPos = target:getPosition();
	if (not targetPos) then 
		return false; 
	end
	
	local playerPos = player:getPosition();
	local distance = getDistanceBetween(playerPos, targetPos);
	local lowest = getLowestBetween(playerPos, targetPos);
	if (distance > 0 and distance <= 4 and lowest <= (g_game["getWorldName"]():lower():find("db") and 1 or 0)) then
		local dir = player:getDirection();
		dir = dir <= 3 and dir or dir < 6 and 1 or 3;
		if (playerPos["x"] > targetPos["x"]) then
			turn(West);
			return dir == West;
		elseif (playerPos["x"] < targetPos["x"]) then
			turn(East);
			return dir == East;
		elseif (playerPos["y"] > targetPos["y"]) then
			turn(North);
			return dir == North;
		elseif (playerPos["y"] < targetPos["y"]) then
			turn(South);
			return dir == South;
		end
	end
end

local getAttackersAddition = function()
	local attackers = table["size"](config["attackers"]);
	attackers = attackers < 6 and attackers or 6;
	return attackers * 5;
end

getCastPercent = function(value)
	if (value == 100) then
		value = 45;
	end
	value = value + getAttackersAddition();
	return value <= 100 and value or 100;
end

local canCast = function(entry)
	if (not entry["enabled"]) then
		return false;
	end
	
	if ((entry["cooldownTime"] or 0) >= os["time"]()) then
		return false;
	end

	if (table["find"](spellsRespectOrder, entry["type"]) and hasAnyActive(entry["type"])) then
		return false;
	end

	local key = entry["key"];
	local percent = (tonumber(entry["percent"]) or 0);
	
	
	if (entry["type"] == spellsTypes["ESCAPE"]) then
		if (percent > 0) then
			local healthPercent = (player:getHealthPercent() or 100);
			if (healthPercent < getCastPercent(percent)) then
				return true;
			end
		end
		return isKeyPressed(key);
	end
	
	if (entry["type"] == spellsTypes["TRAP"]) then
		if (key == "AUTO") then
			local target = g_game["getAttackingCreature"]();
			if (target and target:isPlayer()) then
				return true;
			end
		end
		
		return isKeyPressed(key);
	end
		
	if (entry["type"] == spellsTypes["STACK"]) then
		if (g_mouse["isPressed"](3)) then 
			for _, key in ipairs(entry["selectedKeys"]:split(", ")) do
				if (isKeyPressed(key)) then
					local creature = getStackingCreature(key, entry);
					if (creature ~= nil) then
						return key;
					end
				end
			end
		end
		return;
	end
	
	if (entry["type"] == spellsTypes["STRAIGHT"]) then
		local castPercent = percent;
		if (castPercent ~= nil) then
			local target = g_game["getAttackingCreature"]();
			if (target and target:isPlayer()) then
				local healthPercent = (target:getHealthPercent() or 100);
				if (healthPercent < castPercent) then
					return canUseStraight();
				end
			end
		end
		if (entry["key"] == "AUTO" or isKeyPressed(key)) then
			return canUseStraight();
		end
		return;
	end
	
	if (entry["type"] == spellsTypes["BUFF"]) then
		if ((storage["sealedTypes"] and storage["sealedTypes"]["buff"] or 0) >= os["time"]()) then
			return false;
		end
		
		if (entry["key"] == "AUTO") then
			return true;
		end
		
		return isKeyPressed(entry["key"]);
	end
	
	if (entry["type"] == spellsTypes["DEFAULT"]) then
		local castPercent = percent;
		if (castPercent ~= nil) then
			local target = g_game["getAttackingCreature"]();
			if (target and target:isPlayer()) then
				local healthPercent = (target:getHealthPercent() or 100);
				if (healthPercent < castPercent) then
					return true;
				end
			end
		end
		
		return isKeyPressed(entry["key"]);
	end
end

local doSpellCast = function(type)
	local spells = config["spells"][type];
	if (#spells == 0) then return; end
	
	local any_castable;
	local respectOrder = table["find"](spellsRespectOrder, type);
	for _, entry in ipairs(spells) do
		if (
			respectOrder and 
			(not entry["key"] or not isKeyPressed(entry["key"])) and 
			entry["enabled"] and
			(entry["cooldownTotal"] or 0) > 0
		) then
			if (any_castable ~= nil) then
				goto continue;
			end
			if (not entry["cooldownTime"]) then
				any_castable = true;
			end
		end

		local result = canCast(entry);
		if (result) then
			if (entry["type"] == spellsTypes["STACK"]) then
				stackData = {};
				stackData["key"] = result;
				stackData["entry"] = entry;
			else
				if (
					(entry["key"] ~= nil and isKeyPressed(entry["key"])) or 
					entry["type"] == spellsTypes["ESCAPE"]
				) then
					shazamFugaComboDelay = now + 500;
				end
				say(entry["spellName"], table["size"](spellsOptions) - table["find"](spellsOptions, entry["type"]));
				if (respectOrder) then
					return;
				end
			end
		end
		::continue::
	end
end

table["findbyfield"] = function(t, fieldname, fieldvalue)
	for _i,subt in pairs(t) do
		if subt[fieldname] == fieldvalue then
			return subt
		end
	end
	return nil
end

local reIndex = function()
	local selectedSpells = config["spells"][config["selected_type"]];
	for index, widget in ipairs(screenWidget["mainPanel"]["spellsList"]:getChildren()) do
		local entry = table["findbyfield"](selectedSpells, "spellName", widget:getId());
		entry["index"] = index;
	end
end

doRefreshSpells = function()
	destroyAllWidgets();
	for type, data in pairs(config["spells"]) do
		local removedTotal = 0;
		local removeEntries = {};
		local limit = spellsLimits[type];
		for index, entry in ipairs(data) do
			if (limit < index) then
				table["insert"](removeEntries, index);
				goto continue;
			end
		
			if (config["enabled"] and entry["enabled"] and entry["spellTime"]) then
				setupWidget(entry);
			end
			::continue::
		end
		for _, index in ipairs(removeEntries) do
			table["remove"](data, index - removedTotal);
			removedTotal = removedTotal + 1;
		end
	end
	
	local selectedSpells = config["spells"][config["selected_type"]];
	for index, entry in ipairs(selectedSpells) do
		local widget = setupUI(entryWidget, screenWidget["mainPanel"]["spellsList"]);
		local removeSpell = function()
			screenWidget["mainPanel"]["nameField"]:setText(entry["spellName"]);
			table["remove"](selectedSpells, index);
			doRefreshSpells();
		end
		
		widget["onDoubleClick"] = function()
			doRegisterSpell(table["copy"](entry));
			removeSpell();
		end
		widget["remove"]["onClick"] = removeSpell;
		widget["enabled"]:setChecked(entry["enabled"]);
		widget["spellTime"]:setChecked(entry["spellTime"]);

		widget["enabled"]["onCheckChange"] = function(widget, enabled)
			entry["enabled"] = enabled;
			doRefreshSpells();
		end
		widget["spellTime"]["onCheckChange"] = function(widget, enabled)
			entry["spellTime"] = enabled;
			doRefreshSpells();
		end

		local text = {entry["spellName"]:sub(1, 10):ucwords(), tr("CD: %ds", entry["cooldownTotal"])};
		if (entry["percent"]) then
			local percent = (entry["percent"] == 100 and "AUTO" or entry["percent"]) .. "%";
			table["insert"](text, percent);
		end
		if (entry["key"]) then
			local header = entry["key"] == "AUTO" and "" or "Key: ";
			local key = header .. entry["key"];
			table["insert"](text, key);
		end
		
		text = table["concat"](text, " | ");
		widget:setText(text);
		widget:setId(entry["spellName"]);
	end
	if (config["showInfo"] and config["enabled"] and not FUGAS_RESTRICTED_MODE) then
		setupWidget("battlingStatus");
	end
	reIndex();
end

local doConfigCheck = function()
	local clean_config = {};
	clean_config["spells"] = {};
	clean_config["attackers"] = {};
	clean_config["enabled"] = true;
	clean_config["showInfo"] = true;
	clean_config["battlePos"] = widgetStartPosition;
	clean_config["selected_type"] = spellsOptions[1];

	for _, option in ipairs(spellsOptions) do
		clean_config["spells"][option] = {};
	end

	if (type(storage["shazamTyrFugasConfig"]) ~= "table") then
		storage["shazamTyrFugasConfig"] = clean_config;
	else
		if (storage["shazamTyrFugasConfig"]["selected_type"] == nil) then
			local config_copy = table["recursivecopy"](storage["shazamTyrFugasConfig"]);
			clean_config["showInfo"] = config_copy["showInfo"];
			
			for orangeMsg, entry in pairs(config_copy["spells"]) do
				entry["castSpellName"] = nil;
				entry["orangeMsg"] = orangeMsg;
				
				if (entry["selectedKeys"]) then
					entry["selectedKeys"] = table["concat"](entry["selectedKeys"], ", ");
				end
				
				if (entry["type"] == "Especiais") then
					entry["type"] = spellsTypes["DEFAULT"];
				end
				
				local spells = clean_config["spells"][entry["type"]];
				
				table["insert"](spells, entry);
				table["sort"](spells, function(a, b) return a["index"] < b["index"];	end)
			end
			
			storage["shazamTyrFugasConfig"] = clean_config;
		end
	end
	
	local data = storage["shazamTyrFugasConfig"]["spells"]["Especiais"];
	if (data ~= nil) then
		local new_data = {};
		for index, entry in ipairs(data) do
			local copy = table["recursivecopy"](entry);
			copy["type"] = spellsTypes["DEFAULT"];
			table["insert"](new_data, copy);
		end
		storage["shazamTyrFugasConfig"]["spells"]["Especiais"] = nil;
		storage["shazamTyrFugasConfig"]["spells"][spellsTypes["DEFAULT"]] = new_data;
	end
	
	config = storage["shazamTyrFugasConfig"];
end

local changeChildByIndex = function(sum)
	local widget = screenWidget["mainPanel"]["spellsList"];
	local child = widget:getFocusedChild();
	if (not child) then return; end
	local oldIndex = widget:getChildIndex(child);
	local newIndex = oldIndex + sum;
	local spells = config["spells"][config["selected_type"]];
	spells[oldIndex]["index"] = newIndex;
	spells[newIndex]["index"] = oldIndex;
	table["sort"](spells, function(a,b) return a["index"] < b["index"] end);
	doRefreshSpells();
	widget:getChildByIndex(newIndex):focus();
end

local checkLoadableConfigs = function()
	local base_dir = tr("/elfo_scripts/storage/%s", worldName);
	local files = g_resources["listDirectoryFiles"](base_dir);
	
	screenWidget["mainPanel"]["configList"]:clear();
	screenWidget["mainPanel"]["configList"]:addOption(characterName);
	for _, file in ipairs(files) do
		local file_without_extension = file:gsub(".lua", "");
		if (file_without_extension ~= characterName and file:ends(".lua")) then
			local path = base_dir .. "/" .. file;
			local content = g_resources["readFileContents"](path);
			local status, data = pcall(function() return load("return " .. content)() end);
			if (status and type(data) == "table" and data["especiaisConfig"]) then
				screenWidget["mainPanel"]["configList"]:addOption(file_without_extension);
			end
		end
	end
end

local loadConfig = function(name)
	checkLoadableConfigs();
	local base_dir = tr("/elfo_scripts/storage/%s", worldName);
	if (screenWidget["mainPanel"]["configList"]:isOption(name)) then
		local path = base_dir .. "/" .. name .. ".lua";
		if (g_resources["fileExists"](path)) then
			local content = g_resources["readFileContents"](path);
			local status, data = pcall(function() return load("return " .. content)() end);
			if (status and type(data) == "table" and data["especiaisConfig"]) then
				UI["ConfirmationWindow"]("Load Config", tr("Deseja utilizar a configura\231\227o de %s?", name), function()
					storage["shazamTyrFugasConfig"] = data["especiaisConfig"];
					doConfigCheck();
					doRefreshSpells();
				end)
			end
		end
	end
end

local addAnchors = function(widget)
	local isLabel = widget:getStyleName() == "Label";
	local hasAnyChild = registerWidget["mainPanel"]:getChildCount() ~= 1;
	local lastAnchor = (hasAnyChild or not isLabel) and "prev" or "parent";
	local lastDirection = (hasAnyChild or not isLabel) and AnchorBottom or AnchorTop;
	widget:addAnchor(AnchorRight, "parent", AnchorRight);
	widget:addAnchor(AnchorLeft, "parent", AnchorLeft);
	widget:addAnchor(AnchorTop, lastAnchor, lastDirection);
end

local createComboBox = function(data)
	local label = UI["createWidget"]("Label", registerWidget["mainPanel"]);
	addAnchors(label);
	label:setMarginTop(7);
	label:setMarginLeft(10);
	label:setText(data["title"]);
	local comboBox = UI["createWidget"]("ComboBox", registerWidget["mainPanel"]);
	addAnchors(comboBox);
	comboBox:setMarginLeft(10);
	comboBox:setMarginRight(10);
	for _, value in ipairs(data["values"]) do
		comboBox:addOption(value);
	end
	comboBox:setId(data["var_name"]);
	comboBox:setCurrentOption(data["text"]);
	comboBox["menuScroll"] = true;
	comboBox["menuScrollStep"] = 10;
end

local createTextEdit = function(data)
	local label = UI["createWidget"]("Label", registerWidget["mainPanel"]);
	addAnchors(label);
	label:setMarginTop(7);
	label:setMarginLeft(10);
	label:setText(data["title"]);
	local textEdit = UI["createWidget"]("TextEdit", registerWidget["mainPanel"]);
	addAnchors(textEdit);
	textEdit:setMarginLeft(10);
	textEdit:setMarginRight(10);
	textEdit:setText(data["text"]);
	textEdit:setId(data["var_name"]);
end

local createScrollBar = function(data)
	local label = UI["createWidget"]("Label", registerWidget["mainPanel"]);
	addAnchors(label);
	label:setMarginTop(7);
	label:setMarginLeft(10);
	label:setText(data["title"]);
	local scrollBar = UI["createWidget"]("HorizontalScrollBar", registerWidget["mainPanel"]);
	addAnchors(scrollBar);
	scrollBar:setMarginLeft(10);
	scrollBar:setMarginRight(10);
	scrollBar["onValueChange"] = function(widget, value)
		local suffix = "s";
		if (data["range"]["min"] == 1) then
			suffix = "";
		elseif (data["range"]["max"] == 100) then
			suffix = "%";
		end
		widget:setText(value .. suffix);
	end
	scrollBar:setMinimum(data["range"]["min"]);
	scrollBar:setMaximum(data["range"]["max"]);
	scrollBar:setValue(data["text"] or data["range"]["min"]);
	scrollBar:onValueChange(scrollBar:getValue());
	scrollBar:setId(data["var_name"]);
end

doRegisterSpell = function(entry)
	screenWidget:hide();
	registerWidget:show();
	registerWidget["mainPanel"]:destroyChildren();
	for _, _data in ipairs(displayOptions) do
		local data = table["copy"](_data);
		if (data["ignore"] ~= nil) then
			if (table["find"](data["ignore"], config["selected_type"])) then
				break;
			end
		end
		
		if (data["skip"] ~= nil) then
			if (table["find"](data["skip"], config["selected_type"])) then
				goto continue;
			end
		end
		local exclusive_data = data[config["selected_type"]];
		if (exclusive_data ~= nil) then
			if (data["range"] ~= nil and exclusive_data["range"] == nil) then
				data["range"] = nil;
			end
			for key, value in pairs(exclusive_data) do
				data[key] = value;
			end
		end
		
		if (data["default_value"] ~= nil) then
			data["text"] = entry[data["default_value"]];
		end
		
		if (entry[data["var_name"]] ~= nil) then
			data["text"] = entry[data["var_name"]];
		end
		
		if (data["var_name"] == "key") then
			data["values"] = getAllKeys();
		end		
		
		if (data["values"]) then
			createComboBox(data);
			goto continue;
		end
	
		
		if (data["range"]) then
			createScrollBar(data);
			goto continue;
		end
		createTextEdit(data);
		::continue::
		
	end
end

local checkKeyPress = function(widget, pressed)
	if (widget["pressed"] ~= pressed) then
		local setMouseMouveFunction = not pressed and doRemoveMouseMove or doSetMouseMove;
		setMouseMouveFunction(widget["entry"]);
	end
end

local doSetWidgetContent = function(widget)
	local entry = widget["entry"];
	
	if (entry == "battlingStatus") then
		return setBattleStatus();
	end
	
	local time = os["time"]();
	
	
	local color = "green";
	local text = {tr("%s:", (entry["showMsg"] or entry["spellName"]):ucwords()), "0s"};
	
	local activeTime = (entry["activeTime"] or 0) - time;
	local cooldownTime = (entry["cooldownTime"] or 0) - time;
	local deathRemaining = (entry["death_max_count"] or 0) - (entry["death_count"] or 0);
	

	
	if (activeTime >= 0) then
		local value = tr("%ds", activeTime);
		color = "orange";
		text[2] = value;
		
		if (deathRemaining > 0) then
			local value = "[" .. deathRemaining .. "]";
			text[3] = value;
		end
	elseif (cooldownTime >= 0) then
		local value = tr("%ds", cooldownTime);
		color = "red";
		text[2] = value;
	else
		entry["cooldownTime"] = nil;
		entry["activeTime"] = nil;
	end
	
	
	text = table["concat"](text, " ");
	if (widget["_color"] ~= color or widget["_text"] ~= text) then
		widget:setColor(color);
		widget:setText(text);
		
		widget["_text"] = text;
		widget["_color"] = color;
	end
end

botWidget["switch"]["onClick"] = function()
	local status = not botWidget["switch"]:isOn();
	config["enabled"] = status;
	botWidget["switch"]:setOn(status);
	doRefreshSpells();
end

botWidget["config"]["onClick"] = function()
	screenWidget:show();
end

screenWidget["onEscape"] = function()
	screenWidget:hide();
	gameRootPanel:focus();
end

registerWidget["backButton"]["onClick"] = function()
	registerWidget:hide();
	screenWidget:show();
end

infoCheckBox["onCheckChange"] = function(widget, checked)
	config["showInfo"] = checked;
	doRefreshSpells();
end

screenWidget["mainPanel"]["configList"]["onOptionChange"] = function(widget, option)
	if (option == characterName) then return; end
	loadConfig(option);
	screenWidget["mainPanel"]["configList"]:setOption(characterName);
end

screenWidget["mainPanel"]["typeList"]["onOptionChange"] = function(widget, option)
	if (config == nil) then return; end
	config["selected_type"] = option;
	doRefreshSpells();
end

screenWidget["mainPanel"]["spellsList"]["onMousePress"] = function(widget, pos)
	moveStart = now;
end

screenWidget["mainPanel"]["spellsList"]["onMouseRelease"] = function(widget, pos)
	if (not moveStart) then 
		return; 
	end
	if (now - moveStart < 30) then 
		return; 
	end
	local changeChild = widget:getFocusedChild();
	if (not changeChild) then 
		return; 
	end
	local selectedChild = widget:getChildByPos(pos);
	if (not selectedChild or changeChild == selectedChild) then 
		return; 
	end
	
	local changeWidgetIndex = widget:getChildIndex(changeChild);
	local selectedWidgetIndex = widget:getChildIndex(selectedChild);
	
	local diff = math["abs"](selectedWidgetIndex - changeWidgetIndex);
	local step = changeWidgetIndex > selectedWidgetIndex and -1 or 1;
	
	for i = 1, diff do
		changeChildByIndex(step);
	end
	
end

screenWidget["mainPanel"]["addButton"]["onClick"] = function()
	local spellName = screenWidget["mainPanel"]["nameField"]:getText():lower():trim();
	local spells = config["spells"][config["selected_type"]];
	if (table["size"](spells) == spellsLimits[config["selected_type"]]) then
		warn("Limite FREE Atingido");
		screenWidget["mainPanel"]["message"]:setColor("red");
		return;
	end
			
		
	
	if (spellName:len() == 0) then
		warn("Insira uma magia!");
		return;
	end

	for _, entry in ipairs(spells) do
		if (entry["spellName"] == spellName) then
			error("Essa magia j\225 existe");
			return;
		end
	end
	
	doRegisterSpell({spellName=spellName});
end

registerWidget["addButton"]["onClick"] = function()
	local children = registerWidget["mainPanel"]:getChildren();
	local spellName = screenWidget["mainPanel"]["nameField"]:getText():trim():lower();
	local spells = config["spells"][config["selected_type"]];
	local entry = {
		spellName=spellName, 
		enabled=true,
		type = config["selected_type"],
		index = table["size"](spells) + 1,
		spellTime=table["find"](spellsDefaultShowTime, config["selected_type"])
	};
	for _, child in ipairs(children) do
		local value;
		local var_name = child:getId();
		local styleName = child:getStyleName();
		if (styleName == "ComboBox") then
			value = child:getCurrentOption()["text"];
			if (value == "None") then
				value = nil;
			end
		elseif (styleName == "TextEdit") then
			local text = child:getText():trim():lower();
			if (text:len() >= 1) then
				value = text;
			end
		elseif (styleName == "HorizontalScrollBar") then
			value = child:getValue();
		end
		if (value ~= nil) then
			entry[var_name] = value;
		end
	end
	
	if (entry["key"] == "AUTO" and (tonumber(entry["percent"]) or 0) > 0) then
		entry["key"] = nil;
	end
	
	if (entry["percent"] == 0) then
		entry["percent"] = nil;
	end
	
	
	table["insert"](spells, table["copy"](entry));
	
	doRefreshSpells();
	screenWidget:show();
	registerWidget:hide();
	screenWidget["mainPanel"]["nameField"]:clearText();
end

local getFugaSpellData = function(name)
	name = name:trim():lower();
	for _, entries in pairs(config["spells"]) do
		for _, entry in pairs(entries) do
			if (entry["spellName"] == name) then
				return entry;
			end
		end
	end
end

warn = function(msg)
	local widget = screenWidget["mainPanel"]["message"];
	widget["added"] = now + 3000;
	
	widget:setText(msg);
	widget:setColor("yellow");
end


for _, option in ipairs(spellsOptions) do
	screenWidget["mainPanel"]["typeList"]:addOption(option);
	spellsLimits[option] = math["huge"];
end

for index, key in ipairs(wasdKeys) do
	local currentValue = stackDirections[key];
	if (index <= 4) then
		local arrowKey = arrowKeys[index];
		stackDirections[arrowKey] = currentValue;
	end
	
	local numpadKey = numpadKeys[index];
	stackDirections[numpadKey] = currentValue;
end

if (FUGAS_RESTRICTED_MODE) then
	spellsLimits[spellsTypes["ESCAPE"]] = 2;
	spellsLimits[spellsTypes["TRAP"]] = 2;
	spellsLimits[spellsTypes["STACK"]] = 0;
	spellsLimits[spellsTypes["STRAIGHT"]] = 0;
	spellsLimits[spellsTypes["BUFF"]] = 1;
end


doConfigCheck();
screenWidget["mainPanel"]["typeList"]:setCurrentOption(config["selected_type"]);
screenWidget["mainPanel"]["configList"]["menuScroll"] = true;
screenWidget["mainPanel"]["configList"]["mouseScroll"] = false;
screenWidget["onEnter"] = screenWidget["mainPanel"]["addButton"]["onClick"];
screenWidget["mainPanel"]["closeButton"]["onClick"] = screenWidget["onEscape"];



screenWidget:hide()
registerWidget:hide();
checkLoadableConfigs();
doRefreshSpells();


if (config["enabled"]) then
	botWidget["switch"]:setOn(config["enabled"]);
end

if (config["showInfo"]) then
	infoCheckBox:setChecked(true);
end


onCreatureHealthPercentChange(function(creature, percent)
	if (creature ~= player) then
		return;
	end
	
	if (percent == nil) then
		return;
	end
	
	local diff = percent - oldPercent;
	oldPercent = percent;
	if (diff < 85) then
		return;
	end
	
	for spellName, entry in pairs(config["spells"]) do
		if (entry["type"] == spellsTypes["ESCAPE"]) then
			if (not entry["death_max_count"]) then
				entry["activeTime"] = nil;
			else
				entry["death_count"] = (entry["death_count"] or 0) + 1;
				if (entry["death_count"] >= entry["death_max_count"]) then
					entry["activeTime"] = nil;
					entry["death_count"] = nil;
				end
			end
		end
	end
end)


onTalk(function(name, level, mode, text)
	if (mode ~= 44) then return; end
	if (name ~= characterName) then return; end
	
	text = text:trim():lower();
	for _, data in pairs(config["spells"]) do
		for _, entry in ipairs(data) do
			if (entry["orangeMsg"] == text and (entry["cooldownTime"] or 0) < os["time"]()) then
			
				local cooldownTotal = (entry["cooldownTotal"] or 0);
				if (cooldownTotal > 0) then
					entry["cooldownTime"] = os["time"]() + cooldownTotal;
				end
				
				if (entry["activeTotal"] and entry["activeTotal"] > 0) then
					entry["activeTime"] = os["time"]() + entry["activeTotal"];
				end
				
				if (stackData and table["equal"](entry, stackData["entry"])) then
					doCancelStack();
				end
				
				break;
			end
		end
	end

end)

onTextMessage(function(mode, text)
	if (not text:find("attack by")) then return; end
	text = text:sub(9);
	
	local getSpectators = getSpectators;
	for _, spec in ipairs(getSpectators()) do
		if (spec:isPlayer()) then
			local specName = spec:getName();
			if (text:find(specName)) then
				config["attackers"][specName] = os["time"]() + 1;
				break
			end
		end
	end
end)

onTextMessage(function(mode, text)
	if (worldName ~= "NtoUltimate") then return; end
	if (text:find("jutsu foi selado")) then
		local time = tonumber(text:match("%d+"));
		if (time ~= nil) then
			for _, entry in pairs(config["spells"][spellsTypes["BUFF"]]) do
				entry["cooldownTime"] = os["time"]() + time;
			end
		end
	end
end)

if (modules["_G"]["buffData"] == nil) then
	modules["_G"]["buffData"] = {};
end
local buffData = modules["_G"]["buffData"];
macro(1, function(self)
	if (worldName ~= "NtoUltimate") then
		self:setOff();
		return;
	end
	
	local currentMedicine = player:getSkillLevel(3);
	
	if (buffData["medicineLast"] ~= nil and buffData["medicineLast"] - currentMedicine > 50) then
		local time = os["time"]() + 5;
		for _, entry in pairs(config["spells"][spellsTypes["BUFF"]]) do
			local cooldownTime = (entry["cooldownTime"] or 0);
			if (cooldownTime > time) then
				entry["cooldownTime"] = nil;
			end
		end
	end
	
	buffData["medicineLast"] = currentMedicine;
	
	
		
		
	
	

	
		
	
	
	
		
	
end)

macro(1, function(self)
	if (worldName ~= "NtoUltimate") then
		self:setOff();
		return;
	end
	
	
	local spellData = getFugaSpellData("Kawarimi no jutsu");
	if (spellData == nil) then return; end
	local time = os["time"]();
	
	if (spellData["setActiveTime"]) then 
		local cooldownTime = (spellData["cooldownTime"] or 0);
		if (cooldownTime < time) then
			spellData["setActiveTime"] = nil;
		end
		return; 
	end
	
	local activeTime = (spellData["activeTime"] or 0);
	if (activeTime < time) then
		return;
	end
	
	local playerPos = player:getPosition();
	for x = -1, 1 do
		for y = -1, 1 do
			local tile = g_map["getTile"]({x=playerPos["x"]+x, y=playerPos["y"]+y, z=playerPos["z"]});
			if (tile ~= nil) then
				for _, item in ipairs(tile:getItems()) do
					if (item:getId() == 5945) then
						spellData["setActiveTime"] = true;
						spellData["activeTime"] = time + 4;
						return;
					end
				end
			end
		end
	end
end)

macro(1, function()
	local widget = screenWidget["mainPanel"]["message"];
	
	if (widget["added"]) then
		if (widget["added"] < now) then
			widget["added"] = nil;
		elseif (widget:isHidden()) then
			widget:show();
		end
	end
	
	
	if (widget["added"] == nil) then
		if (widget:isVisible()) then
			widget:hide();
		end
		return;
	end
end)

macro(100, function()
	local currentTime = os["time"]();
	for name, time in pairs(config["attackers"]) do
		if (time < currentTime) then
			config["attackers"][name] = nil;
		end
	end
end)

macro(50, function()
	if (not config["enabled"]) then return; end
	if (isInPz()) then return; end
	
	if (stackData ~= nil and not g_mouse["isPressed"](3)) then
		doCancelStack();
	end
	
	if (stackData ~= nil) then
		
		
			
		
		doStack();
	end
	
	for _, type in ipairs(spellsOptions) do
		doSpellCast(type);
	end
end)

local widgetPos;
macro(1, function()
	if (widgetPos ~= nil) then
		local widgets = {screenWidget, registerWidget};
		for _, widget in ipairs(widgets) do
			if (widget:isHidden()) then
				widget:breakAnchors();
				widget:setPosition(widgetPos);
			end
		end
		widgetPos = nil;
	end
	if (screenWidget:isVisible()) then
		widgetPos = screenWidget:getPosition();
	elseif (registerWidget:isVisible()) then
		widgetPos = registerWidget:getPosition();
	end
end)


macro(storage["scrollBars"] and storage["scrollBars"]["macroDelay"] or 50, function()
	if (not config["enabled"]) then return; end
	local dragKeyPressed = isDragKeyPressed();

	local widgets = getAllScreenWidgets();
	for _, widget in ipairs(widgets) do
		checkKeyPress(widget, dragKeyPressed);
		doSetWidgetContent(widget);
	end
end)

-- Fugas independente: sem registro em tyrBot.
