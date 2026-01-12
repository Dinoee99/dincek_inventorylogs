local function getWebhook(key)
    return GetConvar(('invlogs:webhook_%s'):format(key), '')
end

local function safeWebhook(key)
    local wh = getWebhook(key)
    if wh == nil or wh == '' then return nil end
    return wh
end

local function getIdentifiers(src)
    local license, steam, discord = 'N/A', 'N/A', 'N/A'

    if GetPlayerIdentifierByType then
        license = GetPlayerIdentifierByType(src, 'license') or license
        steam   = GetPlayerIdentifierByType(src, 'steam') or steam
        discord = GetPlayerIdentifierByType(src, 'discord') or discord
    else
        for _, id in ipairs(GetPlayerIdentifiers(src)) do
            if id:sub(1, 8) == 'license:' then license = id end
            if id:sub(1, 6) == 'steam:' then steam = id end
            if id:sub(1, 8) == 'discord:' then discord = id end
        end
    end

    if discord ~= 'N/A' then
        discord = discord:gsub('discord:', '')
    end

    return {
        id = src,
        name = GetPlayerName(src) or ('ID %s'):format(src),
        license = license,
        steam = steam,
        discord = discord
    }
end

local function who(src)
    local p = getIdentifiers(src)

    local discordLine = '**Discord:** N/A'
    if p.discord ~= 'N/A' then
        discordLine = ('**Discord:** <@%s> (`%s`)'):format(p.discord, p.discord)
    end

    return table.concat({
        ('**Player:** %s'):format(p.name),
        ('\n**ID:** %s'):format(p.id),
        ('\n**License:** %s'):format(p.license),
        ('\n**Steam:** %s'):format(p.steam),
        ('\n%s'):format(discordLine)
    }, '')
end

local LogQueues    = {}

-- Tunables via convars
local MAX_PER_TICK = tonumber(GetConvar('invlogs:max_per_tick', '8')) or 8    -- total sends per tick
local TICK_MS      = tonumber(GetConvar('invlogs:tick_ms', '1000')) or 1000   -- ms between flushes
local MAX_QUEUE    = tonumber(GetConvar('invlogs:max_queue', '5000')) or 5000 -- safety cap per webhook

local function sendDiscord(webhook, title, description, color)
    if not webhook or webhook == '' then return end

    LogQueues[webhook] = LogQueues[webhook] or {}

    if #LogQueues[webhook] >= MAX_QUEUE then
        table.remove(LogQueues[webhook], 1)
    end

    LogQueues[webhook][#LogQueues[webhook] + 1] = {
        title = title,
        description = description,
        color = color or 16777215
    }
end


CreateThread(function()
    while true do
        Wait(TICK_MS)

        local sent = 0

        for webhook, queue in pairs(LogQueues) do
            if sent >= MAX_PER_TICK then break end
            if queue and #queue > 0 then
                local entry = table.remove(queue, 1)

                local payload = {
                    username = 'Inventory Logs',
                    embeds = { {
                        title = entry.title,
                        description = entry.description,
                        color = entry.color,
                        footer = { text = 'TRAKTEN INV LOGS' },
                        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
                    } }
                }

                PerformHttpRequest(webhook, function() end, 'POST', json.encode(payload), {
                    ['Content-Type'] = 'application/json'
                })

                sent = sent + 1
            end
        end
    end
end)

local function stringifyInventory(inv)
    if type(inv) == 'table' then
        if inv.id then return tostring(inv.id) end
        if inv.type and inv.owner then return ('%s:%s'):format(inv.type, inv.owner) end
        return json.encode(inv)
    end
    return tostring(inv)
end

local function pickWebhookForSwap(fromInv, toInv)
    fromInv = fromInv or ''
    toInv = toInv or ''

    local f = tostring(fromInv)
    local t = tostring(toInv)

    local isStash = (f:find('stash') ~= nil) or (t:find('stash') ~= nil)
    if isStash then return safeWebhook('stash'), 'STASH' end

    local isVehicle =
        (f:find('trunk') ~= nil) or (t:find('trunk') ~= nil) or
        (f:find('glovebox') ~= nil) or (t:find('glovebox') ~= nil)

    if isVehicle then return safeWebhook('vehicle'), 'VEHICLE' end

    return safeWebhook('inventory'), 'INVENTORY'
end

local function formatItem(slot)
    if not slot then return 'unknown', 0 end
    local name = slot.name or 'unknown'
    local count = slot.count or slot.amount or 0
    return name, count
end

local function invToPlayerId(inv)
    if inv == nil then return nil end
    local s = tostring(inv)
    local n = tonumber(s)
    if n and n > 0 and GetPlayerName(n) ~= nil then
        return n
    end
    return nil
end

local function otherPlayerInfoLine(pid, label)
    local p = getIdentifiers(pid)
    local discordLine = 'N/A'
    if p.discord ~= 'N/A' then
        discordLine = ('<@%s> (`%s`)'):format(p.discord, p.discord)
    end

    return table.concat({
        ('\n\n**%s:** %s'):format(label or 'Other Player', p.name),
        ('\n**%s ID:** %s'):format(label or 'Other Player', p.id),
        ('\n**%s License:** %s'):format(label or 'Other Player', p.license),
        ('\n**%s Steam:** %s'):format(label or 'Other Player', p.steam),
        ('\n**%s Discord:** %s'):format(label or 'Other Player', discordLine),
    }, '')
end



exports.ox_inventory:registerHook('swapItems', function(payload)
    local src = payload.source
    if not src or src <= 0 then return end

    local fromInv             = stringifyInventory(payload.fromInventory)
    local toInv               = stringifyInventory(payload.toInventory)

    local itemName, itemCount = formatItem(payload.fromSlot)

    local toSlot              = payload.toSlot
    local toCount             = itemCount
    if type(toSlot) == 'table' then
        toCount = toSlot.count or toSlot.amount or itemCount
    end

    local webhook, scope = pickWebhookForSwap(fromInv, toInv)

    local srcStr         = tostring(src)
    local fromIsPlayer   = (tostring(fromInv) == srcStr)
    local toIsPlayer     = (tostring(toInv) == srcStr)

    local action         = 'TRANSFER'
    local title          = 'Item Flyttat'

    if fromIsPlayer and not toIsPlayer then
        action = 'DEPOSIT (LADE IN)'
        title  = 'Item Inlagd i Inventory'
    elseif toIsPlayer and not fromIsPlayer then
        action = 'WITHDRAW (TOG UT)'
        title  = 'Item Uttagen från Inventory'
    end

    local victimId = nil
    if toIsPlayer then
        local possibleVictim = invToPlayerId(fromInv)
        if possibleVictim and possibleVictim ~= src then
            victimId = possibleVictim
            action   = 'LOOT (TOG FRÅN ANNAN SPELARE)'
            title    = 'Player Loot'
        end
    end

    local msg = table.concat({
        who(src),
        ('\n**Scope:** %s'):format(scope),
        ('\n**Action:** %s'):format(action),
        ('\n**Item:** %s x%s'):format(itemName, tostring(itemCount)),
        ('\n**From:** %s'):format(fromInv),
        ('\n**To:** %s'):format(toInv),
        ('\n**ToSlot:** %s'):format(
            type(toSlot) == 'number' and tostring(toSlot)
            or (type(toSlot) == 'table' and tostring(toSlot.slot or 'table') or 'N/A')
        ),
        ('\n**ToCount (post):** %s'):format(tostring(toCount))
    }, '')

    if victimId then
        msg = msg .. otherPlayerInfoLine(victimId, 'Looted Player')
    end

    sendDiscord(webhook, title, msg, 3145658)
end)
