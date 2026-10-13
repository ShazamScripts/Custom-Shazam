-- Definição dos tipos mantendo a compatibilidade da interface
local spellsTypes = {
	BUFF = "Buffs"
}

local spellsLimits = { ["Buffs"] = math.huge }
local spellsWidgets = {}
local spellsOptions = { spellsTypes.BUFF }

local widgetStartPosition = {x=50, y=50}
local worldName = g_game.getWorldName():trim()
local characterName = g_game.getCharacterName()
local isMobileApp = (g_app or modules._G.g_app).isMobile()
local isKeyPressed = modules.corelib.g_keyboard.isKeyPressed

-- Opções de exibição configuradas apenas para o que o Buff utiliza
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
		range = {min=0, max=600}
	},
	{
		title = "Tempo ativo",
		var_name = "activeTotal",
		range = {min=0, max=180},
	},
	{
		title = "Tecla para utilizar",
		var_name = "key"
	}
}

local warn
local config
local doRefreshSpells
local doRegisterSpell

local spellWidget = "UIWidget\n  background-color: black\n  padding: 0 5\n  text-auto-resize: true\n"

local botWidget = setupUI("Panel\n  height: 17\n\n  BotSwitch\n    id: switch\n    anchors.top: parent.top\n    anchors.left: parent.left\n    text-align: center\n    width: 130\n    !text: tr(\"Buffs\")\n\n  Button\n    id: config\n    anchors.top: prev.top\n    anchors.bottom: prev.bottom\n    anchors.left: prev.right\n    anchors.right: parent.right\n    text: Config\n")

local entryWidget = "Label\n  background-color: alpha\n  text-offset: 37 4\n  focusable: true\n  height: 16\n  font: verdana-11px-rounded\n\n  CheckBox\n    id: enabled\n    !tooltip: tr(\"Ativar\")\n    anchors.left: parent.left\n    anchors.verticalCenter: parent.verticalCenter\n    width: 15\n    height: 15\n    margin-top: 2\n    margin-left: 3\n\n  CheckBox\n    id: spellTime\n    !tooltip: tr(\"Ativar Time Spell\")\n    anchors.left: prev.right\n    anchors.verticalCenter: prev.verticalCenter\n    width: 15\n    height: 15\n    margin-left: 3\n\n  $focus:\n    background-color: #00000055\n\n  Button\n    id: remove\n    !text: tr('x')\n    anchors.right: parent.right\n    margin-right: 15\n    text-offset: 1 0\n    width: 15\n    height: 15\n    tooltip: Remover magia da lista\n"

local screenWidget = setupUI("MainWindow\n  size: 320 360\n  !text: tr(\"Buffs By Shazam\")\n  color: white\n\n  Panel\n    id: mainPanel\n    image-source: /images/ui/panel_flat\n    anchors.top: parent.top\n    anchors.bottom: parent.bottom\n    anchors.left: parent.left\n    anchors.right: parent.right\n    image-border: 6\n\n    TextList\n      id: spellsList\n      image-source: /images/ui/textedit\n      anchors.centerIn: parent\n      anchors.left: parent.left\n      anchors.right: parent.right\n      margin-top: 20\n      margin-left: 10\n      margin-right: 10\n      image-border: 6\n      height: 180\n      vertical-scrollbar: spellsListScroll\n\n    VerticalScrollBar\n      id: spellsListScroll\n      anchors.top: spellsList.top\n      anchors.bottom: spellsList.bottom\n      anchors.right: spellsList.right\n      step: 10\n      pixels-scroll: true\n\n    TextEdit\n      id: nameField\n      tooltip: Nome da Magia\n      anchors.bottom: spellsList.top\n      anchors.left: parent.left\n      margin-bottom: 5\n      margin-left: 10\n      width: 185\n\n    Label\n      !text: tr(\"Nome do Buff\")\n      anchors.bottom: prev.top\n      anchors.left: prev.left\n      margin-left: 50\n      margin-bottom: 2\n\n    ComboBox\n      id: configList\n      anchors.top: parent.top\n      anchors.left: spellsList.left\n      text-offset: 3 0\n      margin-top: 5\n      margin-right: 5\n      width: 122\n\n    ComboBox\n      id: typeList\n      anchors.top: prev.top\n      anchors.left: prev.right\n      anchors.right: spellsList.right\n      text-offset: 3 0\n      margin-left: 5\n\n    Button\n      id: addButton\n      !text: tr(\"Adicionar\")\n      anchors.top: nameField.top\n      anchors.bottom: nameField.bottom\n      anchors.left: nameField.right\n      anchors.right: spellsList.right\n      margin-left: 5\n\n    Label\n      anchors.top: spellsList.bottom\n      anchors.right: parent.right\n      anchors.left: parent.left\n      id: message\n      margin-top: 2\n      text-auto-resize: true\n      text-align: center\n      text-wrap: true\n\n    Button\n      id: closeButton\n      !text: tr(\"Fechar\")\n      anchors.bottom: parent.bottom\n      anchors.right: typeList.right\n      anchors.left: configList.left\n      margin-bottom: 1\n", g_ui.getRootWidget())

