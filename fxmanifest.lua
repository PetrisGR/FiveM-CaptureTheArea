fx_version 'cerulean'
game 'gta5'

author 'Petris <github.com/PetrisGR>'
description 'Capture The Area'
version '1.0.1'

lua54 'yes'

server_scripts {
    'config.lua',
    'server/main.lua',
}

client_scripts {
    '@PolyZone/client.lua',
    '@clm_ProgressBar/client/main.lua',
    '@clm_ProgressBar/client/classes/TimerBarBase.lua',
    'client/main.lua',
}

dependencies {
    'PolyZone',
    'clm_ProgressBar',
}
