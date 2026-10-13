local tab = getTab("Others") and "Others";
if (tab) then
	setDefaultTab("Others");
end
local TravelSystem = {};

string["capitalize"] = {[""]=true, [":"]=true, [" "]=true};
string["ucwords"] = function(self)
	local capitalize = string["capitalize"];
	local result = {};
	for i = 1, #self do
		local capitalizeNext;
		local char = self:sub(i, i);
		local previous = self:sub(i - 1, i - 1);
		if (capitalize[previous]) then
			capitalizeNext = true;
		end
		result[i] = capitalizeNext and char:upper() or char:lower();
	end
	return table["concat"](result);
end

TravelSystem["switch"] = setupUI("Panel\n  height: 17\n\n  BotSwitch\n    id: macro\n    anchors.top: parent.top\n    anchors.left: parent.left\n    text-align: center\n    width: 130\n    !text: tr(\"Travel System\")\n\n  Button\n    id: configs\n    anchors.top: prev.top\n    anchors.left: prev.right\n    anchors.right: parent.right\n    margin-left: 3\n    height: 17\n    text: Config\n");

TravelSystem["configWindow"] = setupUI("MainWindow\n  size: 400 200\n  !text: tr(\"Travel System - Shazam Scripts\")\n  color: #A020F0\n  @onEscape: self:hide();\n  @onSetup: self:hide();\n\n  Panel\n    id: mainPanel\n    image-source: /images/ui/panel_flat\n    anchors.top: parent.top\n    anchors.bottom: parent.bottom\n    anchors.left: parent.left\n    anchors.right: parent.right\n    image-border: 6\n\n    Label\n      !text: tr(\"NPCS NAME\")\n      anchors.left: parent.left\n      anchors.top: parent.top\n      margin-left: 25\n      color: #A020F0\n\n    TextList\n      id: npcList\n      anchors.left: parent.left\n      anchors.top: prev.bottom\n      size: 120 100\n      image-border: 3\n      image-source: /images/ui/textedit\n      vertical-scrollbar: npcListScroll\n\n    VerticalScrollBar\n      id: npcListScroll\n      anchors.top: npcList.top\n      anchors.bottom: npcList.bottom\n      anchors.right: npcList.right\n      step: 10\n      pixels-scroll: true\n\n    Button\n      id: up\n      !text: tr(\"^\")\n      tooltip: Mover para cima\n      anchors.left: npcList.right\n      anchors.top: npcList.top\n      size: 15 15\n      @onSetup: self:hide();\n\n    Button\n      id: down\n      !text: tr(\"^\")\n      tooltip: Mover para baixo\n      anchors.left: npcList.right\n      anchors.top: up.bottom\n      size: 15 15\n      margin-top: 10\n      rotation: 180\n      @onSetup: self:hide();\n\n    Button\n      id: addButton\n      text: Add\n      anchors.top: npcList.bottom\n      anchors.left: parent.left\n      size: 35 20\n      margin-top: 5\n\n    TextEdit\n      id: npcName\n      anchors.top: prev.top\n      anchors.right: npcList.right\n      anchors.left: prev.right\n      height: 20\n\n    Button\n      id: closeButton\n      !text: tr(\"Close\")\n      anchors.right: parent.right\n      anchors.bottom: parent.bottom\n      @onClick: self:getParent():getParent():hide();\n", g_ui["getRootWidget"]());

local worldName = g_game["getWorldName"]();
local npcList = TravelSystem["configWindow"]["mainPanel"]["npcList"];
local addButton = TravelSystem["configWindow"]["mainPanel"]["addButton"];
local upButton = TravelSystem["configWindow"]["mainPanel"]["up"];
local downButton = TravelSystem["configWindow"]["mainPanel"]["down"];
local npcNameTextEdit = TravelSystem["configWindow"]["mainPanel"]["npcName"];

if (type(storage["TravelSystem"]) ~= "table") then
	storage["TravelSystem"] = {};
end

