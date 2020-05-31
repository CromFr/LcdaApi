import vibe.d;
import std.stdio;

import resourcemanager: ResourceManager, ResourceException;
import nwn.tlk;
import lcda.dungeons;
import config;
import api.api;
import api.auth;
import cache;

int main(string[] args){
	import std.getopt : getopt, defaultGetoptPrinter;
	import std.file : readText;
	import std.path : buildNormalizedPath;
	import std.algorithm : map;
	import std.array : array;
	import std.traits: EnumMembers;
	import std.conv: to;

	import etc.linux.memoryerror;
	static if (is(typeof(registerMemoryErrorHandler)))
		registerMemoryErrorHandler();

	string cfgFile = "config.json";
	ushort port = 0;
	LogLevel logLevel = LogLevel.info;
	auto res = getopt(args,
		"config", "Configuration file to use", &cfgFile,
		"p|port", "Override port setting in config", &port,
		"loglevel", "Log level. Any of ("~EnumMembers!LogLevel.stringof[6..$-1]~"). Default: info", &logLevel
		);

	if(res.helpWanted){
	    defaultGetoptPrinter("Usage: " ~ args[0] ~ " [args]",
	        res.options);
	    return 0;
	}

	setLogLevel(logLevel);

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

	writeln("Starting thread to reload large files");
	import core.thread: Thread;
	with(new Thread({
		try{
			while(1){
				Cache.reduce();

				Thread.sleep(dur!"seconds"(60));
			}
		}
		catch(Throwable e){
			writeln("Reload thread exited with: ", e);
		}
	})){
		isDaemon = true;
		start();
	}



	import core.memory: GC;
	GC.collect();
	GC.minimize();

	if(cfg["database"] == "mysql"){
		import mysql.pool: MySQLPool;
		auto sqlPool = new MySQLPool(
			cfg["mysql"]["host"].to!string,
			cfg["mysql"]["user"].to!string,
			cfg["mysql"]["password"].to!string,
			cfg["mysql"]["database"].to!string,
			cfg["mysql"]["port"].to!ushort,
			);
		ResourceManager.store("sql", sqlPool);

		//test connection
		try sqlPool.lockConnection();
		catch(Exception e){
			stderr.writeln("Could not connect to MySQL server: ", e.msg);
			return 1;
		}
	}
	else{
		assert(0, "Unsupported database type: '"~cfg["database"].to!string~"'");
	}


	auto settings = new HTTPServerSettings;
	settings.bindAddresses = cfg["server"]["addresses"][].map!(j => j.to!string).array;
	settings.hostName = cfg["server"]["hostname"].to!string;
	settings.port = port != 0 ? port : cfg["server"]["port"].to!ushort;
	settings.useCompressionIfPossible = cfg["server"]["compression"].to!bool;

	immutable publicPath = cfg["server"]["public_path"].to!string;
	immutable indexPath = buildNormalizedPath(publicPath, "index.html");

	auto router = new URLRouter;
	auto api = new Api;
	ResourceManager.store!Api("api", api);
	router.registerRestInterface(api);
	router.registerWebInterface(new Authenticator(api));
	import api.apidef: IApi;
	router.get("/client.js", serveRestJSClient!IApi(cfg["server"]["api_url"].to!string));
	listenHTTP(settings, router);
	runEventLoop();

	return 0;
}