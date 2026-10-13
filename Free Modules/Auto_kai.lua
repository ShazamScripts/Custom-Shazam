-- ============================================================================
-- ANTI TRAP / AUTO KAI (Versão Limpa - Sem Textos Extras no Menu)
-- ============================================================================

autoKaiUI = setupUI("Panel\n  height: 17\n\n  BotSwitch\n    id: macro\n    anchors.top: parent.top\n    anchors.left: parent.left\n    text-align: center\n    width: 130\n    text: Anti Trap\n\n  Button\n    id: config\n    anchors.top: prev.top\n    anchors.bottom: prev.bottom\n    anchors.left: prev.right\n    anchors.right: parent.right\n    text: Config\n")

storage["autoKaiConfig"] = storage["autoKaiConfig"] or {}
local config = storage["autoKaiConfig"]

-- Define a magia padrão inicial caso não exista nenhuma salva no seu bot
config["myRemoveSpell"] = config["myRemoveSpell"] or "Kai"

if (g_game.getWorldName():upper() == "NTOLOST" and config["myRemoveSpell"] == "Kai") then
    config["myRemoveSpell"] = "Jyuu No Jutsu"
end

local autoKaiCaster = { rootWidget = g_ui.getRootWidget() }

function string:ucwords()
    local cases = {" ", ":", ""}
    for index, case in ipairs(cases) do cases[case] = true; cases[index] = nil end
    local newStr = ""
    for i = 1, #self do
        local str = self:sub(i, i):lower()
        local previous = self:sub(i - 1, i - 1)
        if (cases[previous]) then str = str:upper() end
        newStr = newStr .. str
    end
    return newStr:trim()
end

autoKaiCaster["spellEntry"] = "Label\n  background-color: alpha\n  text-offset: 18 1\n  focusable: true\n  height: 16\n  font: verdana-11px-rounded\n\n  CheckBox\n    id: enabled\n    anchors.left: parent.left\n    anchors.verticalCenter: parent.verticalCenter\n    width: 15\n    height: 15\n    margin-top: 2\n    margin-left: 3\n\n  Button\n    id: remove\n    text: x\n    anchors.right: parent.right\n    margin-right: 15\n    width: 15\n    height: 15\n"

-- Macro de Execução ANÔNIMA (Removeu o bug do texto extra na lista do bot)
autoKaiCaster["executionMacro"] = macro(100, function()
    if (not config["requestKai"]) then return end
    if (isInPz()) then return end
    if (config["kaiExhaust"] and config["kaiExhaust"] >= os.time()) then return end
    
    -- Conjura a magia que você configurou no painel
    if canShazamMacroAct("autoKai", 100) then say(config["myRemoveSpell"]) end
end)

config["macroActive"] = config["macroActive"] or false
autoKaiUI["macro"].onClick = function()
    config["macroActive"] = not config["macroActive"]
    autoKaiUI["macro"]:setOn(config["macroActive"])
    autoKaiCaster["executionMacro"]:setOn(config["macroActive"])
end

autoKaiUI["config"].onClick = function()
    local window = autoKaiCaster["window"]
    if (window:isHidden()) then window:show(); window:raise(); window:focus() else window:hide() end
end

-- Janela de Configurações Expandida com a Opção de Mudar sua Magia de Remoção
autoKaiCaster["window"] = setupUI("MainWindow\n  size: 450 255\n  !text: tr('Anti Trap By Shazam')\n\n  Panel\n    id: mainPanel\n    image-source: /images/ui/panel_flat\n    anchors.fill: parent\n    image-border: 6\n\n    TextEdit\n      id: mySpellInput\n      anchors.top: parent.top\n      anchors.left: parent.left\n      margin-top: 15\n      margin-left: 10\n      width: 185\n\n    Label\n      text: Magia Anti Trap (Seu Boneco)\n      anchors.bottom: prev.top\n      anchors.left: prev.left\n\n    TextList\n      id: spellsList\n      anchors.top: mySpellInput.bottom\n      anchors.left: parent.left\n      size: 200 145\n      margin-top: 15\n      margin-left: 10\n      image-source: /images/ui/textedit\n      vertical-scrollbar: spellsListScroll\n\n    VerticalScrollBar\n      id: spellsListScroll\n      anchors.top: spellsList.top\n      anchors.bottom: spellsList.bottom\n      anchors.right: spellsList.right\n      step: 10\n\n    TextEdit\n      id: spellName\n      anchors.top: parent.top\n      anchors.left: spellsList.right\n      margin-left: 30\n      margin-top: 15\n      width: 150\n\n    Label\n      text: Nome da Magia Inimiga\n      anchors.bottom: prev.top\n      anchors.left: prev.left\n\n    TextEdit\n      id: sealedTime\n      anchors.top: spellName.bottom\n      anchors.left: spellName.left\n      width: 150\n      margin-top: 20\n\n    Label\n      text: Tempo Selado (Segundos)\n      anchors.bottom: prev.top\n      anchors.left: prev.left\n\n    TextEdit\n      id: sealType\n      anchors.top: sealedTime.bottom\n      anchors.left: sealedTime.left\n      width: 150\n      margin-top: 20\n\n    Label\n      text: Tipo (Buff, Speed, Kai)\n      anchors.bottom: prev.top\n      anchors.left: prev.left\n\n    Button\n      id: addButton\n      text: Adicionar Magia\n      anchors.top: sealType.bottom\n      anchors.left: spellName.left\n      width: 150\n      margin-top: 10\n      height: 25\n\n    Label\n      id: infoDisplay\n      anchors.left: addButton.left\n      anchors.bottom: parent.bottom\n\n  Button\n    id: closeButton\n    text: x\n    anchors.right: parent.right\n    anchors.top: parent.top\n    size: 25 20\n", autoKaiCaster["rootWidget"])