local registerWidget = setupUI("MainWindow\n  size: 320 430\n  !text: tr(\"Configurar Buff\")\n  color: white\n\n  Panel\n    id: mainPanel\n    image-source: /images/ui/panel_flat\n    anchors.top: parent.top\n    anchors.bottom: parent.bottom\n    anchors.left: parent.left\n    anchors.right: parent.right\n    image-border: 6\n\n  Button\n    id: addButton\n    !text: tr(\"Salvar\")\n    anchors.left: mainPanel.left\n    anchors.bottom: mainPanel.bottom\n    margin-bottom: 5\n    margin-left: 1\n    width: 133\n\n  Button\n    id: backButton\n    !text: tr(\"Voltar\")\n    anchors.bottom: mainPanel.bottom\n    anchors.left: addButton.right\n    anchors.right: mainPanel.right\n    margin-bottom: 5\n    margin-right: 2\n    @onClick: self:getParent():hide();\n", g_ui.getRootWidget())

local getAllKeys = function()
	local keys = {}
	if (isMobileApp) then
		keys = {"None", "F1", "F2", "Escape"}
	else
		for name, key in pairs(modules.corelib.KeyCodeDescs) do
			if (key ~= "Unknown") then
				table.insert(keys, key)
			end
		end
	end
	table.sort(keys)
	table.insert(keys, 1, "None")
	table.insert(keys, 1, "AUTO")
	return keys
end

local isDragKeyPressed = function()
	if (isMobileApp) then return isKeyPressed("F2") end
	return modules.corelib.g_keyboard.isCtrlPressed()
end

local hasAnyActive = function(type)
	local spells = config.spells[type]
	for _, entry in ipairs(spells) do
		if (entry.activeTime and entry.activeTime >= os.time()) then
			return true
		end
	end
	return false
end

local getAllScreenWidgets = function()
	local widgets = {}
	for type, data in pairs(spellsWidgets) do
		for _, widget in pairs(data) do
			table.insert(widgets, widget)
		end
	end
	return widgets
end

local destroyAllWidgets = function()
	screenWidget.mainPanel.spellsList:destroyChildren()
	local widgets = getAllScreenWidgets()
	for _, widget in pairs(widgets) do
		widget:destroy()
	end
	table.clear(spellsWidgets)
end

local doRemoveMouseMove = function(entry)
	local widget = spellsWidgets[entry.type][entry.spellName]
	if not widget then return end
	widget.onDragEnter = nil
	widget.onDragMove = nil
	widget:setFocusable(false)
	widget:setPhantom(true)
	widget:setDraggable(false)
	widget:setOpacity(7 / 10)
end