local config = storage["TravelSystem"];
if (type(config[worldName]) ~= "table") then
	if (table["size"](config) == 0) then
		storage["TravelSystem"] = {
			["minoru"] = {index = 1};
			["gate keaper"] = {index = 2};
		};
		config = storage["TravelSystem"];
	end
else
	config = config[worldName];
end

TravelSystem["macro"] = TravelSystem["switch"]["macro"];
TravelSystem["configs"] = TravelSystem["switch"]["configs"];

TravelSystem["configs"]["onClick"] = function()
	TravelSystem["configWindow"]:show();
	TravelSystem["configWindow"]:raise();
	TravelSystem["configWindow"]:focus();
end;

TravelSystem["macro"]["onClick"] = function()
	config["active"] = not config["active"];
	TravelSystem["macro"]:setOn(config["active"]);
end

TravelSystem["macro"]:setOn(config["active"]);

addButton["onClick"] = function()
	local npcName = npcNameTextEdit:getText():trim():lower();
	if (npcName:len() == 0) then
		error("Coloque um Nome");
		return;
	end
	if (config[npcName]) then
		error("Já existe.");
		return;
	end
	config[npcName] = { index = table["size"](config) + 1 };
	npcNameTextEdit:clearText();
	TravelSystem["refreshList"]();
end

local widgetEntry = "UIWidget\n  background-color: alpha\n  text-offset: 3 1\n  focusable: true\n  height: 16\n  font: verdana-11px-rounded\n  text-align: left\n\n  $focus:\n    background-color: #00000055\n\n  Button\n    id: remove\n    !text: tr('X')\n    anchors.right: parent.right\n    anchors.verticalCenter: parent.verticalCenter\n    width: 14\n    height: 14\n    margin-right: 15\n    text-align: center\n    text-offset: 0 1\n    tooltip: Remover o nome da lista.\n";

local removeEntry = function(widget)
	local npcName = widget:getId();
	local entry = config[npcName];
	if (not entry) then
		widget = widget:getParent();
		npcName = widget:getId();
	end
	npcList:removeChild(widget);
	npcNameTextEdit:setText(npcName:ucwords());
	config[npcName] = nil;
end

local setupEntry = function(name)
	local widget = setupUI(widgetEntry, npcList);
	widget:setId(name);
	widget:setText(name:ucwords());
	widget["onDoubleClick"] = removeEntry;
	widget["remove"]["onClick"] = removeEntry;
end

local moveWidgetByDir = function(widget, dir)
	local entry = config[widget:getId()];
	local oldIndex = entry["index"];
	local index = oldIndex + dir;
	local oldChild = npcList:getChildByIndex(index);
	local oldEntry = config[oldChild:getId()];
	npcList:moveChildToIndex(widget, index);
	entry["index"] = index;
	oldEntry["index"] = oldIndex;
	npcList:onChildFocusChange();
end

upButton["onClick"] = function()
	local child = npcList:getFocusedChild();
	moveWidgetByDir(child, -1);
end

downButton["onClick"] = function()
	local child = npcList:getFocusedChild();
	moveWidgetByDir(child, 1);
end

npcList["onChildFocusChange"] = function(widget)
	upButton:hide(); downButton:hide();
	local child = widget:getFocusedChild();
	if (not child) then return; end
	upButton:show(); downButton:show();
	if (widget:getFirstChild() == child) then upButton:hide(); end
	if (widget:getLastChild() == child) then downButton:hide(); end
end

TravelSystem["refreshList"] = function()
	npcList:destroyChildren();
	if (table["size"](config) == 0) then return; end
	local sorted = {};
	for name, info in pairs(config) do
		if (type(info) == "table") then
			local entry = table["copy"](info);
			entry["npcName"] = name;
			table["insert"](sorted, entry);
		end
	end
	table["sort"](sorted, function(a, b) return a["index"] < b["index"]; end);
	for _, entry in ipairs(sorted) do setupEntry(entry["npcName"]); end
end
TravelSystem["refreshList"]();

