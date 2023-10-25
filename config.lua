Config = {
    ["Debug"] = true,
    Framework = exports['es_extended']:getSharedObject(), -- Your framework table "GET" export. (ESX Example)

    Settings = {
        ['RestartAfterPause'] = false, -- USAGE: True to restart timer after pause, false to resume the timer.
        ['GroupCapturing'] = true, -- USAGE: True to avoid pausing the capture while players are friends, otherwise false to make capturing solo.
        ['RewardAll'] = false, -- USAGE: False to reward all capturers of the group which captured the zone or true for only 1 of the group which captured.
    },

    Schedule = {
        ['Monday'] = {
            {zone = "House", hour = 14, minute = 0}, -- 14:00 - 2:00PM
            {zone = "random", hour = 18, minute = 30}, -- 18:30 - 6:30PM
        },
        ['Tuesday'] = {
            {zone = "House", hour = 14, minute = 0}, -- 14:00 - 2:00PM
            {zone = "random", hour = 18, minute = 30}, -- 18:30 - 6:30PM
        },
        ['Wednesday'] = {
            {zone = "House", hour = 14, minute = 0}, -- 14:00 - 2:00PM
            {zone = "random", hour = 18, minute = 30}, -- 18:30 - 6:30PM
        },
        ['Thursday'] = {
            {zone = "House", hour = 14, minute = 0}, -- 14:00 - 2:00PM
            {zone = "random", hour = 18, minute = 30}, -- 18:30 - 6:30PM
        },
        ['Friday'] = {
            {zone = "House", hour = 14, minute = 0}, -- 14:00 - 2:00PM
            {zone = "random", hour = 18, minute = 30}, -- 18:30 - 6:30PM
        },
        ['Saturday'] = {
            {zone = "House", hour = 14, minute = 0}, -- 14:00 - 2:00PM
            {zone = "random", hour = 18, minute = 30}, -- 18:30 - 6:30PM
        },
        ['Sunday'] = {
            {zone = "House", hour = 14, minute = 0}, -- 14:00 - 2:00PM
            {zone = "random", hour = 18, minute = 30}, -- 18:30 - 6:30PM
        }
    },

    Zones = {
        ["House"] = {
            ["Area"] = { -- INFO: /pzcreate: to start a polyzone creation, /pzadd to add a point in the polyzone, /pzfinish to finish the creation of the polyzone.
                vector2(3275.9729003906, 5182.8525390625),
                vector2(3286.1896972656, 5196.1513671875),
                vector2(3288.8740234375, 5197.8774414063),
                vector2(3307.4431152344, 5200.8916015625),
                vector2(3333.015625, 5181.2436523438),
                vector2(3315.8989257813, 5158.84765625),
                vector2(3312.8894042969, 5160.7846679688),
                vector2(3309.7436523438, 5156.7666015625)
            },

            ["Blip"] = {
                Coords = vector3(3305.22,5178.94,17.16)
            },

            ["Settings"] = {
                visible = true,
                minZ = 17.0, 
                maxZ = 37.0,
            },

            ["Duration"] = 2, -- INFO: Duration in minutes.
            
            ["Bucket"] = 1, -- INFO: Use 0 if you don't want an exclusive area bucket.

            ["ViewDistance"] = 100.0, -- INFO: View distance to see the zone if setted to be visible.

            ["Rewards"] = { -- INFO: You can add any types, names and amount of rewards as the reward function is open source and you can handle freely the function.
                {type = "item", name = "bread", amount = 5},
                {type = "weapon", name = "WEAPON_PISTOL", amount = 50},
                {type = "money", name = "black_money", amount = 1000}
            }
        }
    },

    Translation = {
        ["entry_notification"] = "You entered the area.",
        ["exit_notification"] = "You exited the area.",
        ["started_capturing_solo"] = "You started capturing the area.",
        ["started_capturing_group"] = "You started capturing the area with your group.",
        ["paused_notification"] = "The capture has been paused.",
        ["announce_started"] = "Capture The Area has been started.",
        ["announce_finished"] = " captured the area"
    },

    Functions = {
        TriggerCronTask = function(h, m) -- INFO: ESX Cron is used here. Change it if you're using something else.
            TriggerEvent('cron:runAt', h, m, StartCaptureTheArea)
        end,

        RewardPlayer = function(playerId, reward) -- INFO: In this function, you can handle any type of rewards the capturer will receive.
            -- ESX EXAMPLE
            if reward.type == 'item' then
                local xPlayer = Config.Framework.GetPlayerFromId(playerId)
                xPlayer.addInventoryItem(reward.name, reward.amount)
            end
        end,

        GetPlayerGroup = function(playerId) -- INFO: This is used to avoid capturing being paused by friends 
            -- ESX EXAMPLE
            local xPlayer = Config.Framework.GetPlayerFromId(playerId)
            return xPlayer.job.name
        end,

        SendNotificationToPlayer = function(playerId, text)
            -- ESX EXAMPLE
            TriggerClientEvent('esx:showNotification', playerId, text)
        end,

        Announcement = function(text)
            -- ESX EXAMPLE (Notification)
            -- RECOMMENDATION: It would be better if you replace the notification with a chat message instead.
            TriggerClientEvent('esx:showNotification', -1, text)
        end,

        IsStaff = function(playerId)
            -- ESX EXAMPLE
            local xPlayer = Config.Framework.GetPlayerFromId(playerId)
            if xPlayer.getGroup() ~= 'user' then
                return true
            end
            return false
        end,

        IsAllowedToStart = function(playerId)
            -- ESX EXAMPLE
            local xPlayer = Config.Framework.GetPlayerFromId(playerId)
            if xPlayer.getGroup() == 'superadmin' then
                return true
            end
            return false
        end
    }
}

-- INFO: Death event. Please set the right death event which will let the script handle the dead players.

RegisterServerEvent('esx:onPlayerDeath')
AddEventHandler('esx:onPlayerDeath', function(data)
    data.victim = source
    CapturePlayerDied(data.victim) -- WARNING: Do Not Touch, it is script's function.
end)