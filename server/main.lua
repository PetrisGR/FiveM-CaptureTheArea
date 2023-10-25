local ScriptData = {
    Active = false,
    CurrentArea = nil,
    State = "empty",
    PlayersInZone = {},
    StaffInZone = {},
    CurrentTime = {
        Holders = {},
        Group = nil,
        Minutes = 0,
        Seconds = 0,
    },
}

local function DebugPrint(text)
	if Config["Debug"] then
		print("^0[^2Capture The Area^0]: "..text)
	end
end

local function GetScheduledArea(d, h, m)
    local scheduled = false

    if not d then return scheduled end

    for k,v in pairs(Config.Schedule) do
        local days = { [1] = 'Sunday', [2] = 'Monday', [3] = 'Tuesday', [4] = 'Wednesday', [5] = 'Thursday', [6] = 'Friday', [7] = 'Saturday' }
        
        if k == days[d] then
            for _, times in pairs(v) do
                if times.hour == h and times.minute == m then
                    scheduled = times.zone
                    break
                end
            end
        end
    end

    return scheduled
end

local function FinishCapture(capturers)
    local area = ScriptData.CurrentArea

    ScriptData.Active = false
    ScriptData.CurrentArea = nil
    ScriptData.State = "empty"
    ScriptData.PlayersInZone = {}

    TriggerClientEvent('CaptureTheArea:Client:Stopped', -1)

    for k,v in pairs(ScriptData.StaffInZone) do
        SetPlayerRoutingBucket(k, 0)
        ScriptData.StaffInZone[k] = nil
    end

    for k,v in pairs(capturers) do
        SetPlayerRoutingBucket(k, 0)
    end

    if Config.Settings['RewardAll'] and Config.Settings['GroupCapturing'] then
        for k,v in pairs(capturers) do
            for _, reward in pairs(Config.Zones[area]["Rewards"]) do
                Config.Functions.RewardPlayer(k, reward)
            end
        end
    else
        for k,v in pairs(capturers) do
            for _, reward in pairs(Config.Zones[area]["Rewards"]) do
                Config.Functions.RewardPlayer(k, reward)
            end
            break
        end
    end

    for k,v in pairs(capturers) do
        if Config.Settings['GroupCapturing'] then
            Config.Functions.Announcement(""..v.." "..Config.Translation["announce_finished"].."")
        else
            Config.Functions.Announcement(""..GetPlayerName(v).." "..Config.Translation["announce_finished"].."")
        end
        break
    end
end

local function KillClientTimer(id)
    TriggerClientEvent('CaptureTheArea:Client:KillTimer', id)

    if ScriptData.CurrentTime.Holders[id] then
        ScriptData.CurrentTime.Holders[id] = nil
    end
end

local function SendClientTimer(id)
    TriggerClientEvent('CaptureTheArea:Client:SendTimer', id, ScriptData.CurrentTime.Minutes, ScriptData.CurrentTime.Seconds)

    ScriptData.CurrentTime.Holders[id] = true
end

local function KillServerTimer()
    for k,v in pairs(ScriptData.CurrentTime.Holders) do
        KillClientTimer(k)
    end
    
    ScriptData.CurrentTime.Group = nil
    ScriptData.CurrentTime.Minutes = 0
    ScriptData.CurrentTime.Seconds = -1
end

local function StartTimer(group)
    local zoneDuration = Config.Zones[ScriptData.CurrentArea]["Duration"]

    Citizen.CreateThread(function()
        if ScriptData.CurrentTime.Group then
            if Config.Settings['RestartAfterPause'] then
                ScriptData.CurrentTime.Seconds = 0
                ScriptData.CurrentTime.Minutes = zoneDuration
            elseif not Config.Settings['RestartAfterPause'] and group ~= ScriptData.CurrentTime.Group then
                ScriptData.CurrentTime.Seconds = 0
                ScriptData.CurrentTime.Minutes = zoneDuration
            end 
        else
            ScriptData.CurrentTime.Seconds = 0
            ScriptData.CurrentTime.Minutes = zoneDuration
        end

        ScriptData.CurrentTime.Group = group

        if ScriptData.State == "capturing" then
            for k,v in pairs(ScriptData.PlayersInZone) do
                if not ScriptData.CurrentTime.Holders[k] then
                    SendClientTimer(k)
                end
            end
        end
    end)