autoKaiCaster["window"]:hide()
autoKaiCaster["window"]["closeButton"].onClick = autoKaiUI["config"].onClick

-- Carrega o texto salvo na caixinha de input
autoKaiCaster["window"]["mainPanel"]["mySpellInput"]:setText(config["myRemoveSpell"])
autoKaiCaster["window"]["mainPanel"]["mySpellInput"]["onTextChange"] = function(widget, text)
    config["myRemoveSpell"] = text:trim()
end

autoKaiCaster["window"]["mainPanel"]["addButton"].onClick = function()
    local spellName = autoKaiCaster["window"]["mainPanel"]["spellName"]:getText():ucwords()
    local sealedTime = tonumber(autoKaiCaster["window"]["mainPanel"]["sealedTime"]:getText()) or 0
    local sealType = autoKaiCaster["window"]["mainPanel"]["sealType"]:getText():trim():ucwords()

    if (#spellName == 0) then return end
    config[spellName] = { spell = spellName, sealedTime = sealedTime, sealType = sealType, enabled = true }
    autoKaiCaster["window"]["mainPanel"]["spellName"]:clearText()
    autoKaiCaster["window"]["mainPanel"]["sealType"]:clearText()
    autoKaiCaster["window"]["mainPanel"]["sealedTime"]:clearText()
    autoKaiCaster["refreshSpells"]()
end

storage["attackingPlayers"] = storage["attackingPlayers"] or {}
macro(500, function()
    for name, time in pairs(storage["attackingPlayers"]) do
        if (os.time() >= time) then storage["attackingPlayers"][name] = nil end
    end
end)

onTextMessage(function(mode, text)
    if (not text:find("attack by")) then return end
    text = text:sub(9)
    local specs = (ShazamCore and ShazamCore.getSpectators(false, 80) or getSpectators())
    for _, spec in ipairs(specs) do
        if (spec:isPlayer()) then
            local specName = spec:getName()
            if (text:find(specName, 1, true)) then
                storage["attackingPlayers"][specName] = os.time() + 1
                break
            end
        end
    end
end)

storage["sealedTypes"] = storage["sealedTypes"] or {}
onTalk(function(name, level, mode, text)
    if (mode ~= 44) then return end
    if (storage["attackingPlayers"][name]) then
        text = text:ucwords()
        local index = config[text]
        if (not index) then return end
        
        for _, val in ipairs(index["sealType"]:split(",")) do
            val = val:lower():trim()
            if (val ~= "kai") then
                storage["sealedTypes"][val] = os.time() + index["sealedTime"]
            else
                config["kaiExhaust"] = os.time() + index["sealedTime"]
            end
        end
        config["requestKai"] = true
    elseif (player:getName() == name) then
        text = text:ucwords()
        if (text:lower() == config["myRemoveSpell"]:lower()) then
            config["kaiExhaust"] = os.time() + (g_game.getWorldName():upper() == "NTOLOST" and 60 or 1)
            config["requestKai"] = false
        end
    end
end)

autoKaiCaster["refreshSpells"] = function()
    for _, child in ipairs(autoKaiCaster["window"]["mainPanel"]["spellsList"]:getChildren()) do child:destroy() end
    for spellName, value in pairs(config) do
        if (type(value) == "table" and value["spell"]) then
            local children = setupUI(autoKaiCaster["spellEntry"], autoKaiCaster["window"]["mainPanel"]["spellsList"])
            children["enabled"]:setChecked(value["enabled"])
            local formattedText = value["spell"] .. ": " .. value["sealType"] .. " por " .. value["sealedTime"] .. "s"
            children:setText(formattedText)
            
            local removeFunc = function()
                config[spellName] = nil
                autoKaiCaster["window"]["mainPanel"]["spellName"]:setText(value["spell"])
                autoKaiCaster["window"]["mainPanel"]["sealType"]:setText(value["sealType"])
                autoKaiCaster["window"]["mainPanel"]["sealedTime"]:setText(value["sealedTime"])
                autoKaiCaster["refreshSpells"]()
            end
            children["remove"].onClick = removeFunc
            children.onDoubleClick = removeFunc
            children["enabled"].onClick = function()
                value["enabled"] = not value["enabled"]
                autoKaiCaster["refreshSpells"]()
            end
        end
    end
end

autoKaiCaster["refreshSpells"]()


-- Atalhos: registra esta macro para aparecer na janela Atalhos (aba User).
do
  local g = (type(_G) == "table" and _G) or modules["_G"]
  g.configData = g.configData or {}
  g.configData["antiTrap"] = {macro = autoKaiUI["macro"]}
end
