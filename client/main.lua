local API_ProgressBar = exports["clm_ProgressBar"]:GetAPI()
local ClientData = {
    Active = false,
    CurrentZone = nil,
    State = "empty",
    InsideZone = false,
    CurrentTimer = nil,
    Blips = {Main = nil, Background = nil},
    Time = {seconds = 0, minutes = 0}
}

CreateThread(function()
	while true do
		Wait(100)
		if NetworkIsPlayerActive(PlayerId()) then
			TriggerServerEvent('CaptureTheArea:Server:RequestState')
			break
		end
	end
end)

local function RemoveAreaBlips()
    if ClientData.Blips.Background then
        RemoveBlip(ClientData.Blips.Background)
        ClientData.Blips.Background = nil
    end

    if ClientData.Blips.Main then
        RemoveBlip(ClientData.Blips.Main)
        ClientData.Blips.Main = nil
    end
end

local function ChangeBlipState()
    local state = ClientData.State

    if state == "empty" then
        SetBlipFlashes(ClientData.Blips.Background, false)
        SetBlipColour(ClientData.Blips.Background, 0)
    elseif state == "paused" then
        SetBlipFlashes(ClientData.Blips.Background, true)
        SetBlipFlashInterval(ClientData.Blips.Background, 1500)
        SetBlipColour(ClientData.Blips.Background, 40)
    elseif state == "capturing" then
        SetBlipFlashes(ClientData.Blips.Background, false)
        SetBlipColour(ClientData.Blips.Background, 1)
    end
end

