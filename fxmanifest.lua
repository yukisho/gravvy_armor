fx_version 'cerulean'
game 'gta5'
name 'gravvy_armor'
description 'Armor carriers & plates'
author 'Gravvy'
version '1.0.0'
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