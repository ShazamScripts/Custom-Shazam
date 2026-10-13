-- ============================================================================
-- CORE SYSTEM + SHAZAM GUARD
--
-- 1) SHAZAM GUARD: tudo que a custom "pendura" no client (fala, filtro do Battle,
--    connect() em g_game / mapa, widgets soltos na tela, tamanho da janela do bot)
--    passa a ser registrado aqui e DESFEITO quando a custom e recarregada,
--    desligada ou quando voce abre OUTRA custom.
--    Esse era o motivo das outras customs pararem de funcionar: os hooks da
--    Shazam continuavam ativos (e quebrados) dentro do client.
-- 2) FILA DE FALA (anti-spam) com prioridade.
-- 3) SALVAMENTO SEGURO ao desligar/recarregar o bot.
--
-- Versao independente para OTClient / vBot.
-- ============================================================================

local realG = modules["_G"]

-- Os hooks abaixo podem continuar rodando depois que o bot recarrega, entao eles
-- NUNCA dependem de globais do ambiente antigo: tudo e capturado aqui.
local pcall, type, print, tostring, tonumber = pcall, type, print, tostring, tonumber
local pairs, ipairs = pairs, ipairs
local table_insert, table_sort = table.insert, table.sort
local gameRef = g_game
local clockRef = g_clock or realG["g_clock"]
local uiRef = g_ui or realG["g_ui"]

local function nowMs()
    if clockRef and clockRef.millis then return clockRef.millis() end
    return 0
end

-- ============================================================================
-- [PARTE 0] ENCERRA A SESSAO ANTERIOR (recarga da propria Shazam)
-- ============================================================================
local previousGuard = realG["__ShazamSession"]
if type(previousGuard) == "table" and type(previousGuard.shutdown) == "function" then
    pcall(previousGuard.shutdown, "reload")
end

-- Flag antiga que travava a fila de fala de qualquer custom depois de um reload.
if realG["talking_event"] ~= nil then realG["talking_event"] = nil end

-- ============================================================================
-- [PARTE 1] SHAZAM GUARD
-- ============================================================================
local Session = {
    heartbeat = nowMs(),
    dead = false,
    cleanups = {},
    widgets = {},
}

local Guard = { session = Session }
Guard.SOFT_TIMEOUT = 8000   -- sem sinal de vida: hooks viram "passa direto"
Guard.HARD_TIMEOUT = 45000  -- sem sinal de vida por muito tempo: desfaz tudo

function Guard.beat()
    Session.heartbeat = nowMs()
end

-- Sessao viva = a Shazam esta rodando de verdade neste momento.
function Guard.alive()
    return (not Session.dead) and (nowMs() - Session.heartbeat) < Guard.SOFT_TIMEOUT
end

-- Igual a alive(), mas se a Shazam sumiu de vez (outra custom aberta) desfaz tudo.
function Guard.check()
    if Session.dead then return false end
    local age = nowMs() - Session.heartbeat
    if age >= Guard.HARD_TIMEOUT then
        Guard.shutdown("stale")
        return false
    end
    return age < Guard.SOFT_TIMEOUT
end

function Guard.onCleanup(fn)
    if type(fn) == "function" then table_insert(Session.cleanups, fn) end
end

function Guard.trackWidget(widget)
    if widget then table_insert(Session.widgets, widget) end
    return widget
end

function Guard.shutdown(reason)
    if Session.dead then return end
    Session.dead = true

    for i = #Session.cleanups, 1, -1 do
        pcall(Session.cleanups[i], reason)
    end
    Session.cleanups = {}

    for _, widget in ipairs(Session.widgets) do
        pcall(function()
            if widget and not widget:isDestroyed() then widget:destroy() end
        end)
    end
    Session.widgets = {}

    if realG["__ShazamSession"] == Guard then realG["__ShazamSession"] = nil end
end