local function CreateAreaBlips(settings)
    ClientData.Blips.Main = AddBlipForCoord(vector3(settings.Coords.x, settings.Coords.y, settings.Coords.z))
    ClientData.Blips.Background = AddBlipForRadius(vector3(settings.Coords.x, settings.Coords.y, settings.Coords.z), 100.0)
    
    SetBlipSprite(ClientData.Blips.Main, 358)
    SetBlipDisplay(ClientData.Blips.Main, 4)
    SetBlipAsShortRange(ClientData.Blips.Main, true)
    SetBlipScale(ClientData.Blips.Main, 1.1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Capture The Area')
    EndTextCommandSetBlipName(ClientData.Blips.Main)

    SetBlipHighDetail(ClientData.Blips.Background, true)
    SetBlipColour(ClientData.Blips.Background, 0)
    SetBlipAlpha(ClientData.Blips.Background, 150)
    SetBlipRotation(ClientData.Blips.Background, settings.Rotation)
    SetBlipDisplay(ClientData.Blips.Background, 3)
    BeginTextCommandSetBlipName("STRING")
    EndTextCommandSetBlipName(ClientData.Blips.Background)
end

local function ChangePolyState()
    local state = ClientData.State

    if state == "empty" then
        ClientData.CurrentZone.debugColors = {
            walls = {0, 255, 0},
            outline = {0, 0, 0},
            grid = {0, 255, 0}
        },
        PolyZone.ensureMetatable(ClientData.CurrentZone)
    elseif state == "paused" then
        ClientData.CurrentZone.debugColors = {
            walls = {255, 150, 0},
            outline = {0, 0, 0},
            grid = {255, 150, 0}
        },
        PolyZone.ensureMetatable(ClientData.CurrentZone)
    elseif state == "capturing" then
        ClientData.CurrentZone.debugColors = {
            walls = {255, 0, 0},
            outline = {0, 0, 0},
            grid = {255, 0, 0}
        },
        PolyZone.ensureMetatable(ClientData.CurrentZone)
    end
end

local function KillMyTimer()
    if ClientData.CurrentTimer then
        API_ProgressBar.remove(ClientData.CurrentTimer._id)
        ClientData.CurrentTimer = nil
    end

    ClientData.Time.minutes = 0
    ClientData.Time.seconds = 0
end

local function StartMyTimer()
    Citizen.CreateThread(function()
        while ClientData.Time.seconds >= 0 do
            Wait(1000)
            
            if ClientData.Time.minutes == 0 and ClientData.Time.seconds == 0 then
                ClientData.Time.seconds = -1
                KillMyTimer()
                break
            else
                if ClientData.Time.seconds == 0 then
                    if ClientData.Time.minutes == 0 then
                        ClientData.Time.minutes = 0
                    else
                        ClientData.Time.minutes = ClientData.Time.minutes - 1
                    end

                    ClientData.Time.seconds = 60
                end

                if ClientData.Time.seconds > 0 then
                    ClientData.Time.seconds = ClientData.Time.seconds - 1
                end

                if ClientData.Time.minutes == 0 then
                    ClientData.CurrentTimer.Func.lib.TextTimerBar.setTextColor({200, 0, 0, 255})
                    PlaySoundFrontend(-1, "HORDE_COOL_DOWN_TIMER", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                end

                ClientData.CurrentTimer.Func.lib.TextTimerBar.setText(string.format("%02d:%02d",ClientData.Time.minutes,ClientData.Time.seconds))
            end
        end 
    end)
end

RegisterNetEvent('CaptureTheArea:Client:KillTimer')
AddEventHandler('CaptureTheArea:Client:KillTimer', function()
    KillMyTimer()
end)

RegisterNetEvent('CaptureTheArea:Client:SendTimer')
AddEventHandler('CaptureTheArea:Client:SendTimer', function(mins, secs)
    ClientData.Time.minutes = mins
    ClientData.Time.seconds = secs
    ClientData.CurrentTimer = API_ProgressBar.add("TextTimerBar", "TIME REMAINING", string.format("%02d:%02d",ClientData.Time.minutes,ClientData.Time.seconds))

    StartMyTimer()
end)

RegisterNetEvent('CaptureTheArea:Client:StateChanged')
AddEventHandler('CaptureTheArea:Client:StateChanged', function(state)
    ClientData.State = state
    ChangeBlipState()
    ChangePolyState()
end)

RegisterNetEvent('CaptureTheArea:Client:ReceiveNewPlayerState')
AddEventHandler('CaptureTheArea:Client:ReceiveNewPlayerState', function(zone, state)
    ClientData.Active = true
    
    ClientData.CurrentZone = PolyZone:Create(zone.area, {
        name = zone.name,
        minZ = zone.settings.minZ,
        maxZ = zone.settings.maxZ,
        debugPoly = zone.settings.visible,
        debugColors = {
            walls = {0, 255, 0},
            outline = {0, 0, 0},
            grid = {0, 255, 0}
        },
    })

    ClientData.CurrentZone:onPointInOut(PolyZone.getPlayerPosition, function(isPointInside, point)
        if ClientData.Active then
            if ClientData.InsideZone ~= isPointInside then
                ClientData.InsideZone = isPointInside
                TriggerServerEvent('CaptureTheArea:Server:TriggeredZone', isPointInside)
            end
        end
    end, 1000)
    
    CreateAreaBlips(zone.blip)
    ClientData.State = state
    ChangeBlipState()
    ChangePolyState()

    if zone.settings.visible then

        while ClientData.Active do
            Citizen.Wait(3000)
            local currDistance = #(GetEntityCoords(PlayerPedId()) - vector3(zone.area[1].x, zone.area[1].y, zone.settings.minZ))
            if currDistance > zone.distance then
                ClientData.CurrentZone.name = zone.name
                ClientData.CurrentZone.minZ = zone.settings.minZ
                ClientData.CurrentZone.maxZ = zone.settings.maxZ
                ClientData.CurrentZone.debugPoly = false

                PolyZone.ensureMetatable(ClientData.CurrentZone)
            else
                ClientData.CurrentZone.debugPoly = true
                ChangePolyState()
            end
        end

    end
end)

RegisterNetEvent('CaptureTheArea:Client:Started')
AddEventHandler('CaptureTheArea:Client:Started', function(zone)
    ClientData.Active = true

    ClientData.CurrentZone = PolyZone:Create(zone.area, {
        name = zone.name,
        minZ = zone.settings.minZ,
        maxZ = zone.settings.maxZ,
        debugPoly = zone.settings.visible,
        debugColors = {
            walls = {0, 255, 0},
            outline = {0, 0, 0},
            grid = {0, 255, 0}
        },
    })

    ClientData.CurrentZone:onPointInOut(PolyZone.getPlayerPosition, function(isPointInside, point)
        if ClientData.Active then
            if ClientData.InsideZone ~= isPointInside then
                ClientData.InsideZone = isPointInside
                TriggerServerEvent('CaptureTheArea:Server:TriggeredZone', isPointInside)
            end
        end
    end, 1000)

    CreateAreaBlips(zone.blip)

    if zone.settings.visible then

        while ClientData.Active do
            Citizen.Wait(3000)
            local currDistance = #(GetEntityCoords(PlayerPedId()) - vector3(zone.area[1].x, zone.area[1].y, zone.settings.minZ))

            if currDistance > zone.distance then
                ClientData.CurrentZone.name = zone.name
                ClientData.CurrentZone.minZ = zone.settings.minZ
                ClientData.CurrentZone.maxZ = zone.settings.maxZ
                ClientData.CurrentZone.debugPoly = false
                ClientData.CurrentZone.debugColors = {}
                
                PolyZone.ensureMetatable(ClientData.CurrentZone)
            else
                ClientData.CurrentZone.debugPoly = true
                ChangePolyState()
            end
        end

    end
end)

RegisterNetEvent('CaptureTheArea:Client:Stopped')
AddEventHandler('CaptureTheArea:Client:Stopped', function()
    ClientData.Active = false
    ClientData.State = "empty"

    RemoveAreaBlips()

    ClientData.CurrentZone:destroy()
    ClientData.CurrentZone = nil
    ClientData.InsideZone = false
end)

RegisterNetEvent('CaptureTheArea:Client:ChangePlayerState')
AddEventHandler('CaptureTheArea:Client:ChangePlayerState', function(bool)
    ClientData.InsideZone = bool
end)

exports('IsPlayerInZone', function()
    return ClientData.InsideZone
end)

exports('IsPlayerCapturing', function()
    if ClientData.State == "capturing" then
        return true
    end

    return false
end)
