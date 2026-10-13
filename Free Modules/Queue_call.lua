-- ============================================================================
-- SYSTEM: TASK QUEUE MANAGER (Gerenciador de Fila de Ações - Sem sistema anterior)
-- Evita quedas de FPS e kicks ao executar muitas macros juntas
-- ============================================================================

local queue = {}
local pending = {}
local head, tail = 1, 0
local addEventLocal = modules["_G"]["addEvent"]

-- Consulta O(1), sem percorrer a fila inteira.
isOnQueue = function(func)
    return pending[func] == true
end

putOnQueue = function(func)
    if type(func) ~= "function" or pending[func] then return end
    tail = tail + 1
    queue[tail] = func
    pending[func] = true
end

-- Mantem a cadencia original: uma acao por ciclo.
macro(100, function()
    if head > tail then return end
    local currentCall = queue[head]
    queue[head] = nil
    head = head + 1
    if head > tail then head, tail = 1, 0 end
    if currentCall then
        pending[currentCall] = nil
        addEventLocal(currentCall, true)
    end
end)
