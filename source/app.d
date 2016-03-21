import vibe.d;
import std.stdio;


int main(string[] args){
	auto settings = new HTTPServerSettings;
	settings.port = 8080;
	//settings.sessionStore = new MemorySessionStore;
	settings.sessionStore = new RedisSessionStore("127.0.0.1", 1);

	auto router = new URLRouter;
	router.get("*", serveStaticFiles("public/"));
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

		auto vault = DirEntry(buildNormalizedPath(
			"/home/crom/Documents/Neverwinter Nights 2/servervault/",//TODO: get from config
			req.params["accountToView"]));

		Character[] charList;
		foreach(d ; vault.dirEntries("*.bic", SpanMode.depth)){
			charList ~= new Character(d);
		}

		enum page = "charlist";
		auto session = this;
		render!("page.dt", page, session, charList);
	}

	@path("/:accountToView/:char")
	void getChar(HTTPServerRequest req, HTTPServerResponse res){

		enum page = "char";
		auto session = this;
		render!("page.dt", page, session);
	}

	void postLogin(string login, string password){
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