end

Citizen.CreateThread(function()
    while true do
        Wait(1000)
        if ScriptData.State == "capturing" then
            if ScriptData.CurrentTime.Minutes == 0 and ScriptData.CurrentTime.Seconds == 0 then
                ScriptData.CurrentTime.Seconds = -1
                KillServerTimer()
                FinishCapture(ScriptData.PlayersInZone)
                break
            else
                if ScriptData.CurrentTime.Seconds == 0 then
                    if ScriptData.CurrentTime.Minutes == 0 then
                        ScriptData.CurrentTime.Minutes = 0
                    else
                        ScriptData.CurrentTime.Minutes = ScriptData.CurrentTime.Minutes - 1
                    end

                    ScriptData.CurrentTime.Seconds = 60
                end
                if ScriptData.CurrentTime.Seconds > 0 then
                    ScriptData.CurrentTime.Seconds = ScriptData.CurrentTime.Seconds - 1
                end
            end
        end
    end
end)

local function UpdateCaptureState()
    local state = "empty"
    local groupsFound = 0
    local latestGroup = ""

    for k,v in pairs(ScriptData.PlayersInZone) do
        if groupsFound == 0 then
            latestGroup = v
            groupsFound = 1
        else
            if v ~= latestGroup then
                groupsFound = 2
                state = "paused"
            end
        end
    end

    if groupsFound == 1 then state = "capturing" StartTimer(latestGroup) end

    if ScriptData.State ~= state then
        if state == "empty" or state == "paused" and ScriptData.State == "capturing" then
            for k,v in pairs(ScriptData.CurrentTime.Holders) do
                KillClientTimer(k)
            end
        end

        ScriptData.State = state

        TriggerClientEvent('CaptureTheArea:Client:StateChanged', -1, ScriptData.State)

        if ScriptData.State == "paused" then
            for k,v in pairs(ScriptData.PlayersInZone) do
                Config.Functions.SendNotificationToPlayer(k, Config.Translation["paused_notification"])
            end
        end
    end
    return state
end

function CapturePlayerDied(playerId)
    if ScriptData.Active then
        if ScriptData.PlayersInZone[playerId] then
            if ScriptData.CurrentTime.Holders[playerId] then KillClientTimer(playerId) end

            ScriptData.PlayersInZone[playerId] = nil
            SetPlayerRoutingBucket(playerId, 0)
            UpdateCaptureState()

            TriggerClientEvent('CaptureTheArea:Client:ChangePlayerState', playerId, false)
        end

        if ScriptData.StaffInZone[playerId] then 
            ScriptData.StaffInZone[playerId] = nil 
        end
    end
end

