import vibe.d;
import mysql;
import std.stdio;
import resourcemanager;
import nwn2.tlk;
import api;

int main(string[] args){

	//TODO: get from config
	ResourceManager.path.add("/home/crom/Documents/Neverwinter Nights 2/override/LcdaClientSrc/lcda2da.hak/");
	auto strresolv = new StrRefResolver(
		new Tlk("/home/crom/.wine-nwn2/drive_c/Neverwinter Nights 2/dialog.TLK"),
		new Tlk("/home/crom/Documents/Neverwinter Nights 2/tlk/Lcda.tlk"));
	ResourceManager.store("resolver", strresolv);

	try{
		auto client = new MySQLClient("host=localhost;user=root;pwd=123;db=nwnx");
		ResourceManager.store("sql", client);
	}
	catch(Exception e){
		throw new Exception("MySQL database appears to be offline", e);
	}

	//TODO handle if mysql disconnected


	auto settings = new HTTPServerSettings;
	settings.port = 8080;
	//settings.sessionStore = new MemorySessionStore;
	settings.sessionStore = new RedisSessionStore("127.0.0.1", 1);
	//TODO check is redis started

	auto router = new URLRouter;
	router.get("/node_modules/*", serveStaticFiles(
		"node_modules/",
		new HTTPFileServerSettings("/node_modules"))//Strips "/node_modules" from path
	);
	router.registerWebInterface(new Api);
	router.get("*", function(req, res){
			//TODO: don't serve index.html if requested file type is css/js/png, etc.
			auto settings = new HTTPFileServerSettings();
			settings.options = HTTPFileServerOption.failIfNotFound;

			try return serveStaticFiles("./public/", settings)(req, res);
			catch(HTTPStatusException e){}
			return serveStaticFile("./public/index.html")(req, res);
		});

	listenHTTP(settings, router);
	runEventLoop();

	return 0;
}