local NPC_LIST = {};
local nextNpcRefresh = 0
local refreshNpcList = function()
	if not config["active"] then NPC_LIST = {}; return; end
	-- PERF: onCreaturePositionChange dispara para qualquer criatura. Limita rescans em rajadas.
	if nextNpcRefresh > now then return end
	nextNpcRefresh = now + 200
	local npcList = {};
	for _, spec in ipairs((ShazamCore and ShazamCore.getSpectators(false, 120) or getSpectators())) do
		if (spec:isNpc()) then table["insert"](npcList, spec); end
	end
	NPC_LIST = npcList;
end
refreshNpcList();
onCreaturePositionChange(refreshNpcList);

local getBestNpc = function()
	local bestNpc;
	local playerPos = player:getPosition();
	for _, spec in ipairs(NPC_LIST) do
		local specName = spec:getName():trim():lower();
		if (config[specName]) then
			local specPos = spec:getPosition();
			if (specPos ~= nil) then
				local distance = getDistanceBetween(playerPos, specPos);
				if (distance <= 3) then
					if (not bestNpc or distance < bestNpc["distance"]) then
						bestNpc = spec;
					end
				end
			end
		end
	end
	return bestNpc;
end

NPC["say"] = function(text)
	return g_game["talkChannel"](11, 0, text);
end

local scheduleNpcSay = function(text, delay)
	delay = delay or 500;
	schedule(delay, function() NPC["say"](text); end);
end

local talkingNpc;
local PositionChangeCallback = function(newPos, oldPos)
	if (talkingNpc) then 
		local specPos = talkingNpc:getPosition();
		if (specPos and specPos["z"] == newPos["z"]) then
			local distance = getDistanceBetween(specPos, newPos);
			if (distance > 3) then
				talkingNpc = nil;
				NPC["say"]("bye");
				TravelSystem["cityWindow"]:hide();
			end
		else
			TravelSystem["cityWindow"]:hide();
			talkingNpc = nil;
		end
		return; 
	end
	if (TravelSystem["cityWindow"]) then TravelSystem["cityWindow"]:hide(); end
	local bestNpc = getBestNpc();
	if (not bestNpc) then return; end
	talkingNpc = bestNpc;
end
PositionChangeCallback(player:getPosition());
onPlayerPositionChange(PositionChangeCallback);