local doSetMouseMove = function(entry)
	local widget = spellsWidgets[entry.type][entry.spellName]
	if not widget then return end
	widget:setFocusable(true)
	widget:setPhantom(false)
	widget:setDraggable(true)
	widget:setOpacity(1)

	widget.onDragEnter = function(widget, mousePos)
		widget:breakAnchors()
		widget.movingReference = {x = mousePos.x - widget:getX(), y = mousePos.y - widget:getY()}
		return true
	end

	widget.onDragMove = function(widget, mousePos, moved)
		local parentRect = widget:getParent():getRect()
		local x = math.min(math.max(parentRect.x, mousePos.x - widget.movingReference.x), parentRect.x + parentRect.width - widget:getWidth())
		local y = math.min(math.max(parentRect.y - widget:getParent():getMarginTop(), mousePos.y - widget.movingReference.y), parentRect.y + parentRect.height - widget:getHeight())
		widget:move(x, y)
		entry.pos = {x = x, y = y}
		return true
	end
end

local setupWidget = function(entry)
	local widget = setupUI(spellWidget, g_ui.getRootWidget())
	if (spellsWidgets[entry.type] == nil) then
		spellsWidgets[entry.type] = {}
	end
	spellsWidgets[entry.type][entry.spellName] = widget
	widget:setPosition(entry.pos or widgetStartPosition)
	widget.entry = entry
	doRemoveMouseMove(entry)
end

local canCast = function(entry)
	if (not entry.enabled) then return false end
	if ((entry.cooldownTime or 0) >= os.time()) then return false end

	if ((storage.sealedTypes and storage.sealedTypes.buff or 0) >= os.time()) then
		return false
	end
	
	if (entry.key == "AUTO") then return true end
	return isKeyPressed(entry.key)
end

local doSpellCast = function(type)
	local spells = config.spells[type]
	if not spells or #spells == 0 then return end
	
	for _, entry in ipairs(spells) do
		if canCast(entry) then
			say(entry.spellName)
		end
	end
end

table.findbyfield = function(t, fieldname, fieldvalue)
	for _i, subt in pairs(t) do
		if subt[fieldname] == fieldvalue then
			return subt
		end
	end
	return nil
end

local reIndex = function()
	local selectedSpells = config.spells[config.selected_type]
	for index, widget in ipairs(screenWidget.mainPanel.spellsList:getChildren()) do
		local entry = table.findbyfield(selectedSpells, "spellName", widget:getId())
		if entry then entry.index = index end
	end
end

doRefreshSpells = function()
	destroyAllWidgets()
	for type, data in pairs(config.spells) do
		for index, entry in ipairs(data) do
			if (config.enabled and entry.enabled and entry.spellTime) then
				setupWidget(entry)
			end
		end
	end
	
	local selectedSpells = config.spells[config.selected_type]
	for index, entry in ipairs(selectedSpells) do
		local widget = setupUI(entryWidget, screenWidget.mainPanel.spellsList)
		local removeSpell = function()
			screenWidget.mainPanel.nameField:setText(entry.spellName)
			table.remove(selectedSpells, index)
			doRefreshSpells()
		end
		
		widget.onDoubleClick = function()
			doRegisterSpell(table.copy(entry))
			removeSpell()
		end
		widget.remove.onClick = removeSpell
		widget.enabled:setChecked(entry.enabled)
		widget.spellTime:setChecked(entry.spellTime)

		widget.enabled.onCheckChange = function(widget, enabled)
			entry.enabled = enabled
			doRefreshSpells()
		end
		widget.spellTime.onCheckChange = function(widget, enabled)
			entry.spellTime = enabled
			doRefreshSpells()
		end

		local formattedName = entry.spellName:sub(1, 10):gsub("^%l", string.upper)
		local text = {formattedName, tr("CD: %ds", entry.cooldownTotal or 0)}

		if (entry.key) then
			local header = entry.key == "AUTO" and "" or "Key: "
			table.insert(text, header .. entry.key)
		end
		
		widget:setText(table.concat(text, " | "))
		widget:setId(entry.spellName)
	end
	reIndex()
end

local doConfigCheck = function()
	local clean_config = {
		spells = { ["Buffs"] = {} },
		enabled = true,
		selected_type = spellsTypes.BUFF
	}

	if (type(storage.especiaisConfig) ~= "table" or not storage.especiaisConfig.spells or not storage.especiaisConfig.spells["Buffs"]) then
		storage.especiaisConfig = clean_config
	end
	config = storage.especiaisConfig
