fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Dip for Beacon RP'
description 'sCoin Balance App for LB Phone'
version '1.0.0'

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js'
}
