fx_version 'cerulean'
game 'gta5'

author 'UX Development'
description 'UX Scripts | Starterpack'
version '1.0.4'

shared_scripts {
	'@ox_lib/init.lua',
	'config.lua'
}

client_scripts {
	'core.lua',
	'auth.lua',
	'client/*.lua'
}

server_scripts {
	'@mysql-async/lib/MySQL.lua',
	'core.lua',
	'server/*.lua'
}

escrow_ignore {
	'config.lua',
	'auth.lua',
	'server/discordlog.lua'
}

dependencies {
	'ox_lib',
}

lua54 'yes'