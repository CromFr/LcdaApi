import vibe.d;
import mysql;
import std.stdio;
import nwn2.resman;
import nwn2.tlk;

//TODO: exploit this trick internally in resman
class ConnectionWrap{
	alias data this;
	MySQLClient.LockedConnection data;
}

int main(string[] args){

	//TODO: get from config
	ResMan.path ~= "/home/crom/Documents/Neverwinter Nights 2/override/LcdaClientSrc/lcda2da.hak/";
	auto strresolv = new StrRefResolver(
		new Tlk("/home/crom/.wine-nwn2/drive_c/Neverwinter Nights 2/dialog.TLK"),
		new Tlk("/home/crom/Documents/Neverwinter Nights 2/tlk/Lcda.tlk"));
	ResMan.addRes("resolver", strresolv);


	auto client = new MySQLClient("host=localhost;user=root;pwd=123;db=nwnx");
	auto conn = new ConnectionWrap;
	conn.data = client.lockConnection();
	ResMan.addRes("sql", conn);


	auto settings = new HTTPServerSettings;
	settings.port = 8080;
	//settings.sessionStore = new MemorySessionStore;
	settings.sessionStore = new RedisSessionStore("127.0.0.1", 1);

	auto router = new URLRouter;
	router.get("*", serveStaticFiles("public/"));//TODO: not great
	//router.get("/nwn2", serveStaticFiles("/home/crom/.wine-nwn2/drive_c/Neverwinter Nights 2/UI/default/images"));//TODO: not great
	router.registerWebInterface(new WebInterface);

	listenHTTP(settings, router);
	runEventLoop();

	return 0;
}


class WebInterface {

	void index(){
		enum page = "index";
		auto session = this;
		auto test = this;
		render!("page.dt", page, session);
	}

	@path("/:accountToView/charlist/")
	void getCharList(HTTPServerRequest req, HTTPServerResponse res){
		enforceHTTP(authenticated, HTTPStatus.forbidden);
		enforceHTTP(admin || account==req.params["accountToView"], HTTPStatus.forbidden);

		import nwn2.character;
		import std.file;
		import std.path;
		import std.algorithm;

		auto vault = DirEntry(buildNormalizedPath(
			"/home/crom/Documents/Neverwinter Nights 2/servervault/",//TODO: get from config
			req.params["accountToView"]));

		Character[] charList;
		foreach(d ; vault.dirEntries("*.bic", SpanMode.depth)){
			charList ~= new Character(d);
		}
		charList.sort!"a.name<b.name";

		Character[] supprCharList;

		enum page = "charlist";
		auto session = this;
		render!("page.dt", page, session, charList, supprCharList);
	}

	@path("/:accountToView/:char")
	void getChar(HTTPServerRequest req, HTTPServerResponse res){
		enforceHTTP(authenticated, HTTPStatus.forbidden);
		enforceHTTP(admin || account==req.params["accountToView"], HTTPStatus.forbidden);

		import nwn2.character;
		import std.path;

		auto character = new Character(buildNormalizedPath(
			"/home/crom/Documents/Neverwinter Nights 2/servervault/",//TODO: get from config
			req.params["accountToView"],
			req.params["char"]~".bic"
			));

		enum page = "char";
		auto session = this;
		render!("page.dt", page, session, character);
	}

	void postLogin(string login, string password){

		import mysql;
		auto conn = ResMan.get!ConnectionWrap("sql");

		//TODO: move query to settings
		//TODO: escape fields !!!
		bool credsOK;
		conn.execute("SELECT (`password`=SHA(?)) FROM `account` WHERE `name`=?", password, login, (MySQLRow row) {
			credsOK = row[0].get!int == 1;
		});

		enforceHTTP(credsOK, HTTPStatus.forbidden);

		authenticated = true;
		account = login;
		redirect("/");
	}

	void postLogout(){
		terminateSession();
		redirect("/");
	}

@path(""):
	SessionVar!(bool, "authenticated") authenticated;
	SessionVar!(bool, "authenticated") admin;
	SessionVar!(string, "account") account;
}