end

local checkLoadableConfigs = function()
	local files = {} -- Configuracoes gerenciadas pelo storage nativo; sem diretorios legados.
	local base_dir = ""
	
	screenWidget.mainPanel.configList:clear()
	screenWidget.mainPanel.configList:addOption(characterName)
	for _, file in ipairs(files) do
		local file_without_extension = file:gsub(".lua", "")
		if (file_without_extension ~= characterName and file:ends(".lua")) then
			local path = base_dir .. "/" .. file
			local content = g_resources.readFileContents(path)
			local status, data = pcall(function() return load("return " .. content)() end)
			if (status and type(data) == "table" and data.especiaisConfig) then
				screenWidget.mainPanel.configList:addOption(file_without_extension)
			end
		end
	end
end

local addAnchors = function(widget)
	local isLabel = widget:getStyleName() == "Label"
	local hasAnyChild = registerWidget.mainPanel:getChildCount() ~= 1
	local lastAnchor = (hasAnyChild or not isLabel) and "prev" or "parent"
	local lastDirection = (hasAnyChild or not isLabel) and 2 or 1
	widget:addAnchor(4, "parent", 4)
	widget:addAnchor(3, "parent", 3)
	widget:addAnchor(1, lastAnchor, lastDirection)
end

local createComboBox = function(data)
	local label = UI.createWidget("Label", registerWidget.mainPanel)
	addAnchors(label)
	label:setMarginTop(7)
	label:setMarginLeft(10)
	label:setText(data.title)
	local comboBox = UI.createWidget("ComboBox", registerWidget.mainPanel)
	addAnchors(comboBox)
	comboBox:setMarginLeft(10)
	comboBox:setMarginRight(10)
	for _, value in ipairs(data.values) do
		comboBox:addOption(value)
	end
	comboBox:setId(data.var_name)
	comboBox:setCurrentOption(data.text)
	comboBox.menuScroll = true
	comboBox.menuScrollStep = 10
end

local createTextEdit = function(data)
	local label = UI.createWidget("Label", registerWidget.mainPanel)
	addAnchors(label)
	label:setMarginTop(7)
	label:setMarginLeft(10)
	label:setText(data.title)
	local textEdit = UI.createWidget("TextEdit", registerWidget.mainPanel)
	addAnchors(textEdit)
	textEdit:setMarginLeft(10)
	textEdit:setMarginRight(10)
	textEdit:setText(data.text)
	textEdit:setId(data.var_name)
end

-- ============================================================
--  STEPPER  ( -  [valor]  +  )  -- substitui a barra com setas < >
--  Mesmo estilo dos botoes do Auto Treino. Mantem a API:
--  getValue() / setValue(v) / onValueChange(widget, valor)
-- ============================================================
local STEPPER_UI = [[
Panel
  height: 22

  Button
    id: minus
    anchors.top: parent.top
    anchors.left: parent.left
    width: 28
    height: 22
    text: <

  TextEdit
    id: edit
    anchors.top: parent.top
    anchors.left: minus.right
    margin-left: 4
    width: 60
    height: 22
    text-align: center

  Button
    id: plus
    anchors.top: parent.top
    anchors.left: edit.right
    margin-left: 4
    width: 28
    height: 22
    text: >

  Label
    id: unit
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: plus.right
    margin-left: 6
]]

local function createStepper(parent, minV, maxV, startValue, unit)
    local w = setupUI(STEPPER_UI, parent)
    w.isStepper = true
    w.minV = minV
    w.maxV = maxV
    w.value = minV
    w.busy = false
    w.unit:setText(unit or "")

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

    w.minus.onClick = function() w:setValue(w.value - 1) end
    w.plus.onClick = function() w:setValue(w.value + 1) end

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
	local label = UI.createWidget("Label", registerWidget.mainPanel)
	addAnchors(label)
	label:setMarginTop(7)
	label:setMarginLeft(10)
	label:setText(data.title)
	local stepper = createStepper(registerWidget.mainPanel, data.range.min, data.range.max, data.text or data.range.min, "s")
	addAnchors(stepper)
	stepper:setMarginLeft(10)
	stepper:setMarginTop(2)
	stepper:setId(data.var_name)
