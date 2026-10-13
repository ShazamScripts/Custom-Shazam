lblInfo= UI.Label("-- PVP --")
lblInfo:setColor("yellow")


-- Combo Macro - versão limpa e independente
-- Independente de loaders externos; usa apenas a API nativa da Custom.
-- Mantém configuração de combos, calibração, teste de combinações e persistência.

local configData = (type(_G) == "table" and type(_G.configData) == "table") and _G.configData or nil
if configData then
    configData["combo"] = configData["combo"] or {}
end

local unpack = (_G or modules["_G"])["unpack"]
local addEvent = (_G or modules["_G"])["addEvent"]
local scheduleEvent = (_G or modules["_G"])["scheduleEvent"]

local AnchorTop = 1
local AnchorBottom = 2
local AnchorLeft = 3
local AnchorRight = 4


local displayOptions = {
	{
		title = "Mensagem em laranja",
		var_name = "orangeMsg",
		default_value = "spellName"
	},
	{
		title = "Dist\226ncia da magia (sqm)",
		var_name = "distance",
		range = {min=0,max=10},
		step = 1
	},
	{
		title = "Cooldown da magia",
		var_name = "cooldownTotal",
		range = {min=0,max=60000},
		step = 50
	}
};


local spellsOptions = {"Combo 1", "Combo 2", "Combo 3", "Combo 4", "Combo 5"};
local worldName = g_game["getWorldName"]():trim();
local characterName = g_game["getCharacterName"]();
local gameRootPanel = g_ui["getRootWidget"]():recursiveGetChildById("gameRootPanel");

local persistCombo = function()
	if type(ShazamPersistNow) == "function" then
		ShazamPersistNow()
	elseif type(saveConfig) == "function" then
		saveConfig()
	end
end

local warn;
local config;
local moveStart;
local checkSpells;
local doRegisterSpell;

local spellWidget = "UIWidget\n  background-color: black\n  padding: 0 5\n  text-auto-resize: true\n";

local botWidget = setupUI("Panel\n  height: 17\n\n  BotSwitch\n    id: switch\n    anchors.top: parent.top\n    anchors.left: parent.left\n    text-align: center\n    width: 130\n    !text: tr(\"Combo\")\n\n  Button\n    id: configButton\n    anchors.top: prev.top\n    anchors.bottom: prev.bottom\n    anchors.left: prev.right\n    anchors.right: parent.right\n    text: Config\n");

local entryWidget = "Label\n  background-color: alpha\n  text-offset: 18 4\n  focusable: true\n  height: 16\n  font: verdana-11px-rounded\n\n  CheckBox\n    id: enabled\n    !tooltip: tr(\"Ativar\")\n    anchors.left: parent.left\n    anchors.verticalCenter: parent.verticalCenter\n    width: 15\n    height: 15\n    margin-top: 2\n    margin-left: 3\n\n  $focus:\n    background-color: #00000055\n\n  Button\n    id: remove\n    !text: tr('x')\n    anchors.right: parent.right\n    margin-right: 15\n    text-offset: 1 0\n    width: 15\n    height: 15\n"

local screenWidget = setupUI("MainWindow\n  size: 320 360\n  !text: tr(\"Combo by Shazam Scripts\")\n  color: white\n\n  Panel\n    id: mainPanel\n    image-source: /images/ui/panel_flat\n    anchors.top: parent.top\n    anchors.bottom: parent.bottom\n    anchors.left: parent.left\n    anchors.right: parent.right\n    image-border: 6\n\n    TextList\n      id: spellsList\n      image-source: /images/ui/textedit\n      anchors.centerIn: parent\n      anchors.left: parent.left\n      anchors.right: parent.right\n      margin-top: 20\n      margin-left: 10\n      margin-right: 10\n      image-border: 6\n      height: 180\n      vertical-scrollbar: spellsListScroll\n\n    VerticalScrollBar\n      id: spellsListScroll\n      anchors.top: spellsList.top\n      anchors.bottom: spellsList.bottom\n      anchors.right: spellsList.right\n      step: 10\n      pixels-scroll: true\n\n\n    TextEdit\n      id: nameField\n      tooltip: Nome da Magia\n      anchors.bottom: spellsList.top\n      anchors.left: parent.left\n      margin-bottom: 5\n      margin-left: 10\n      width: 185\n\n    Label\n      !text: tr(\"Nome da Magia\")\n      anchors.bottom: prev.top\n      anchors.left: prev.left\n      margin-left: 50\n      margin-bottom: 2\n\n    ComboBox\n      id: configList\n      anchors.top: parent.top\n      anchors.left: spellsList.left\n      text-offset: 3 0\n      margin-top: 5\n      margin-right: 5\n      width: 122\n\n    ComboBox\n      id: typeList\n      anchors.top: prev.top\n      anchors.left: prev.right\n      anchors.right: spellsList.right\n      text-offset: 3 0\n      margin-left: 5\n\n    Button\n      id: addButton\n      !text: tr(\"Adicionar\")\n      anchors.top: nameField.top\n      anchors.bottom: nameField.bottom\n      anchors.left: nameField.right\n      anchors.right: spellsList.right\n      margin-left: 5\n\n    Label\n      anchors.top: spellsList.bottom\n      anchors.right: parent.right\n      anchors.left: parent.left\n      id: message\n      margin-top: 2\n      text-auto-resize: true\n      text-align: center\n      text-wrap: true\n\n    Button\n      id: closeButton\n      !text: tr(\"Fechar\")\n      anchors.top: prev.bottom\n      anchors.right: typeList.right\n      width: 122\n      margin-left: 5\n      margin-bottom: 1\n\n    UIButton\n      id: testButton\n      !text: tr(\"Testar Combo\")\n      anchors.top: prev.top\n      anchors.bottom: prev.bottom\n      anchors.right: prev.left\n      anchors.left: spellsList.left\n      margin-top: 1\n      margin-bottom: 1\n      margin-right: 5\n      color: white\n      background-color: #A020F0\n\n      $hover:\n        background-color: #8C0CDC\n", g_ui["getRootWidget"]());