local getHighlitedValues = function(text)
	local values = {};

	-- Formato tradicional: {Konoha}, {SunaGakure}, etc.
	for value in text:gmatch("{(.-)}") do
		value = value:trim();
		if (value:len() > 0) then
			table["insert"](values, value);
		end
	end

	if (#values > 0) then
		return values;
	end

	-- Alguns servidores/NPCs (ex.: Minoru) enviam:
	-- "I can take you to Konoha, SunaGakure, ..." sem { }.
	local lowerText = text:lower();
	local marker = "i can take you to";
	local startPos = lowerText:find(marker, 1, true);
	if (startPos) then
		local cityText = text:sub(startPos + #marker):trim();
		-- Remove pontuacao somente do final da mensagem.
		cityText = cityText:gsub("[%s%.%!%?]+$", "");

		for city in cityText:gmatch("[^,]+") do
			city = city:trim();
			if (city:len() > 0) then
				table["insert"](values, city);
			end
		end
	end

	return values;
end

local NPC_TALK_MODE = 51;
onTalk(function(name, level, mode, text)
	if (mode ~= NPC_TALK_MODE) then return; end
	name = name:trim():lower();
	if (name ~= settingNpc) then return; end
	local npcConfig = config[name];
	
	if (not npcConfig["talkActions"]) then
		npcConfig["talkActions"] = {"hi"};
	end
	
	local values = getHighlitedValues(text);
	if (#values <= 3 and #values > 0) then
		table["insert"](npcConfig["talkActions"], values[1]);
		scheduleNpcSay(values[1]);
	elseif (#values > 3) then
		local first_city = g_game["getWorldName"]() == "Katon" and ("takumi no sato"):ucwords() or nil;
		npcConfig["cities"] = {first_city};
		for _, city in ipairs(values) do
			table["insert"](npcConfig["cities"], city:ucwords());
		end
		table["sort"](npcConfig["cities"], function(a, b) return a < b; end)
		NPC["say"]("bye");
		settingNpc = nil;
	end
end);

TravelSystem["cityWindow"] = setupUI("MainWindow\n  size: 560 200\n  !text: tr(\"Travel System - Shazam Scripts\")\n  color: #A020F0\n  @onEscape: self:hide();\n  @onSetup: self:hide();\n\n  Panel\n    id: mainPanel\n    image-source: /images/ui/panel_flat\n    anchors.top: parent.top\n    anchors.bottom: parent.bottom\n    anchors.left: parent.left\n    anchors.right: parent.right\n    image-border: 6\n", g_ui["getRootWidget"]());

local firstRowButton = "Button\n  anchors.left: parent.left\n  anchors.top: parent.top\n";
local cityButtonWidget = "Button\n  anchors.top: prev.bottom\n  anchors.left: prev.left\n";

local onClick = function(widget)
	local city = widget:getId();
	NPC["say"](city);
	scheduleNpcSay("yes");
	TravelSystem["cityWindow"]:hide();
	TravelSystem["delay"] = now + 1500;
end

local setupWindow = function(cities)
	TravelSystem["cityWindow"]:show();
	local width = TravelSystem["cityWindow"]["width"];
	if (width) then TravelSystem["cityWindow"]:setWidth(width); end
	PositionChangeCallback(player:getPosition());
	TravelSystem["cityWindow"]["mainPanel"]:destroyChildren();
	local windowWidth = TravelSystem["cityWindow"]:getWidth();
	TravelSystem["cityWindow"]["width"] = windowWidth;
	
	for index, city in ipairs(cities) do
		local firstRow = index % 4 == 1;
		local widget = setupUI(firstRow and firstRowButton or cityButtonWidget, TravelSystem["cityWindow"]["mainPanel"]);
		widget:setMarginTop(10); widget:setHeight(25); widget:setWidth(90);
		if (firstRow) then
			widget:setMarginLeft((index - 1) * 25);
			local widgetPos = widget:getWidth() + widget:getX();
			local width = TravelSystem["cityWindow"]:getWidth();
			local winPos = width + TravelSystem["cityWindow"]:getPosition()["x"];
			local diff = widgetPos - winPos;
			if (diff ~= 0) then TravelSystem["cityWindow"]:setWidth(width + diff + 15); end
		end
		widget:setText(city:sub(1, 12));
		widget:setId(city);
		widget["onClick"] = onClick;
	end
end

macro(50, function(self)
	if (not config["active"]) then return; end
	if (not talkingNpc) then return; end
	if (settingNpc) then return; end
	if (TravelSystem["delay"] and TravelSystem["delay"] >= now) then return; end
	
	local npcName = talkingNpc:getName():trim():lower();
	local npcConfig = config[npcName];
	if (not npcConfig) then return; end
	
	local talkActions = npcConfig["talkActions"];
	local cities = npcConfig["cities"];
	
	if (not talkActions or not cities) then
		settingNpc = npcName;
		g_game["follow"](talkingNpc);
		scheduleNpcSay("hi");
		return;
	end
	if (not TravelSystem["cityWindow"]:isHidden()) then return; end
	NPC["say"]("bye");
	for index, talkAction in ipairs(npcConfig["talkActions"]) do
		scheduleNpcSay(talkAction, index * 500);
	end
	local window_delay = (table["size"](npcConfig["talkActions"]) + 1) * 500;
	schedule(window_delay, function() setupWindow(npcConfig["cities"]); end);
	delay(window_delay + 500);
end);


-- Atalhos: registra esta macro para aparecer na janela Atalhos (aba User).
do
  local g = (type(_G) == "table" and _G) or modules["_G"]
  g.configData = g.configData or {}
  g.configData["travelSystem"] = {macro = TravelSystem["macro"]}
end