end

doRegisterSpell = function(entry)
	screenWidget:hide()
	registerWidget:show()
	registerWidget.mainPanel:destroyChildren()
	for _, _data in ipairs(displayOptions) do
		local data = table.copy(_data)
		
		if (data.default_value ~= nil) then
			data.text = entry[data.default_value]
		end
		if (entry[data.var_name] ~= nil) then
			data.text = entry[data.var_name]
		end
		if (data.var_name == "key") then
			data.values = getAllKeys()
		end		
		if (data.values) then
			createComboBox(data)
		elseif (data.range) then
			createScrollBar(data)
		else
			createTextEdit(data)
		end
	end
end

local checkKeyPress = function(widget, pressed)
	if (widget.pressed ~= pressed) then
		local setMouseMouveFunction = not pressed and doRemoveMouseMove or doSetMouseMove
		setMouseMouveFunction(widget.entry)
	end
end

local doSetWidgetContent = function(widget)
	local entry = widget.entry
	local time = os.time()
	local color = "green"
	local baseName = entry.showMsg or entry.spellName
	local formattedName = baseName:gsub("^%l", string.upper)
	local text = {tr("%s:", formattedName), "0s"}

	local activeTime = (entry.activeTime or 0) - time
	local cooldownTime = (entry.cooldownTime or 0) - time
	
	if (activeTime >= 0) then
		color = "orange"
		text = tr("%ds", activeTime)
	elseif (cooldownTime >= 0) then
		color = "red"
		text = tr("%ds", cooldownTime)
	else
		entry.cooldownTime = nil
		entry.activeTime = nil
	end
	
	text = table.concat(text, " ")
	if (widget._color ~= color or widget._text ~= text) then
		widget:setColor(color)
		widget:setText(text)
		widget._text = text
		widget._color = color
	end
end

botWidget.switch.onClick = function()
	local status = not botWidget.switch:isOn()
	config.enabled = status
	botWidget.switch:setOn(status)
	doRefreshSpells()
end

botWidget.config.onClick = function() screenWidget:show() end
screenWidget.onEscape = function() screenWidget:hide() end
registerWidget.backButton.onClick = function() registerWidget:hide() screenWidget:show() end
screenWidget.mainPanel.closeButton.onClick = function() screenWidget:hide() end

screenWidget.mainPanel.configList.onOptionChange = function(widget, option)
	if (option == characterName) then return end
	screenWidget.mainPanel.configList:setOption(characterName)
end

screenWidget.mainPanel.typeList.onOptionChange = function(widget, option)
	if (config == nil) then return end
	config.selected_type = option
	doRefreshSpells()
end

screenWidget.mainPanel.addButton.onClick = function()
	local spellName = screenWidget.mainPanel.nameField:getText():lower():trim()
	if (spellName:len() == 0) then return end
	for _, entry in ipairs(config.spells[config.selected_type]) do
		if (entry.spellName == spellName) then return end
	end
	doRegisterSpell({spellName=spellName})
end

registerWidget.addButton.onClick = function()
	local children = registerWidget.mainPanel:getChildren()
	local spellName = screenWidget.mainPanel.nameField:getText():trim():lower()
	local spells = config.spells[config.selected_type]
	
	local entry = {spellName=spellName, enabled=true, type=config.selected_type, index=table.size(spells)+1, spellTime=false}
	
	for _, child in ipairs(children) do
		local var_name = child:getId()
		local styleName = child:getStyleName()
		if (styleName == "ComboBox") then
			local val = child:getCurrentOption().text
			if (val ~= "None") then entry[var_name] = val end
		elseif (styleName == "TextEdit") then
			local t = child:getText():trim():lower()
			if (t:len() >= 1) then entry[var_name] = t end
		elseif (styleName == "HorizontalScrollBar" or child.isStepper) then
			entry[var_name] = child:getValue()
		end
	end
	table.insert(spells, table.copy(entry))
	doRefreshSpells()
	screenWidget:show() registerWidget:hide()
	screenWidget.mainPanel.nameField:clearText()