local registerWidget = setupUI("MainWindow\n  size: 320 240\n  !text: tr(\"Combo by Shazam Scripts\")\n  color: white\n\n  Panel\n    id: mainPanel\n    image-source: /images/ui/panel_flat\n    anchors.top: parent.top\n    anchors.bottom: parent.bottom\n    anchors.left: parent.left\n    anchors.right: parent.right\n    image-border: 6\n\n  Button\n    id: addButton\n    !text: tr(\"Adicionar\")\n    anchors.left: mainPanel.left\n    anchors.bottom: mainPanel.bottom\n    margin-bottom: 5\n    margin-left: 1\n    width: 133\n\n  Button\n    id: backButton\n    !text: tr(\"Voltar\")\n    anchors.bottom: mainPanel.bottom\n    anchors.left: addButton.right\n    anchors.right: mainPanel.right\n    margin-bottom: 5\n    margin-right: 2\n", g_ui["getRootWidget"]());


local destroyAllWidgets = function()
	screenWidget["mainPanel"]["spellsList"]:destroyChildren();
end

local reIndex = function()
	local selectedSpells = config["spells"][config["selected_type"]];
	for index, widget in ipairs(screenWidget["mainPanel"]["spellsList"]:getChildren()) do
		local entry = table["findbyfield"](selectedSpells, "spellName", widget:getId());
		entry["index"] = index;
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
end

local createTextEdit = function(data)
	local label = UI["createWidget"]("Label", registerWidget["mainPanel"]);
	addAnchors(label);
	label:setMarginTop(10);
	label:setMarginLeft(10);
	label:setText(data["title"]);
	local textEdit = UI["createWidget"]("TextEdit", registerWidget["mainPanel"]);
	addAnchors(textEdit);
	textEdit:setMarginLeft(10);
	textEdit:setMarginRight(10);
	textEdit:setMarginTop(3);
	textEdit:setText(data["text"]);
	textEdit:setId(data["var_name"]);
end

-- ============================================================
--  STEPPER  ( -  [valor]  +  )  -- substitui a barra com setas < >
--  Mesmo estilo dos botoes do Auto Treino. Mantem a API:
--  getValue() / setValue(v) / onValueChange(widget, valor)
-- ============================================================
local STEPPER_UI = [[
Panel
  height: 24

  Button
    id: minus
    anchors.top: parent.top
    anchors.left: parent.left
    width: 34
    height: 22
    text: <

  Button
    id: plus
    anchors.top: parent.top
    anchors.right: parent.right
    width: 34
    height: 22
    text: >

  TextEdit
    id: edit
    anchors.top: parent.top
    anchors.left: minus.right
    anchors.right: plus.left
    margin-left: 4
    margin-right: 4
    height: 22
    text-align: center
]]

local function createStepper(parent, minV, maxV, startValue, step)
    local w = setupUI(STEPPER_UI, parent)
    w.isStepper = true
    w.minV = minV
    w.maxV = maxV
    w.step = math.max(1, math.floor(tonumber(step) or 1))
    w.value = minV
    w.busy = false

    w.getValue = function(self) return self.value end

    w.setValue = function(self, v)
        v = math.floor(tonumber(v) or self.minV)
        v = math.max(self.minV, math.min(self.maxV, v))
        self.value = v
        self.busy = true
        self.edit:setText(tostring(v))
        self.busy = false
        if self.onValueChange then self.onValueChange(self, v) end
    end

    -- sempre "encaixa" na grade do passo (ex.: 130 -> + -> 150 | - -> 100)
    w.minus.onClick = function() w:setValue((math.ceil(w.value / w.step) - 1) * w.step) end
    w.plus.onClick = function() w:setValue((math.floor(w.value / w.step) + 1) * w.step) end

    -- tambem da para digitar o valor direto
    w.edit.onTextChange = function(widget, text)
        if w.busy then return end
        local n = tonumber(text)
        if not n then return end
        if n < w.minV or n > w.maxV then
            w:setValue(n)
        else
            w.value = math.floor(n)
            if w.onValueChange then w.onValueChange(w, w.value) end
        end
    end

    w:setValue(startValue or minV)
    return w
end

local createScrollBar = function(data)
	local label = UI["createWidget"]("Label", registerWidget["mainPanel"]);
	addAnchors(label);
	label:setMarginTop(10);
	label:setMarginLeft(10);
	label:setText(data["title"]);
	local stepper = createStepper(registerWidget["mainPanel"], data["range"]["min"], data["range"]["max"], data["text"] or data["range"]["min"], data["step"] or 1);
	addAnchors(stepper);
	stepper:setMarginLeft(10);
	stepper:setMarginRight(10);
	stepper:setMarginTop(3);
	stepper:setId(data["var_name"]);
end

doRegisterSpell = function(entry)
	registerWidget["mainPanel"]:destroyChildren();
	screenWidget:hide();
	registerWidget:show();
	for _, _data in ipairs(displayOptions) do
		local data = table["copy"](_data);
		
		if (data["default_value"] ~= nil) then
			data["text"] = entry[data["default_value"]];
		end
		
		if (entry[data["var_name"]] ~= nil) then
			data["text"] = entry[data["var_name"]];
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

doRefreshSpells = function()
	
	destroyAllWidgets();
	local selectedSpells = config["spells"][config["selected_type"]];
	for index, entry in ipairs(selectedSpells) do
		local widget = setupUI(entryWidget, screenWidget["mainPanel"]["spellsList"]);
		local removeSpell = function()
			screenWidget["mainPanel"]["nameField"]:setText(entry["spellName"]);
			table["remove"](selectedSpells, index);
			doRefreshSpells();
			persistCombo();
		end
		
		widget["onDoubleClick"] = function()
			doRegisterSpell(table["copy"](entry));
			removeSpell();
		end
		widget["remove"]["onClick"] = removeSpell;
		widget["enabled"]:setChecked(entry["enabled"]);

		widget["enabled"]["onCheckChange"] = function(widget, enabled)
			entry["enabled"] = enabled;
			persistCombo()
			doRefreshSpells();
		end

		local formattedName = entry["spellName"]:sub(1, 15):gsub("^%l", string.upper)
        local text = {formattedName, tr("CD: %s", entry["cooldownTotal"] or "?")};

		
		text = table["concat"](text, " | ");
		widget:setText(text);
		widget:setId(entry["spellName"])
	end
	reIndex();