function StartCaptureTheArea(d, h, m)
    if ScriptData.Active then return end

    local scheduledArea = GetScheduledArea(d, h, m)

    if scheduledArea then
        ScriptData.Active = true

        if string.lower(scheduledArea) == "random" then 
            local areas = {}

            for k,v in pairs(Config.Zones) do
                table.insert(areas, k)
            end

            local randomArea = tonumber(math.random(1, #areas))
            ScriptData.CurrentArea = tostring(areas[randomArea])
        else
            ScriptData.CurrentArea = scheduledArea
        end

        TriggerClientEvent('CaptureTheArea:Client:Started', -1, {name = ScriptData.CurrentArea, area = Config.Zones[ScriptData.CurrentArea]["Area"], settings = Config.Zones[ScriptData.CurrentArea]["Settings"], blip = Config.Zones[ScriptData.CurrentArea]["Blip"], distance = Config.Zones[ScriptData.CurrentArea]["ViewDistance"]})
        DebugPrint("Event Started!")
        Config.Functions.Announcement(Config.Translation["announce_started"])
    else
        DebugPrint("Scheduled area could not be found. Please check your configuration.")
    end
end

function StartNonScheduledEvent(area)
    if ScriptData.Active then DebugPrint("A capture the area event is already active.") return end

    local scheduledArea = "random"

    if Config.Zones[area] then scheduledArea = area end

    ScriptData.Active = true

    if string.lower(scheduledArea) == "random" then 
        local areas = {}

        for k,v in pairs(Config.Zones) do
            table.insert(areas, k)
        end

        local randomArea = tonumber(math.random(1, #areas))
        ScriptData.CurrentArea = tostring(areas[randomArea])
    else
        ScriptData.CurrentArea = scheduledArea
    end

    TriggerClientEvent('CaptureTheArea:Client:Started', -1, {name = ScriptData.CurrentArea, area = Config.Zones[ScriptData.CurrentArea]["Area"], settings = Config.Zones[ScriptData.CurrentArea]["Settings"], blip = Config.Zones[ScriptData.CurrentArea]["Blip"], distance = Config.Zones[ScriptData.CurrentArea]["ViewDistance"]})
    DebugPrint("Event Started!")
    Config.Functions.Announcement(Config.Translation["announce_started"])
end

RegisterCommand('startcapturethearea', function(source, args)
    local playerId = source
    local area = args[1]

    if playerId > 0 and not Config.Functions.IsAllowedToStart(playerId) then return end
    
    StartNonScheduledEvent(area)
end)

exports("StartEvent", function(area)
    StartNonScheduledEvent(area)
end)

RegisterServerEvent('CaptureTheArea:Server:TriggeredZone')
AddEventHandler('CaptureTheArea:Server:TriggeredZone', function(inZone)
    local src = source

    TriggerClientEvent('CaptureTheArea:Client:ChangePlayerState', src, inZone)

    if inZone then
        local vehicle = GetVehiclePedIsIn(GetPlayerPed(src), false)

        if vehicle then DeleteEntity(vehicle, 0) end

        SetPlayerRoutingBucket(src, Config.Zones[ScriptData.CurrentArea]["Bucket"])
        Config.Functions.SendNotificationToPlayer(src, Config.Translation["entry_notification"])
        
        if not Config.Functions.IsStaff(src) then
            if Config.Settings['GroupCapturing'] then
                ScriptData.PlayersInZone[src] = Config.Functions.GetPlayerGroup(src)
            else
                ScriptData.PlayersInZone[src] = src
            end

            UpdateCaptureState()

            if ScriptData.State == "capturing" and ScriptData.PlayersInZone[src] then
                if Config.Settings['GroupCapturing'] then
                    if #ScriptData.PlayersInZone > 1 then 
                        Config.Functions.SendNotificationToPlayer(src, Config.Translation["started_capturing_group"])
                        if not ScriptData.CurrentTime.Holders[src] then SendClientTimer(src) end
                    else
                        Config.Functions.SendNotificationToPlayer(src, Config.Translation["started_capturing_solo"])
                    end
                else
                    Config.Functions.SendNotificationToPlayer(src, Config.Translation["started_capturing_solo"])
                end
            end
        else
            ScriptData.StaffInZone[src] = true
        end
    else
        if not Config.Functions.IsStaff(src) then
            if ScriptData.CurrentTime.Holders[src] then KillClientTimer(src) end
            ScriptData.PlayersInZone[src] = nil
            UpdateCaptureState()
        else
            ScriptData.StaffInZone[src] = nil
        end

        SetPlayerRoutingBucket(src, 0)
        Config.Functions.SendNotificationToPlayer(src, Config.Translation["exit_notification"])
    end
end)

RegisterServerEvent('CaptureTheArea:Server:RequestState')
AddEventHandler('CaptureTheArea:Server:RequestState', function()
    if ScriptData.Active then
        TriggerClientEvent('CaptureTheArea:Client:ReceiveNewPlayerState', source, {name = ScriptData.CurrentArea, area = Config.Zones[ScriptData.CurrentArea]["Area"], settings = Config.Zones[ScriptData.CurrentArea]["Settings"], blip = Config.Zones[ScriptData.CurrentArea]["Blip"], distance = Config.Zones[ScriptData.CurrentArea]["ViewDistance"]}, ScriptData.State)
    end
end)

AddEventHandler('playerDropped', function(reason)
    local src = source

    if ScriptData.PlayersInZone[src] then ScriptData.PlayersInZone[src] = nil end

    if ScriptData.StaffInZone[src] then ScriptData.StaffInZone[src] = nil end

    if ScriptData.CurrentTime.Holders[src] then ScriptData.CurrentTime.Holders[src] = nil end

    UpdateCaptureState()
end)

for _, scheduleTimes in pairs(Config.Schedule) do
    for __, scheduledTime in pairs(scheduleTimes) do
        Config.Functions.TriggerCronTask(scheduledTime.hour, scheduledTime.minute)
    end
end
