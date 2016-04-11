import vibe.d;
import mysql;
import std.stdio;
import resourcemanager;
import nwn2.tlk;
import api;
import config;

int main(string[] args){
	import std.getopt : getopt, defaultGetoptPrinter;
	import std.file : readText;
	import std.path : buildNormalizedPath;

	string cfgFile = "config.json";
	auto res = getopt(args,
		"config", "Configuration file to use", &cfgFile
		);

	if(res.helpWanted){
	    defaultGetoptPrinter("Some information about the program.",
	        res.options);
	    return 0;
	}


	auto cfg = new Config(readText(cfgFile));
	ResourceManager.store("cfg", cfg);

	//Register 2da paths
	foreach(path ; cfg.paths.twoda)
		ResourceManager.path.add(path.to!string);

	auto strresolv = new StrRefResolver(
		new Tlk(cfg.paths.tlk.to!string),
		cfg.paths.tlk_custom!=""? new Tlk(cfg.paths.tlk_custom.to!string) : null);
	ResourceManager.store("resolver", strresolv);

	if(cfg.database == "mysql"){
		try{
			auto client = new MySQLClient(
				cfg.mysql.host.to!string,
				cfg.mysql.port.to!ushort,
				cfg.mysql.user.to!string,
				cfg.mysql.password.to!string,
				cfg.mysql.database.to!string,
				);
			ResourceManager.store("sql", client);
		}
		catch(Exception e){
			throw new Exception("Could not connect to MySQL", e);
		}
	}
	else{
		assert(0, "Unsupported database type: '"~cfg.database.to!string~"'");
	}


	auto settings = new HTTPServerSettings;
	settings.bindAddresses = cfg.server.addresses[].map!(j => j.to!string).array;
	settings.hostName = cfg.server.hostname.to!string;
	settings.port = cfg.server.port.to!ushort;
	switch(cfg.server.session_store.to!string){
		case "redis":
			settings.sessionStore = new RedisSessionStore(
				cfg.server.redis.host.to!string,
				cfg.server.redis.database.to!long,
				cfg.server.redis.port.to!ushort,
				);

			auto sessionTest = settings.sessionStore.create();
			settings.sessionStore.destroy(sessionTest.id);
			break;
		case "memory":
			settings.sessionStore = new MemorySessionStore;
			break;
		default:
			assert(0, "Unsupported session store: '"~cfg.server.session_store.to!string~"'");
	}

	immutable publicPath = cfg.server.public_path.to!string;
	immutable indexPath = buildNormalizedPath(publicPath, "index.html");

	auto router = new URLRouter;
	router.registerWebInterface(new Api);
	router.get("*", (HTTPServerRequest req, HTTPServerResponse res){
			import std.path : baseName, extension;
			auto ext = req.path[$-1]!='/'? req.path.baseName.extension : null;
			if(ext is null)
				return serveStaticFile(indexPath)(req, res);
			return serveStaticFiles(publicPath)(req, res);
		});

	listenHTTP(settings, router);
	runEventLoop();

	return 0;
}