-- connect() seguro: handler protegido por pcall, ignorado se a Shazam nao esta
-- viva e desconectado automaticamente ao desligar. Um erro dentro de um handler
-- de g_game derrubava os handlers do proprio client (e de outras customs).
function Guard.connect(object, handlers)
    local connectFn, disconnectFn = realG["connect"], realG["disconnect"]
    if object == nil or type(connectFn) ~= "function" or type(handlers) ~= "table" then
        return nil
    end

    local wrapped = {}
    local disconnecting = false

    for signal, fn in pairs(handlers) do
        wrapped[signal] = function(...)
            if not Guard.check() then
                if Session.dead and not disconnecting and type(disconnectFn) == "function" then
                    disconnecting = true
                    local schedule = realG["addEvent"]
                    if type(schedule) == "function" then
                        schedule(function() pcall(disconnectFn, object, wrapped) end)
                    end
                end
                return
            end
            local ok, result = pcall(fn, ...)
            if not ok then
                print("[Shazam Guard] erro em " .. tostring(signal) .. ": " .. tostring(result))
                return
            end
            return result
        end
    end

    local ok = pcall(connectFn, object, wrapped)
    if not ok then return nil end

    Guard.onCleanup(function()
        if type(disconnectFn) == "function" then pcall(disconnectFn, object, wrapped) end
    end)
    return wrapped
end

-- Sinal de vida: roda so enquanto o bot da Shazam esta realmente carregado.
macro(500, function() Guard.beat() end)

ShazamGuard = Guard
realG["__ShazamSession"] = Guard

-- ============================================================================
-- [PARTE 2] SISTEMA DE FALA INTELIGENTE (FILA DE PRIORIDADES)
-- ============================================================================
-- Nomes proprios (__Shazam...) para nao dividir estado com outras customs
-- (sayList / talk_function / talking_event eram compartilhados e travavam).

do
    -- Se ficou um wrapper da Shazam de uma sessao anterior, volta o original.
    local oldWrapper, oldOriginal = realG["__ShazamTalkWrapper"], realG["__ShazamTalkOriginal"]
    if oldWrapper and oldOriginal and gameRef["talk"] == oldWrapper then
        gameRef["talk"] = oldOriginal
    end

    local baseTalk = gameRef["talk"]
    local pending = {}
    local seq = 0
    local flushScheduled = false
    local scheduleEventFn = realG["scheduleEvent"]

    local function trim(text)
        return (text:gsub("^%s+", ""):gsub("%s+$", ""))
    end

    local function flush()
        flushScheduled = false
        if #pending == 0 then return end

        local list = pending
        pending = {}

        table_sort(list, function(a, b)
            if a.priority ~= b.priority then return a.priority > b.priority end
            return a.seq < b.seq
        end)

        local seen = {}
        for _, item in ipairs(list) do
            local spell = trim(item.spell)
            local key = spell:lower()
            if spell ~= "" and not seen[key] then
                seen[key] = true
                local ok, err = pcall(baseTalk, spell)
                if not ok then
                    print("[Shazam Guard] erro ao falar '" .. spell .. "': " .. tostring(err))
                end
            end
        end
    end

    local function talkWrapper(spell, priority, ...)
        if spell == nil then return end

        -- Shazam parada/desligada: fala normal, sem fila.
        if not Guard.check() then
            return baseTalk(spell, priority, ...)
        end

        spell = tostring(spell)
        priority = tonumber(priority)
        if priority == nil then
            priority = 0
            if spell:lower():find("regen") then
                priority = -1 -- regeneracao passiva vai para o fim da fila
            end
        end

        seq = seq + 1
        table_insert(pending, { spell = spell, priority = priority, seq = seq })

        if not flushScheduled then
            flushScheduled = true
            if type(scheduleEventFn) == "function" then
                -- scheduleEvent global (nao o schedule do bot): nao some no reload.
                scheduleEventFn(flush, 5)
            else
                flush()
            end
        end
    end

    gameRef["talk"] = talkWrapper
    realG["__ShazamTalkWrapper"] = talkWrapper
    realG["__ShazamTalkOriginal"] = baseTalk
    say = talkWrapper

    Guard.onCleanup(function()
        if gameRef["talk"] == talkWrapper then
            gameRef["talk"] = baseTalk
        end
        pending = {}
        flushScheduled = false
    end)
end

-- ============================================================================
-- [PARTE 3] SALVAMENTO AUTOMATICO SEGURO (ANTI-BUG AO DESLIGAR O BOT)
-- ============================================================================

local registeredExitFunctions = {}

local function executeOnExitCallbacks()
    for _, callback in ipairs(registeredExitFunctions) do
        pcall(callback)
    end
end

onExitRegister = function(func)
    if type(func) ~= "function" then return end
    for _, existing in ipairs(registeredExitFunctions) do
        if existing == func then return end
    end
    table_insert(registeredExitFunctions, func)
end

Guard.onCleanup(function() registeredExitFunctions = {} end)