end

local doConfigCheck = function()
	
	local first_option = spellsOptions[1];
	
	local clean_config = {};
	clean_config["spells"] = {};
	clean_config["enabled"] = true;

	for _, option in ipairs(spellsOptions) do
		clean_config["spells"][option] = {};
	end
	
	if (type(storage["comboConfig"]) ~= "table") then
		storage["comboConfig"] = clean_config;
	else
		if (storage["comboConfig"]["enabled"] == nil) then
			local config_copy = table["recursivecopy"](storage["comboConfig"]);
			local spells = clean_config["spells"][first_option];
			
			clean_config["showInfo"] = config_copy["showInfo"];
			
			for orangeMsg, entry in pairs(config_copy["spells"]) do
				entry["orangeMsg"] = orangeMsg;
				table["insert"](spells, entry);
				table["sort"](spells, function(a, b) return a["index"] < b["index"];	end)
			end
			storage["comboConfig"] = clean_config;
		end
	end
	
	if (not table["find"](spellsOptions, storage["comboConfig"]["selected_type"])) then
		storage["comboConfig"]["selected_type"] = first_option;
	end
	
	config = storage["comboConfig"];
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
	local base_dir = tr("/shazam_scripts/storage/%s", worldName);
	local files = g_resources["listDirectoryFiles"](base_dir);
	
	screenWidget["mainPanel"]["configList"]:clear();
	screenWidget["mainPanel"]["configList"]:addOption(characterName);
	for _, file in ipairs(files) do
		local file_without_extension = file:gsub(".lua", "");
		if (file_without_extension ~= characterName and file:ends(".lua")) then
			local path = base_dir .. "/" .. file;
			local content = g_resources["readFileContents"](path);
			local status, data = pcall(function() return load("return " .. content)() end);
			if (status and type(data) == "table" and data["comboConfig"]) then
				screenWidget["mainPanel"]["configList"]:addOption(file_without_extension);
			end
		end
	end
end

local loadConfig = function(name)
	checkLoadableConfigs();
	local base_dir = tr("/shazam_scripts/storage/%s", worldName);
	if (screenWidget["mainPanel"]["configList"]:isOption(name)) then
		local path = base_dir .. "/" .. name .. ".lua";
		if (g_resources["fileExists"](path)) then
			local content = g_resources["readFileContents"](path);
			local status, data = pcall(function() return load("return " .. content)() end);
			if (status and type(data) == "table" and data["comboConfig"]) then
				UI["ConfirmationWindow"]("Load Config", tr("Deseja utilizar a configura\231\227o de %s?", name), function()
					storage["comboConfig"] = data["comboConfig"];
					doConfigCheck();
					doRefreshSpells();
				end)
			end
		end
	end
end

-- Config agora abre com botao direito em qualquer parte da linha (painel, nao so o switch)
botWidget["configButton"]["onClick"] = function()
	screenWidget:show()
	screenWidget:raise()
	screenWidget:focus()
end

botWidget["onMouseRelease"] = function(self, mousePos, mouseButton)
	if mouseButton == 2 then
		screenWidget:show();
		screenWidget:raise();
		screenWidget:focus();
	end
end

screenWidget["onEscape"] = function()
	screenWidget:hide();
	gameRootPanel:focus();
end

registerWidget["backButton"]["onClick"] = function()
	registerWidget:hide();
	screenWidget:show();
end

screenWidget["mainPanel"]["testButton"]["onClick"] = function(widget)
	local text = "Testar Combo";
	local hover_color = "#8C0CDC";
	local background_color = "#A020F0";
	if (not checkSpells) then
		text = "PARAR";
		hover_color = "#FF474C";
		background_color = "red";
	end
	checkSpells = not checkSpells;
	widget:setText(text);
	widget["onHoverChange"] = function(widget, hover)
		widget:setBackgroundColor(hover and hover_color or background_color);
	end
	widget:setBackgroundColor(background_color);
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
	persistCombo();
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
	
	if (spellName:len() == 0) then
		warn("Insira uma magia!");
		return;
	end
	
	local spells = config["spells"][config["selected_type"]];
	for _, entry in ipairs(spells) do
		if (entry["spellName"] == spellName) then
			warn("Essa magia j\225 existe");
			return;
		end
	end
	
	local entry = {
		spellName = spellName,
		index = table["size"](spells) + 1,
		enabled = true
	};

	table["insert"](spells, entry);
	doRefreshSpells();
	screenWidget["mainPanel"]["nameField"]:clearText();
	persistCombo();
end

registerWidget["addButton"]["onClick"] = function()
	local children = registerWidget["mainPanel"]:getChildren();
	local spellName = screenWidget["mainPanel"]["nameField"]:getText():trim():lower();
	local spells = config["spells"][config["selected_type"]];
	local entry = {
		enabled=true,
		spellName=spellName,
		index = table["size"](spells) + 1,
	};
	for _, child in ipairs(children) do
		local value;
		local var_name = child:getId();
		local styleName = child:getStyleName();
		if (styleName == "ComboBox") then
			value = child:getCurrentOption()["text"];
		elseif (styleName == "TextEdit") then
			local text = child:getText():trim():lower();
			if (text:len() >= 1) then
				value = text;
			end
		elseif (styleName == "HorizontalScrollBar" or child.isStepper) then
			value = child:getValue();
		end
		if (value ~= nil) then
			entry[var_name] = value;
		end
	end
	
	
	table["insert"](spells, table["copy"](entry));
	
	doRefreshSpells();
	screenWidget:show();
	registerWidget:hide();
	screenWidget["mainPanel"]["nameField"]:clearText();