end

warn = function(msg)
	local widget = screenWidget.mainPanel.message
	widget.added = now + 3000 widget:setText(msg) widget:setColor("yellow")
end

screenWidget.mainPanel.typeList:addOption(spellsTypes.BUFF)
doConfigCheck()
screenWidget.mainPanel.typeList:setCurrentOption(config.selected_type)
screenWidget:hide() registerWidget:hide()
checkLoadableConfigs() doRefreshSpells()
if (config.enabled) then botWidget.switch:setOn(config.enabled) end

onTalk(function(name, level, mode, text)
	if not config.enabled then return end
	if (mode ~= 44 or name ~= characterName) then return end
	text = text:trim():lower()
	for _, data in pairs(config.spells) do
		for _, entry in ipairs(data) do
			if (entry.orangeMsg == text and (entry.cooldownTime or 0) < os.time()) then
				if ((entry.cooldownTotal or 0) > 0) then entry.cooldownTime = os.time() + entry.cooldownTotal end
				if (entry.activeTotal and entry.activeTotal > 0) then entry.activeTime = os.time() + entry.activeTotal end
				break
			end
		end
	end
end)

onTextMessage(function(mode, text)
	if not config.enabled then return end
	if (worldName ~= "NtoUltimate" or not text:find("jutsu foi selado")) then return end
	local time = tonumber(text:match("%d+"))
	if (time ~= nil) then
		for _, entry in pairs(config.spells[spellsTypes.BUFF]) do entry.cooldownTime = os.time() + time end
	end
end)

if (modules._G.buffData == nil) then modules._G.buffData = {} end
local buffData = modules._G.buffData
macro(200, function(self)
	-- PERF: skill medicine nao precisa de polling a 20Hz.
	if (not config.enabled or worldName ~= "NtoUltimate") then return end
	local currentMedicine = player:getSkillLevel(3)
	if (buffData.medicineLast ~= nil and buffData.medicineLast - currentMedicine > 50) then
		local time = os.time() + 5
		for _, entry in pairs(config.spells[spellsTypes.BUFF]) do
			if ((entry.cooldownTime or 0) > time) then entry.cooldownTime = nil end
		end
	end
	buffData.medicineLast = currentMedicine
end)

macro(500, function()
	local widget = screenWidget.mainPanel.message
	if (widget.added and widget.added < now) then widget.added = nil
	elseif (widget.added and widget:isHidden()) then widget:show() end
	if (widget.added == nil and widget:isVisible()) then widget:hide() end
end)

macro((tonumber(storage["scrollBars"] and storage["scrollBars"]["macroDelay"]) or 50), function()
	if (not config.enabled or isInPz()) then return end
	doSpellCast(spellsTypes.BUFF)
end)

local widgetPos
macro(500, function()
	if (widgetPos ~= nil) then
		for _, w in ipairs({screenWidget, registerWidget}) do
			if (w:isHidden()) then w:breakAnchors() w:setPosition(widgetPos) end
		end
		widgetPos = nil
	end
	if (screenWidget:isVisible()) then widgetPos = screenWidget:getPosition()
	elseif (registerWidget:isVisible()) then widgetPos = registerWidget:getPosition() end
end)

macro(250, function()
	if (not config.enabled) then return end
	local dragKeyPressed = isDragKeyPressed()
	for _, widget in ipairs(getAllScreenWidgets()) do
		checkKeyPress(widget, dragKeyPressed)
		doSetWidgetContent(widget)
	end
end)

-- Atalhos: registra esta macro para aparecer na janela Atalhos (aba User).
do
  local g = (type(_G) == "table" and _G) or modules["_G"]
  g.configData = g.configData or {}
  g.configData["buffs"] = {macro = botWidget.switch}
end