pcall(function()
    local game_bot = modules["game_bot"]
    if type(game_bot) ~= "table" then return end

    local enableButton = uiRef.getRootWidget():recursiveGetChildById("enableButton")
    local GameBot = realG["GameBot"]

    local function runExitIfOn()
        if Guard.alive() and enableButton and enableButton:getText() == "On" then
            executeOnExitCallbacks()
        end
    end

    if (game_bot["save_function"] == nil) then
        game_bot["isMainFunction"] = true
        game_bot["save_function"] = game_bot["save"]
    end

    if (game_bot["save_function"] == nil) then
        game_bot["isMainFunction"] = false
        game_bot["save_function"] = GameBot and GameBot["refresh"] or game_bot["refresh"]
    end

    local function callOriginal()
        if type(game_bot["save_function"]) == "function" then
            return game_bot["save_function"]()
        end
    end

    if (game_bot["isMainFunction"]) then
        game_bot["save"] = function()
            runExitIfOn()
            return callOriginal()
        end
    else
        if (game_bot["refresh"] ~= nil) then
            game_bot["refresh"] = function()
                runExitIfOn()
                return callOriginal()
            end
        elseif GameBot and GameBot["refresh"] then
            GameBot["refresh"] = function()
                runExitIfOn()
                return callOriginal()
            end
        end
    end
end)


-- ============================================================================
-- [SHAZAM CORE 2.0] Infraestrutura compartilhada de performance
-- ============================================================================
ShazamCore = ShazamCore or {}
do
  local C = ShazamCore
  C.version = "2.0"
  C.debug = false
  C.specTTL = 100
  C.pathTTL = 180
  C._spec = {}
  C._paths = {}
  C._jobs = {}
  C._jobIndex = 1

  local function tick()
    return tonumber(now) or 0
  end

  -- Cache curtissimo: reduz scans repetidos no MESMO momento sem deixar combate lento.
  function C.getSpectators(multifloor, ttl)
    local key = multifloor and "multi" or "single"
    local t = tick()
    local e = C._spec[key]
    ttl = tonumber(ttl) or C.specTTL
    if e and t - e.at <= ttl then return e.list end
    local ok, list = pcall(getSpectators, multifloor == true)
    if not ok or type(list) ~= "table" then list = {} end
    C._spec[key] = {at=t, list=list}
    return list
  end

  function C.invalidateSpectators()
    C._spec = {}
  end

  -- PERF: acesso direto ao tile quando a posicao ja e conhecida; evita g_map.getTiles().
  function C.getTile(p)
    if not p then return nil end
    return g_map.getTile(p)
  end

  -- Path cache opt-in. Modulos criticos continuam livres para calcular imediatamente.
  function C.findPath(fromPos, toPos, maxDist, flags, ttl)
    if not fromPos or not toPos or fromPos.z ~= toPos.z then return nil end
    ttl = tonumber(ttl) or C.pathTTL
    local t=tick()
    local key=fromPos.x..":"..fromPos.y..":"..fromPos.z..">"..toPos.x..":"..toPos.y..":"..toPos.z..":"..tostring(maxDist)
    local e=C._paths[key]
    if e and t-e.at<=ttl then return e.path end
    local path=findPath(fromPos,toPos,maxDist,flags)
    C._paths[key]={at=t,path=path}
    return path
  end

  -- Scheduler cooperativo SOMENTE para tarefas de background que optarem por ele.
  -- Nao intercepta Combo/Target/Enemy/Jump ou outras rotinas criticas.
  function C.addBackgroundJob(name, fn)
    if type(fn)=="function" then C._jobs[#C._jobs+1]={name=name,fn=fn} end
  end

  function C.measure(name, fn)
    if not C.debug then return fn() end
    local start=tick()
    local ok,a,b,c=pcall(fn)
    local dt=tick()-start
    if dt>=50 then print("[ShazamPerf] "..tostring(name).." "..tostring(dt).."ms") end
    if not ok then error(a) end
    return a,b,c
  end

  macro(100, function()
    if #C._jobs==0 then return end
    if C._jobIndex>#C._jobs then C._jobIndex=1 end
    local job=C._jobs[C._jobIndex]
    C._jobIndex=C._jobIndex+1
    if job and job.fn then pcall(job.fn) end
  end)

  -- Limpeza evita crescimento ilimitado do cache de caminhos.
  macro(5000, function()
    local t=tick()
    for k,e in pairs(C._paths) do
      if not e or t-(e.at or 0)>1500 then C._paths[k]=nil end
    end
  end)
end
