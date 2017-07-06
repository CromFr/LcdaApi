import vibe.d;
import mysql;
import std.stdio;
import resourcemanager;
import nwn.tlk;
import nwn.dungeons;
import api.api;
import config;

int main(string[] args){
	import std.getopt : getopt, defaultGetoptPrinter;
	import std.file : readText;
	import std.path : buildNormalizedPath;
	import std.algorithm : map;
	import std.array : array;

	string cfgFile = "config.json";
	auto res = getopt(args,
		"config", "Configuration file to use", &cfgFile
		);

	if(res.helpWanted){
	    defaultGetoptPrinter("Some information about the program.",
	        res.options);
	    return 0;
	}

	writeln("Using config ",cfgFile);
	auto cfg = new Config(readText(cfgFile));
	ResourceManager.store("cfg", cfg);

	//Register 2da paths
	foreach(path ; cfg["paths"]["twoda"]){
		writeln("Caching 2DA: ", path.to!string);
		ResourceManager.path.add(path.to!string);
	}

	writeln("Caching TLK");
	auto strresolv = new StrRefResolver(
		new Tlk(cfg["paths"]["tlk"].to!string),
		cfg["paths"]["tlk_custom"]!=""? new Tlk(cfg["paths"]["tlk_custom"].to!string) : null);
	ResourceManager.store("resolver", strresolv);

	writeln("Caching dungeon info");
	initDungeonInfo();

	import core.memory: GC;
	GC.collect();
	GC.minimize();

	size_t cnt = 0;
	while(cnt++<5){
		if(cfg["database"] == "mysql"){
			try{
				auto client = new MySQLClient(
					cfg["mysql"]["host"].to!string,
					cfg["mysql"]["port"].to!ushort,
					cfg["mysql"]["user"].to!string,
					cfg["mysql"]["password"].to!string,
					cfg["mysql"]["database"].to!string,
					);
				ResourceManager.store("sql", client);
				break;
			}
			catch(Exception e){
				stderr.writeln("Could not connect to MySQL", e);
			}
		}
		else{
			assert(0, "Unsupported database type: '"~cfg["database"].to!string~"'");
		}

		import core.thread: Thread, dur;
		Thread.sleep(dur!"seconds"(2));
	}
	enforce(cnt<=5, "Could not connect to SQL database !");



	auto settings = new HTTPServerSettings;
	settings.bindAddresses = cfg["server"]["addresses"][].map!(j => j.to!string).array;
	settings.hostName = cfg["server"]["hostname"].to!string;
	settings.port = cfg["server"]["port"].to!ushort;
	settings.useCompressionIfPossible = cfg["server"]["compression"].to!bool;
	switch(cfg["server"]["session_store"].to!string){
		case "redis":
			cnt = 0;
			while(cnt++<5){
				try{
					settings.sessionStore = new RedisSessionStore(
						cfg["server"]["redis"]["host"].to!string,
						cfg["server"]["redis"]["database"].to!long,
						cfg["server"]["redis"]["port"].to!ushort,
						);

					auto sessionTest = settings.sessionStore.create();
					settings.sessionStore.destroy(sessionTest.id);
					break;
				}
				catch(Exception e){
					stderr.writeln("Could not connect to Redis server", e);
				}
			}
			enforce(cnt<=5, "Could not connect to Redis database !");
			break;
		case "memory":
			settings.sessionStore = new MemorySessionStore;
			break;
		default:
			assert(0, "Unsupported session store: '"~cfg["server"]["session_store"].to!string~"'");
	}

	immutable publicPath = cfg["server"]["public_path"].to!string;
	immutable indexPath = buildNormalizedPath(publicPath, "index.html");

	auto router = new URLRouter;
	router.registerWebInterface(new Api);
	listenHTTP(settings, router);
	runEventLoop();

	return 0;
}