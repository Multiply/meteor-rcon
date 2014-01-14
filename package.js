Package.describe({
	summary: 'RCON for Meteor'
});

Package.on_use(function (api) {
	api.use('coffeescript', 'server');

	api.add_files('rcon.coffee', 'server');
	
	api.export('RCON', 'server');
});
