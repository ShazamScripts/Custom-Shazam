setDefaultTab("Others")

local panelName = 'Shazam BLESS'
local blessCommand = '!bless'

local c_neon   = '#36f25e'
local c_danger = '#ff5555'
local c_warn   = '#fcae1e'
local c_war    = '#d636f2'

storage[panelName] = storage[panelName] or {}

-- =========================================================
-- CONFIGURAÇÃO PADRÃO
-- =========================================================

local defaultConfig = {
    enabled = true,
    autoBuy = true,
    isBlessed = false,
    checkInterval = 3,
    lastExp = 0,
    failCount = 0,
    nextBuyTime = 0,
    savedTime = 0,
    noMoneyDetected = false
}

-- =========================================================
-- RELÓGIO
-- Compatível com versões que não possuem g_clock
-- =========================================================

local function getTime()
    return os.time()
end

-- =========================================================
-- CONFIGURAÇÃO POR PERSONAGEM
-- =========================================================

local function getCharConfig()

    local player = g_game.getLocalPlayer()

    if not player then
        return defaultConfig
    end

    local name = player:getName()

    if not storage[panelName][name] then

        storage[panelName][name] = {
            enabled = defaultConfig.enabled,
            autoBuy = defaultConfig.autoBuy,
            isBlessed = defaultConfig.isBlessed,
            checkInterval = defaultConfig.checkInterval,
            lastExp = defaultConfig.lastExp,
            failCount = defaultConfig.failCount,
            nextBuyTime = defaultConfig.nextBuyTime,
            savedTime = defaultConfig.savedTime,
            noMoneyDetected = defaultConfig.noMoneyDetected
        }

    end

    return storage[panelName][name]
end

-- =========================================================
-- UI PRINCIPAL
-- =========================================================

local mainUi = setupUI([[
Panel
  height: 110
  margin-top: 5

  Label
    id: titleLabel
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    text-align: center
    text: Shazam Bless 1.0
    color: #36f25e
    font: verdana-11px-rounded

  BotSwitch
    id: toggleScript
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    text: Ativar Monitor
    margin-top: 8
    height: 18

  CheckBox
    id: autoBuyCheck
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 8
    text: Auto Comprar (War Mode)

  Button
    id: verifyBtn
    anchors.top: prev.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 10
    text: Resetar / Verificar
    height: 20
]], parent)

mainUi:setId(panelName)

-- =========================================================
-- POSIÇÃO DO HUD
-- =========================================================

storage.widgetPos_V9 = storage.widgetPos_V9 or {
    x = 50,
    y = 50
}

-- =========================================================
-- HUD
-- =========================================================

local hudUi = setupUI([[
UIWidget
  background-color: #000000cc
  border-width: 1
  border-color: #36f25e
  padding: 0
  width: 110
  height: 42
  draggable: true
  focusable: true

  Label
    id: statusLabel
    anchors.fill: parent
    text-align: center
    text: ...
    font: verdana-11px-rounded
    color: #36f25e
]], g_ui.getRootWidget())

hudUi:setPosition(storage.widgetPos_V9)

-- =========================================================
-- ALERTA SEM DINHEIRO
-- =========================================================

local alertUi = setupUI([[
Label
  id: screenAlert
  anchors.centerIn: parent
  text: !!! SEM GRANA PARA BLESS !!!
  color: #ff5555
  font: verdana-11px-rounded
  text-align: center
  background-color: #000000aa
  padding: 10
  width: 200
  visible: false
  phantom: true
]], g_ui.getRootWidget())

-- =========================================================
-- MOVER HUD
-- Segure CTRL e arraste
-- =========================================================

hudUi.onDragEnter = function(widget, mousePos)

    if not modules.corelib.g_keyboard.isCtrlPressed() then
        return false
    end

    widget:breakAnchors()

    widget.movingReference = {
        x = mousePos.x - widget:getX(),
        y = mousePos.y - widget:getY()
    }

    return true
end

hudUi.onDragMove = function(widget, mousePos, moved)

    local parentRect = widget:getParent():getRect()

    local x = math.min(
        math.max(
            parentRect.x,
            mousePos.x - widget.movingReference.x
        ),
        parentRect.x +
        parentRect.width -
        widget:getWidth()
    )

    local y = math.min(
        math.max(
            parentRect.y - widget:getParent():getMarginTop(),
            mousePos.y - widget.movingReference.y
        ),
        parentRect.y +
        parentRect.height -
        widget:getHeight()
    )

    widget:move(x, y)

    storage.widgetPos_V9 = {
        x = x,
        y = y
    }

    return true
end

-- =========================================================
-- SALVAR ESTADO DA BLESS
-- =========================================================

local function saveCharState(isBlessed)

    local cfg = getCharConfig()

    cfg.isBlessed = isBlessed
    cfg.savedTime = getTime()

    if isBlessed then
        cfg.noMoneyDetected = false
    end
end

-- =========================================================
-- VALIDAR SESSÃO
-- =========================================================

