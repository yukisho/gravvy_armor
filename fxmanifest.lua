fx_version 'cerulean'
game 'gta5'

name 'gravvy_kevlar'
description 'Kevlar carriers & plates (simplified: no inventories, plates are useable)'
author 'Gravvy'
version '2.0.0'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/server.lua'
}

dependency 'qb-inventory'

escrow_ignore {
    'config.lua'
}
