fx_version 'cerulean'
game 'gta5'

author 'Petris <github.com/PetrisGR>'
description 'Capture The Area'
version '1.0.0'

lua54 'yes'

server_scripts {
    'config.lua',
    'server/main.lua',
}

client_scripts {
    '@PolyZone/client.lua',
    '@clm_ProgressBar/main.lua',
    '@clm_ProgressBar/class.lua',
    'client/main.lua',
}

dependencies {
    'PolyZone',
    'clm_ProgressBar',
}