local function validateSession()

    local cfg = getCharConfig()

    local timeDiff =
        getTime() - (cfg.savedTime or 0)

    -- Depois de 30 minutos sem atualização,
    -- considera que precisa verificar novamente.
    -- Não invalidar bless apenas pelo tempo: só uma morte ou
    -- resposta explícita do servidor deve alterar o estado.
    -- A verificação manual continua disponível no botão.
    if timeDiff > 1800 then
        cfg.savedTime = getTime()
    end
end

-- =========================================================
-- VERIFICA PZ LOCK
-- =========================================================

local function isPlayerLocked(player)

    if player.isPzLocked then
        return player:isPzLocked()

    elseif player.hasState
        and PlayerStates
        and PlayerStates.PzBlock then

        return player:hasState(PlayerStates.PzBlock)
    end

    return false
end

-- =========================================================
-- ATUALIZA HUD
-- =========================================================

local function updateVisuals()

    local cfg = getCharConfig()

    -- DESATIVADO
    if not cfg.enabled then

        hudUi:hide()
        alertUi:hide()

        return
    end

    local player = g_game.getLocalPlayer()

    if not player then
        return
    end

    -- =====================================================
    -- PZ
    -- =====================================================

    local isInPz = false

    if player.isInProtectionZone then
        isInPz = player:isInProtectionZone()
    end

    local isPzLocked =
        isPlayerLocked(player)

    -- =====================================================
    -- ALERTA SEM DINHEIRO
    -- =====================================================

    if cfg.noMoneyDetected then

        alertUi:show()

        -- Pisca a cada segundo
        if getTime() % 2 == 0 then
            alertUi:setColor('#ff5555')
        else
            alertUi:setColor('#ffff00')
        end

    else

        alertUi:hide()

    end

    -- =====================================================
    -- ESCONDE HUD SE ESTÁ BLESSED DENTRO DA PZ
    -- =====================================================

    if cfg.isBlessed and isInPz then
        hudUi:hide()
    else
        hudUi:show()
    end

    -- =====================================================
    -- SEM DINHEIRO
    -- =====================================================

    if cfg.noMoneyDetected then

        hudUi:setBorderColor(c_danger)

        hudUi.statusLabel:setText(
            "Gold Insuficiente\n(Alerta de Perigo)"
        )

        hudUi.statusLabel:setColor(c_danger)

        mainUi.titleLabel:setColor(c_danger)

        return
    end

    -- =====================================================
    -- BLESSED
    -- =====================================================

    if cfg.isBlessed then

        hudUi:setBorderColor(c_neon)

        hudUi.statusLabel:setText(
            "PROTEGIDO\n(Blessed)"
        )

        hudUi.statusLabel:setColor(c_neon)

        mainUi.titleLabel:setColor(c_neon)

        return
    end

    -- =====================================================
    -- NÃO BLESSED
    -- =====================================================

    local currentColor

    if isPzLocked then

        if getTime() % 2 == 0 then
            currentColor = c_war
        else
            currentColor = c_danger
        end

    else

        if getTime() % 2 == 0 then
            currentColor = c_danger
        else
            currentColor = c_warn
        end

    end

    hudUi:setBorderColor(currentColor)
    hudUi.statusLabel:setColor(currentColor)

    mainUi.titleLabel:setColor(c_danger)

    -- =====================================================
    -- TEXTO DO HUD
    -- =====================================================

    if cfg.autoBuy then

        local timeLeft =
            cfg.nextBuyTime - getTime()

        if isPzLocked then

            hudUi.statusLabel:setText(
                "WAR MODE\nTentando..."
            )

        elseif timeLeft > 0 then

            hudUi.statusLabel:setText(
                "Tentando em:\n" ..
                tostring(timeLeft) ..
                "s"
            )

        else

            hudUi.statusLabel:setText(
                "COMPRANDO..."
            )

        end

    else

        hudUi.statusLabel:setText(
            "VULNERAVEL\n(!!!)"
        )

    end
end

-- =========================================================
-- BOTÃO ATIVAR / DESATIVAR
-- =========================================================

mainUi.toggleScript.onClick = function(widget)

    local cfg = getCharConfig()

    cfg.enabled = not cfg.enabled

    widget:setOn(cfg.enabled)

    updateVisuals()
end

-- =========================================================
-- AUTO BUY
-- =========================================================

mainUi.autoBuyCheck.onClick = function(widget)

    local cfg = getCharConfig()

    cfg.autoBuy = not cfg.autoBuy

    widget:setChecked(cfg.autoBuy)

    cfg.failCount = 0
    cfg.nextBuyTime = 0
    cfg.noMoneyDetected = false

    updateVisuals()
end

-- =========================================================
-- BOTÃO RESETAR / VERIFICAR
-- =========================================================