end

warn = function(msg, color)
	local widget = screenWidget["mainPanel"]["message"];
	widget["added"] = now + 3000;
	
	widget:setText(msg);
	widget:setColor(color or "yellow");
end



for _, value in ipairs(spellsOptions) do
	screenWidget["mainPanel"]["typeList"]:addOption(value);
end

doConfigCheck();
screenWidget["mainPanel"]["typeList"]:setCurrentOption(config["selected_type"]);
screenWidget["mainPanel"]["configList"]["mouseScroll"] = false;
screenWidget["onEnter"] = screenWidget["mainPanel"]["addButton"]["onClick"];
screenWidget["mainPanel"]["closeButton"]["onClick"] = screenWidget["onEscape"];




screenWidget:hide();
registerWidget:hide();
checkLoadableConfigs();
doRefreshSpells();

onTalk(function(name, level, mode, text)
	if not config["enabled"] then return end
	if (mode ~= 44) then return; end
	if (name ~= characterName) then return; end
	
	text = text:trim():lower();
	for _, data in pairs(config["spells"]) do
		for _, entry in ipairs(data) do
			if (entry["orangeMsg"] == text) then
				local cooldownTotal = (entry["cooldownTotal"] or 500) - 150;
				entry["cooldownTime"] = os["clock"]() + (cooldownTotal / 1000);
				break;
			end
		end
	end

end)


local main = function()
	if 	(
			checkSpells or
			isInPz() or
			(storage["comboDelay"] and storage["comboDelay"] >= now)
		) 
	then
		return;
	end
	
	local target = g_game["getAttackingCreature"]();
	if 	(
			not config["enabled"] or
			not target or
			not target:getPosition()
		) 
	then
		return;
	end
	
	
	local distance = getDistanceBetween(target:getPosition(), player:getPosition());
	
	local currentTime = os["clock"]();
	local spells = config["spells"][config["selected_type"]];
	for _, spell in ipairs(spells) do
		if (spell["enabled"] and distance <= (spell["distance"] or 10)) then
			local cooldownTime = (spell["cooldownTime"] or 0);
			local cooldownTotal = (spell["cooldownTotal"] or 0) / 1000;
			if (cooldownTime <= currentTime or currentTime + cooldownTotal < cooldownTime) then
				say(spell["spellName"], -1);
			end
		end
	end
end

local executeMacro = macro(storage["scrollBars"] and storage["scrollBars"]["macroDelay"] or 200, function()
	schedule(0, main);
end)

