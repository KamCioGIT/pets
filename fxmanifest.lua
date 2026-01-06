fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

author 'devchacha'
description 'Pet System by devchacha'
version '2.0.0'

-- NUI
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/img/*.png'
}

-- Shared scripts (loaded first)
shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

-- Client scripts
client_scripts {
    'client/func.lua',
    'client/dog.lua',
    'client/client.lua'
}

-- Server scripts
server_scripts {
    'server/server.lua'
}

lua54 'yes'