mainUi.verifyBtn.onClick = function()

    local cfg = getCharConfig()

    cfg.isBlessed = false
    cfg.noMoneyDetected = false
    cfg.failCount = 0
    cfg.nextBuyTime = 0

    say(blessCommand)

    -- Aguarda 2 segundos pela resposta
    cfg.nextBuyTime =
        getTime() + 2

    updateVisuals()
end

-- =========================================================
-- ATUALIZA OS BOTÕES
-- =========================================================

macro(1000, function()

    local cfg = getCharConfig()

    mainUi.toggleScript:setOn(
        cfg.enabled
    )

    mainUi.autoBuyCheck:setChecked(
        cfg.autoBuy
    )
end)

-- =========================================================
-- RECEBE MENSAGENS DO SERVIDOR
-- =========================================================

onTextMessage(function(mode, text)

    local cfg = getCharConfig()

    if not cfg.enabled then
        return
    end

    if not text then
        return
    end

    local msg = text:lower()

    -- =====================================================
    -- SEM TODAS AS BLESSES
    --
    -- Exemplo:
    -- "Atenção: Você está sem todas as blesses!
    --  Digite !bless para comprá-las."
    -- =====================================================

    if msg:find("sem todas as blesses")
       or msg:find("sem todas as bless") then

        saveCharState(false)

        cfg.noMoneyDetected = false
        cfg.failCount = 0

        -- Tenta novamente em 1 segundo
        cfg.nextBuyTime =
            getTime() + 1

        updateVisuals()

        return
    end

    -- =====================================================
    -- JÁ POSSUI TODAS AS BLESSES
    --
    -- Exemplo:
    -- "Você já possui todas as blesses."
    --
    -- Procuramos somente por:
    -- "possui todas as blesses"
    --
    -- Assim não importa o acento de "já".
    -- =====================================================

    if msg:find("possui todas as blesses")
       or msg:find("possui todas as bless")
       or msg:find("you already have all blessings", 1, true)
       or msg:find("already have all blessings", 1, true) then

        saveCharState(true)

        cfg.failCount = 0
        cfg.nextBuyTime = 0
        cfg.noMoneyDetected = false

        updateVisuals()

        return
    end

    -- =====================================================
    -- SEM DINHEIRO
    -- =====================================================

    if
        (
            msg:find("dinheiro")
            and
            msg:find("suficiente")
        )
        or
        (
            msg:find("precisa")
            and
            msg:find("ryo")
        )
        or
        msg:find("not have enough money")
        or
        msg:find("not enough money")
    then

        saveCharState(false)

        cfg.noMoneyDetected = true

        -- Não fica spammando !bless
        cfg.nextBuyTime =
            getTime() + 10

        updateVisuals()

        return
    end

    -- =====================================================
    -- MORTE
    -- =====================================================

    if msg:find("you are dead")
       or msg:find("you were downgraded")
       or msg:find("you died") then

        saveCharState(false)

        cfg.failCount = 0
        cfg.nextBuyTime = 0
        cfg.noMoneyDetected = false

        updateVisuals()

        return
    end
end)

-- =========================================================
-- MONITOR PRINCIPAL
-- =========================================================

macro(1000, function()

    local cfg = getCharConfig()

    if not cfg.enabled then
        return
    end

    local player =
        g_game.getLocalPlayer()

    if not player then
        return
    end

    local now = getTime()

    -- =====================================================
    -- CORRIGE TIMER INVÁLIDO
    -- =====================================================

    if cfg.nextBuyTime > (now + 20) then
        cfg.nextBuyTime = now + 1
    end

    -- =====================================================
    -- DETECTA MORTE PELO XP
    -- =====================================================

    local currentExp =
        player:getExperience()

    if cfg.lastExp > 0
       and currentExp < cfg.lastExp then

        saveCharState(false)

        cfg.failCount = 0
        cfg.nextBuyTime = 0
        cfg.noMoneyDetected = false

        hudUi:show()

        hudUi.statusLabel:setText(
            "MORTE DETECTADA"
        )
    end

    cfg.lastExp = currentExp

    -- =====================================================
    -- AUTO COMPRAR BLESS
    -- =====================================================

    if cfg.autoBuy
       and not cfg.isBlessed
       and not cfg.noMoneyDetected then

        if now >= cfg.nextBuyTime then

            local isPzLocked =
                isPlayerLocked(player)

            -- Envia !bless
            say(blessCommand)

            -- =================================================
            -- WAR MODE / PZ LOCK
            -- =================================================

            if isPzLocked then

                cfg.nextBuyTime =
                    now + math.random(1, 2)

            else

                -- =================================================
                -- FORA DO WAR MODE
                -- =================================================

                cfg.nextBuyTime =
                    now + math.random(3, 4)

            end
        end
    end

    updateVisuals()
end)

-- =========================================================
-- RESET INICIAL
-- =========================================================

local function initReset()

    local cfg = getCharConfig()

    cfg.nextBuyTime = 0
    cfg.failCount = 0

    -- Não apaga isBlessed aqui.
    -- Assim o estado salvo continua.
end

validateSession()
initReset()
updateVisuals()