local widgetPos;
macro(500, function()
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

macro(500, function()
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

local approach = function(n, a)
	local res = math["floor"](n / a + (1 / 2)) * a;
    return math["floor"](res)
end

local CURRENT_STEP = 0;
local ORANGEMSG_STEP = 0;
local COOLDOWN_STEP = 1;
local EXHAUST_STEP = 2;
local FIST_STEP = 3;
local DAMAGE_STEP = 4;
local HITTIME_STEP = 5;
local PROJECTILES_STEP = 6;
local ITER_STEP = 7;
local TEST_STEP = 8;



local lastMove;
local lastPercent;
local lastHpPercent;
local say_function;
local currentTable = {};
local orangeMessages = {};
local startDelay = math["huge"];

onPlayerPositionChange(function(newPos, oldPos)
	lastMove = now;
end)

macro(storage["scrollBars"] and storage["scrollBars"]["macroDelay"] or (200), function()
	if (not config or config["enabled"] ~= true) then return; end
	local healthPercent = player:getHealthPercent();
	if (healthPercent ~= lastHpPercent and lastHpPercent ~= nil) then
		lastPercent = now;
	end
	lastHpPercent = healthPercent;
end)


local doReset = function(dont_click)
	if (say_function ~= nil) then
		say = say_function;
	end
	
	startDelay = math["huge"];
	CURRENT_STEP = 0;
	say_function = nil;
	table["clear"](currentTable);
	doRefreshSpells();
	if (not dont_click) then
		screenWidget["mainPanel"]["testButton"]:onClick();
	end
end

local getCurrentStatus = function()
	local target = g_game["getAttackingCreature"]();
	if (not target or not target:isMonster()) then
		return "Ataque um monstro";
	end
	
	if (lastPercent and now - lastPercent <= 10000) then
		return "Fique em uma zona segura";
	end
end

macro(storage["scrollBars"] and storage["scrollBars"]["macroDelay"] or (200), function(self)
	if (not config or config["enabled"] ~= true) then return; end
	if (checkSpells ~= true) then return; end
	local status = getCurrentStatus();
	if (status) then
		doReset();
		checkSpells = nil;
		warn(status);
		return;
	end

	
	if (manapercent() < 30) then
		waitingManaRecovery = true;
		doReset(true);
	end
	
	if (say_function == nil) then
		say_function = say;
		say = function() end;
	end
	
	if (waitingManaRecovery) then
		warn("Aguardando mana chegar em 80%");
		if (manapercent() < 80) then
			return;
		end
		waitingManaRecovery = nil;
	end

	if (startDelay == math["huge"]) then
		if (type(saveConfig) == "function") then
			addEvent(saveConfig);
		end
		startDelay = now + 3000;
	end
end)

macro(storage["scrollBars"] and storage["scrollBars"]["macroDelay"] or (200), function()
	if (not config or config["enabled"] ~= true) then return; end
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	if (CURRENT_STEP ~= ORANGEMSG_STEP) then return; end
	
	local entry;
	local spells = config["spells"][config["selected_type"]];
	for index, spell in ipairs(spells) do
		if (spell["orangeMsg"] == nil) then
			entry = spell;
			break;
		end
	end
	
	if (entry == nil) then
		CURRENT_STEP = CURRENT_STEP + 1;
		return;
	end
	
	local text = tr("Verificando texto laranja de %s", entry["spellName"]);
	warn(text, "white");
	
	if (currentTable[1] ~= nil) then
		entry["orangeMsg"] = currentTable[1];
		
		startDelay = math["huge"];
		table["clear"](currentTable);
		delay(500);
		return;
	end
	say_function(entry["spellName"]);
end)

onTalk(function(name, level, mode, text)
	if not config["enabled"] then return end
	if (mode ~= 44) then return; end
	if (name ~= characterName) then return; end
	
	if (CURRENT_STEP ~= ORANGEMSG_STEP) then return; end
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	if (currentTable[1] ~= nil) then return; end
	
	currentTable[1] = text:trim():lower();
end)


macro(storage["scrollBars"] and storage["scrollBars"]["macroDelay"] or (200), function()
	if (not config or config["enabled"] ~= true) then return; end
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	if (CURRENT_STEP ~= COOLDOWN_STEP) then return; end
	doRefreshSpells();
	local entry;
	local spells = config["spells"][config["selected_type"]];
	for index, spell in ipairs(spells) do
		if (spell["cooldownTotal"] == nil) then
			entry = spell;
			break;
		end
	end
	
	if (entry == nil) then
		CURRENT_STEP = CURRENT_STEP + 1;
		return;
	end
	
	orangeMessages[1] = entry["orangeMsg"];
	warn(tr("Verificando cooldown de %s", entry["spellName"]), "white");
	
	if (table["size"](currentTable) >= 10) then
		local values = {};
		for i = 2, table["size"](currentTable) do
			local current_value = currentTable[i];
			local before_value = currentTable[i - 1];
			local diff = current_value - before_value;
			local value = approach(diff, 250);
			table["insert"](values, value);
		end
		
		local data = {};
		for _, value in ipairs(values) do
			local quantity = (data[value] or 0) + 1;
			data[value] = quantity;
		end
		
		local bestValue;
		local higherQuantity;
		for value, quantity in pairs(data) do
			if (not higherQuantity or higherQuantity < quantity) then
				higherQuantity = quantity;
				bestValue = value;
			end
		end
		
		entry["cooldownTotal"] = bestValue;
		startDelay = math["huge"];
		table["clear"](currentTable);
		delay(500);
		return;
	end
	say_function(entry["spellName"]);
end)

onTalk(function(name, level, mode, text)
	if not config["enabled"] then return end
	if (mode ~= 44) then return; end
	if (name ~= characterName) then return; end
	
	if (CURRENT_STEP ~= COOLDOWN_STEP) then return; end
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	if (orangeMessages[1] ~= text:trim():lower()) then return; end
	
	table["insert"](currentTable, os["clock"]() * 1000);
end)

macro(storage["scrollBars"] and storage["scrollBars"]["macroDelay"] or (200), function()
	if (not config or config["enabled"] ~= true) then return; end
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	if (CURRENT_STEP ~= EXHAUST_STEP) then return; end
	
	local entry;
	local subEntry;
	local spells = config["spells"][config["selected_type"]];
	for index, spell in ipairs(spells) do
		if (spell["exhaust"] == nil) then
			entry = spell;
			break;
		end
	end
	
	if (entry == nil) then
		CURRENT_STEP = CURRENT_STEP + 1;
		return;
	end
	
	if (entry["cache"] == nil) then
		entry["cache"] = {};
	end
	
	local spells = config["spells"][config["selected_type"]];
	for index, spell in ipairs(spells) do
		if (entry["cache"][spell["spellName"]] == nil and entry["spellName"] ~= spell["spellName"]) then
			subEntry = spell;
			break;
		end
	end
	
	if (subEntry == nil) then
		local cache = entry["cache"];
		local values = {};
		for spell, exhaust in pairs(cache) do
			values[exhaust] = values[exhaust] or {};
			table["insert"](values[exhaust], spell);
		end

		local most_repeated = {size=0};
		for exhaust, spells in pairs(values) do

			local size = #spells;
			if (most_repeated["size"] < size) then
				most_repeated = {size=size,exhaust=exhaust};
			end
		end


		if (most_repeated["size"] ~= table["size"](spells) - 1) then
			for exhaust, spells in pairs(values) do
				if (exhaust ~= most_repeated["exhaust"]) then
					entry["custom_exhausts"] = entry["custom_exhausts"] or {};
					for _, spell in ipairs(spells) do
						entry["custom_exhausts"][spell] = exhaust;
					end
				end
			end
		end


		entry["cache"] = nil;
		entry["exhaust"] = most_repeated["exhaust"];
		startDelay = math["huge"];
		return;
	end
	
	if (table["size"](currentTable) >= 30) then
		local values = {};
		for i = 2, table["size"](currentTable), 2 do
			local current_value = currentTable[i];
			local before_value = currentTable[i - 1];
			local diff = current_value - before_value;
			local value = approach(diff, 250);
			table["insert"](values, value);
		end
		
		local data = {};
		for _, value in ipairs(values) do
			local quantity = (data[value] or 0) + 1;
			data[value] = quantity;
		end
		
		local bestValue;
		local higherQuantity;
		for value, quantity in pairs(data) do
			if (not higherQuantity or higherQuantity < quantity) then
				higherQuantity = quantity;
				bestValue = value;
			end
		end
		
		entry["cache"][subEntry["spellName"]] = bestValue;
		startDelay = math["huge"];
		table["clear"](currentTable);
		delay(500);
		return;
	end
	
	warn(tr("Verificando exhaust entre %s e %s", entry["spellName"], subEntry["spellName"]), "white");
	
	local entries = {entry, subEntry};
	local currentIndex = (table["size"](currentTable) % 2) + 1;
	if (currentIndex == 1) then
		local currentTime = os["clock"]();
		for _, entry in ipairs(entries) do
			local cooldownTime = (entry["cooldownTime"] or 0) + 2;
			local cooldownTotal = (entry["cooldownTotal"] or 0) / 1000;
			if not (cooldownTime <= currentTime or currentTime + (cooldownTotal + 2) < cooldownTime) then
				return delay(500);
			end
		end
	end
	
	orangeMessages[1] = entry["orangeMsg"];
	orangeMessages[2] = subEntry["orangeMsg"];
	

	if (currentIndex == 1) then
		say_function(entry["spellName"]);
	end
	say_function(subEntry["spellName"]);
end)

onTalk(function(name, level, mode, text)
	if not config["enabled"] then return end
	if (mode ~= 44) then return; end
	if (name ~= characterName) then return; end
	
	if (CURRENT_STEP ~= EXHAUST_STEP) then return; end
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	
	local currentIndex = (table["size"](currentTable) % 2) + 1;
	if (orangeMessages[currentIndex] ~= text:trim():lower()) then return; end
	
	table["insert"](currentTable, os["clock"]() * 1000);
end)



local get_dmg_from_msg = function(text)
    local damageToken

    for token in tostring(text):gmatch("%S+") do
        if token:match("%d") then
            damageToken = token:lower()
        end
    end

    if not damageToken then
        return nil
    end

    local numberPart = damageToken:match("([%d%.]+)")
    if not numberPart then
        return nil
    end

    local damage = tonumber(numberPart)
    if not damage then
        return nil
    end

    if damageToken:find("k", 1, true) then
        damage = damage * 1000
    end

    return math.floor(damage + 0.5)
end

macro(storage["scrollBars"] and storage["scrollBars"]["macroDelay"] or (200), function()
	if (not config or config["enabled"] ~= true) then return; end
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	if (CURRENT_STEP ~= FIST_STEP) then return; end
	
    local slots = {getLeft, getRight};
    for index, slot in ipairs(slots) do
        local slotItem = slot();
        if (slotItem) then
            warn(tr("Desequipando a m\227o %s.", index == 1 and "esquerda" or "direita"), "white");
            moveToSlot(slotItem, SlotBack);
            return;
        end
    end
	
	if (config["fist_dmg"] and config["fist_cooldown"]) then
		CURRENT_STEP = CURRENT_STEP + 1;
		return;
	end
	
	local totalHits = 50;
	if (table["size"](currentTable) >= totalHits) then
		
		local dmg = {min=math["huge"], max=0};
		local times = {};
		for _, value in ipairs(currentTable) do
			if (type(value) ~= "number") then
				table["insert"](times, value["time"]);
				dmg["min"] = math["min"](value["damage"], dmg["min"]);
				dmg["max"] = math["max"](value["damage"], dmg["max"]);
			end
		end
		local values = {};
		for i = 2, table["size"](times) do
			local current_value = times[i];
			local before_value = times[i - 1];
			local diff = current_value - before_value;
			local value = approach(diff, 50);
			table["insert"](values, value);
		end
		
		local data = {};
		for _, value in ipairs(values) do
			local quantity = (data[value] or 0) + 1;
			data[value] = quantity;
		end
		
		local bestValue;
		local higherQuantity;
		for value, quantity in pairs(data) do
			if (not higherQuantity or higherQuantity < quantity) then
				higherQuantity = quantity;
				bestValue = value;
			end
		end
		
		startDelay = math["huge"];
		table["clear"](currentTable);
		config["fist_dmg"] = dmg;
		config["fist_cooldown"] = bestValue;
		delay(500);
		return;
	end
	warn(tr("Verificando os hits da m\227o. [%d/%d]", table["size"](currentTable), totalHits), "white");
end)

onTextMessage(function(mode, text)
	if not config["enabled"] then return end
	
	
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	if (CURRENT_STEP ~= FIST_STEP) then return; end
	if (getLeft() or getRight()) then return; end
	 
	text = text:lower();
	if not (text:find("due to your") or text:find("you deal") or text:match("perdeu %d+ de hps") or text:find("pelo seu ataque") or text:match("lost %d+ hitpoints")) then return; end
	
	local time = os["clock"]() * 1000;
	local damage = get_dmg_from_msg(text);
	if damage then
		local data = {time=time,damage=damage};
		table["insert"](currentTable, data);
	end
end)

local last_fist_attack = 0;
local checkFistAttack = function(msg)
	local dmg = get_dmg_from_msg(msg);
	if not dmg or not config["fist_dmg"] or not config["fist_dmg"]["max"] or not config["fist_dmg"]["min"] then
		return false
	end
	if (dmg <= config["fist_dmg"]["max"] and dmg >= config["fist_dmg"]["min"]) then
		local diff = (os["clock"]() - last_fist_attack);
		local cooldown = (config["fist_cooldown"] - 150) / 1000;
		if (diff >= cooldown) then
			last_fist_attack = os["clock"]();
			return true;
		end
	end
end

math["percent"] = function(a, b)
	local res = (a / b) * 100;
	return math["floor"](res);
end

local get_best_result = function(results)
    local value = 5;
    while true do
        local new_results = {};
        for _, res in ipairs(results) do
            local temp_value = approach(res, value);
            temp_value = math["max"](temp_value, 1);
            temp_value = tostring(temp_value);
            new_results[temp_value] = (new_results[temp_value] or 0) + 1;
        end

        local ret_value = 0;
        local ret_quantity = 0;
        local total = 0;
        for key, value in pairs(new_results) do
            if (ret_quantity < value or ret_value == 0) and value ~= 0 then
                ret_value = tonumber(key);
                ret_quantity = value;
            end
            total = total + value;
        end

        local percent = math["percent"](ret_quantity, total);
        if (percent >= 60 and ret_value > 0) then
            return ret_value;
        end
        value = value + 5;
    end
end


macro(storage["scrollBars"] and storage["scrollBars"]["macroDelay"] or (200), function()
	if (not config or config["enabled"] ~= true) then return; end
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	if (CURRENT_STEP ~= DAMAGE_STEP) then return; end
	
	local entry;
	local spells = config["spells"][config["selected_type"]];
	for index, spell in ipairs(spells) do
		if (spell["damage"] == nil) then
			entry = spell;
			break;
		end
	end
	
	if (entry == nil) then
		CURRENT_STEP = CURRENT_STEP + 1;
		return;
	end
	
	warn(tr("Verificando dano de %s", entry["spellName"]), "white");
	
	if (table["size"](currentTable) >= 10) then
		local bestValue = get_best_result(currentTable);
		entry["damage"] = bestValue;
		startDelay = math["huge"];
		table["clear"](currentTable);
		delay(500);
		return;
	end
	say_function(entry["spellName"]);
end)

onTextMessage(function(mode, text)
	if not config["enabled"] then return end
	
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	if (CURRENT_STEP ~= DAMAGE_STEP) then return; end
	 
	text = text:lower();
	if not (text:find("due to your") or text:find("you deal") or text:match("perdeu %d+ de hps") or text:find("pelo seu ataque") or text:match("lost %d+ hitpoints")) then return; end
	
	if (checkFistAttack(text)) then return; end

	local damage = get_dmg_from_msg(text);
	if damage then
		table["insert"](currentTable, damage);
	end
end)

macro(storage["scrollBars"] and storage["scrollBars"]["macroDelay"] or (200), function()
	if (not config or config["enabled"] ~= true) then return; end
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	if (CURRENT_STEP ~= HITTIME_STEP) then return; end
	
	local entry;
	local spells = config["spells"][config["selected_type"]];
	for index, spell in ipairs(spells) do
		if (spell["until_hit"] == nil) then
			entry = spell;
			break;
		end
	end
	
	if (entry == nil) then
		CURRENT_STEP = CURRENT_STEP + 1;
		return;
	end
	
	local text = tr("Verificando tempo de hit de %s", entry["spellName"]);
	warn(text, "white");
	
	if (table["size"](currentTable) >= 2) then
		local current_value = currentTable[2] - currentTable[1];
		local value = approach(current_value, 50);
		entry["until_hit"] = value;
		startDelay = math["huge"];
		table["clear"](currentTable);
		delay(500);
		return;
	end
	local currentTime = os["clock"]();
	local cooldownTime = (entry["cooldownTime"] or 0) + 1;
	local cooldownTotal = (entry["cooldownTotal"] or 0) / 1000;
	if not (cooldownTime <= currentTime or currentTime + cooldownTotal < cooldownTime) then
		CURRENT_STEP = CURRENT_STEP - 1;
		return;
	end
	say_function(entry["spellName"]);
end)

onTextMessage(function(mode, text)
	if not config["enabled"] then return end
	
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	if (CURRENT_STEP ~= HITTIME_STEP) then return; end
	 
	text = text:lower();
	if not (text:find("due to your") or text:find("you deal") or text:match("perdeu %d+ de hps") or text:find("pelo seu ataque") or text:match("lost %d+ hitpoints")) then return; end
	
	if (checkFistAttack(text)) then return; end

	table["insert"](currentTable, os["clock"]() * 1000);
end)

onTalk(function(name, level, mode, text)
	if not config["enabled"] then return end
	if (mode ~= 44) then return; end
	if (name ~= characterName) then return; end
	
	if (CURRENT_STEP ~= HITTIME_STEP) then return; end
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	
	table["insert"](currentTable, os["clock"]() * 1000);
end)


macro(storage["scrollBars"] and storage["scrollBars"]["macroDelay"] or (200), function()
	if (not config or config["enabled"] ~= true) then return; end
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	if (CURRENT_STEP ~= PROJECTILES_STEP) then return; end
	
	local entry;
	local spells = config["spells"][config["selected_type"]];
	for index, spell in ipairs(spells) do
		if (spell["projectiles"] == nil) then
			entry = spell;
			break;
		end
	end
	
	if (entry == nil) then
		CURRENT_STEP = CURRENT_STEP + 1;
		return;
	end
	
	local text = tr("Verificando proj\233teis de %s", entry["spellName"]);
	warn(text, "white");
	
	if (table["size"](currentTable) >= 10) then
		local values = {};
		for i = 1, table["size"](currentTable) do
			local current_value = currentTable[i];
			table["insert"](values, current_value);
		end
		
		local data = {};
		for _, value in ipairs(values) do
			local quantity = (data[value] or 0) + 1;
			data[value] = quantity;
		end
		
		local bestValue;
		local higherQuantity;
		for value, quantity in pairs(data) do
			if (not higherQuantity or higherQuantity < quantity) then
				higherQuantity = quantity;
				bestValue = value;
			end
		end
		
		entry["projectiles"] = bestValue;
		startDelay = math["huge"];
		table["clear"](currentTable);
		delay(500);
		return;
	end
	local currentTime = os["clock"]();
	local cooldownTime = (entry["cooldownTime"] or 0) + 1;
	local cooldownTotal = (entry["cooldownTotal"] or 0) / 1000;
	if not (cooldownTime <= currentTime or currentTime + cooldownTotal < cooldownTime) then
		trigger = true;
		return;
	end
	
	if (trigger) then
		trigger = nil;
		currentTable[#currentTable + 1] = 0;
	end
			
	
	say_function(entry["spellName"]);
end)

onTextMessage(function(mode, text)
	if not config["enabled"] then return end
	
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	if (CURRENT_STEP ~= PROJECTILES_STEP) then return; end
	 
	text = text:lower();
	if not (text:find("due to your") or text:find("you deal") or text:match("perdeu %d+ de hps") or text:find("pelo seu ataque") or text:match("lost %d+ hitpoints")) then return; end
	
	if (checkFistAttack(text)) then return; end
	
	local index = #currentTable;
	if (currentTable[index] == nil) then return; end
	
	local currentValue = currentTable[index];
	currentTable[index] = currentValue + 1;
end)


local best_combo;
local totalLeft = 0;
local totalTested = 0;
local permutations = {};
function permgen(a, n)
    if n == 0 then
		table["insert"](permutations, table["recursivecopy"](a));
		return;
	end
	for i = 1, n, 1 do
		a[n], a[i] = a[i], a[n];
		permgen(a, n - 1);
		a[n], a[i] = a[i], a[n];
	end
end

local function perm(a)
    local n = #a;
	permgen(a, n);
end

macro(storage["scrollBars"] and storage["scrollBars"]["macroDelay"] or (200), function(self)
	if (not config or config["enabled"] ~= true) then return; end
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	if (CURRENT_STEP ~= ITER_STEP) then return; end
	table["clear"](permutations);
	
	local spells = config["spells"][config["selected_type"]];
	
	local permutated_indexes = {};
	for i = 1, #spells do
		permutated_indexes[i] = i;
	end
	
	perm(permutated_indexes);
	totalLeft = table["size"](permutations);
	
	CURRENT_STEP = CURRENT_STEP + 1;
end)

macro(storage["scrollBars"] and storage["scrollBars"]["macroDelay"] or (200), function(self)
	if (not config or config["enabled"] ~= true) then return; end
	if (startDelay >= now) then return; end
	if (checkSpells ~= true) then return; end
	if (CURRENT_STEP ~= TEST_STEP) then return; end
	
	
	if (permutations[1] == nil) then
		best_combo["dmg"] = nil;
		for _, entry in ipairs(best_combo) do
			entry["exhaustTime"] = nil;
			entry["cooldownTime"] = nil;
		end
		warn("Combo testado!", "white");
		config["spells"][config["selected_type"]] = table["recursivecopy"](best_combo);
		persistCombo();
		best_combo = nil;
		totalTested = 0;
		doReset();
		return;
	end
	
	local sumDamage;
	local currentTime;
	local test_spells;
	local castSpell = function(entry)
		entry["cooldownTime"] = currentTime + entry["cooldownTotal"];
		entry["casted"] = (entry["casted"] or 0) + 1;
		for _, otherEntry in ipairs(test_spells) do
			
			local custom_exhausts = (entry["custom_exhausts"] or {});
			local exhaustValue = custom_exhausts[otherEntry["spellName"]] or entry["exhaust"] or 500;
			otherEntry["exhaustTime"] = currentTime + exhaustValue;
			
		end
		local obj = {};
		for i = 1, entry["projectiles"] do
			local value = currentTime + (entry["until_hit"] * i);
			table["insert"](obj, value);
		end
		sumDamage[entry["spellName"]] = obj;
	end


	local spells = config["spells"][config["selected_type"]];
	local order = permutations[1];
	test_spells = {};
	local spells_copy = table["recursivecopy"](spells);
	for _, index in ipairs(order) do
		table["insert"](test_spells, spells_copy[index]);
	end

	for index, entry in ipairs(test_spells) do
		entry["index"] = index;
		entry["casted"] = nil;
		entry["exhaustTime"] = nil;
		entry["cooldownTime"] = nil;
	end
	
	currentTime = 0;
	sumDamage = {};
	

	local totalDamage = 0;
	local currentDamage = 0;
	local burstDamage = {};
	while (currentTime <= 15000) do
		for _, entry in ipairs(test_spells) do
			local exhaustTime = (entry["exhaustTime"] or 0);
			local cooldownTime = (entry["cooldownTime"] or 0);
			if (exhaustTime <= currentTime and cooldownTime <= currentTime) then
				castSpell(entry);
			end
			local value = sumDamage[entry["spellName"]];
			if (value ~= nil) then
				while (#value > 0 and value[1] <= currentTime) do
					local damage = entry["damage"];
					totalDamage = totalDamage + damage;
					currentDamage = currentDamage + damage;
					table["remove"](value, 1);
				end
				if (#value == 0) then
					sumDamage[entry["spellName"]] = nil;
				end
			end
		end
		currentTime = currentTime + 250;
		if (currentTime % 500 == 0) then
			table["insert"](burstDamage, currentDamage);
			currentDamage = 0;
		end
	end
	
	
	local filtered_spells = table["collect"](test_spells, function(index, entry)
		if entry["spellName"] ~= nil and (not storage["removeUnusedSpells"] or entry["casted"] ~= nil) then
			return entry;
		end
	end)
	
	local new_combo_found;
	local burst_damage = math["max"](unpack(burstDamage));
	local total_damage = totalDamage;
	if (best_combo == nil) then
		new_combo_found = true;
	else
		if (best_combo["dmg"]["burst"] < burst_damage) then
			new_combo_found = true;
		elseif (best_combo["dmg"]["burst"] == burst_damage and best_combo["dmg"]["total"] < total_damage) then
			new_combo_found = true;
		elseif (best_combo["dmg"]["burst"] == burst_damage and best_combo["dmg"]["total"] == total_damage) then
			local bestSpells = {};
			for _, entry in ipairs(best_combo) do
				table["insert"](bestSpells, entry["spellName"]);
			end
			local newSpells = {};
			for _, entry in ipairs(filtered_spells) do
				table["insert"](newSpells, entry["spellName"]);
			end
			local currentAsString = table["concat"](bestSpells, "|");
			local newAsString = table["concat"](newSpells, "|");
			if (newAsString < currentAsString) then
				new_combo_found = true;
			end
		end
			
	end
	
	if (new_combo_found) then
		best_combo = filtered_spells;
		best_combo["dmg"] = {burst=burst_damage,total=total_damage};
	end
	
	
	totalTested = totalTested + 1;
	warn(tr("Testando combos [%d/%d]", totalTested, totalLeft), "white");
	table["remove"](permutations, 1);
end)["timeout"] = 1;


macro(storage["scrollBars"] and storage["scrollBars"]["macroDelay"] or (200), function()
	if (not config or config["enabled"] ~= true) then return; end
	if (not checkSpells) then return; end
	if (CURRENT_STEP ~= TEST_STEP) then return; end
	local dir = (player:getDirection() + 1) % 4;
	turn(dir);
	delay(500);
end)

botWidget["switch"]["onClick"] = function()
	config["enabled"] = not config["enabled"];
	botWidget["switch"]:setOn(config["enabled"]);
	persistCombo()
end

botWidget["switch"]:setOn(config["enabled"]);


if configData then
	configData["combo"]["macro"] = botWidget["switch"]
end
