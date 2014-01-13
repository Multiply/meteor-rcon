Package.describe({
	summary: 'node-rcon for Meteor'
});

Package.on_use(function (api) {
	api.use('coffeescript', 'server');

	api.add_files('rcon.coffee', 'server');
	
	api.export('Rcon', 'server');
});

Npm.depends({
	'rcon' : '0.2.1'
});
