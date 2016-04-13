import vibe.d;
debug import std.stdio : writeln;
import mysql : MySQLClient, MySQLRow;
import std.typecons : Tuple;

import nwn2.character;
import config;



/// Json API
///    /login login password
///    /logout
///    /:account/characters/list
///    /:account/characters/:char/
///    /:account/characters/:char/delete
///    /:account/characters/:char/download
///    /:account/characters/deleted/:char/
///    /:account/characters/deleted/:char/activate
///    /:account/characters/deleted/:char/download
///
@path("/api")
class Api{
	import vibe.web.common : PathAttribute;

	this(){
		import resourcemanager : ResourceManager;
		cfg = ResourceManager.get!Config("cfg");
		mysqlConnection = ResourceManager.getMut!MySQLClient("sql").lockConnection();
	}

	@path("/:account/characters/:char/download")
	auto getCharacterDownload(string _account, string _char, HTTPServerRequest req, HTTPServerResponse res){
		enforceHTTP(authenticated, HTTPStatus.unauthorized);
		enforceHTTP(admin || _account==account, HTTPStatus.forbidden);

		import std.file: exists;
		immutable charFile = getCharFile(_account, _char);

		enforceHTTP(charFile.exists, HTTPStatus.notFound, "Character not found");

		return serveStaticFile(charFile)(req, res);
	}

	@path("/:account/characters/list")
	Json getCharList(string _account){
		enforceHTTP(authenticated, HTTPStatus.unauthorized);
		enforceHTTP(admin || _account==account, HTTPStatus.forbidden);

		//TODO: what if _account="../../secureThing" ?

		import std.file : DirEntry, dirEntries, SpanMode, exists, isDir;
		import std.path : buildNormalizedPath;
		import std.algorithm : sort, map;
		import std.array : array;

		alias CharList = Tuple!(Character[],"active",Character[],"deleted");

		auto activeVault = DirEntry(buildNormalizedPath(
				cfg.paths.servervault.to!string,
				_account));

		auto activeChars = activeVault
				.dirEntries("*.bic", SpanMode.shallow)
				.map!(a => new Character(a))
				.array
				.sort!"a.name<b.name"
				.array;

		auto deletedVaultPath = buildNormalizedPath(
			activeVault,
			cfg.paths.servervault_deleted.to!string);

		Character[] deletedChars = null;
		if(deletedVaultPath.exists && deletedVaultPath.isDir){
			deletedChars = DirEntry(deletedVaultPath)
					.dirEntries("*.bic", SpanMode.shallow)
					.map!(a => new Character(a, true))
					.array
					.sort!"a.name<b.name"
					.array;
		}

		return CharList(activeChars, deletedChars).serializeToJson;
	}
	@path("/:account/characters/:char")
	Json getActiveCharInfo(string _account, string _char){
		enforceHTTP(authenticated, HTTPStatus.unauthorized);
		enforceHTTP(admin || _account==account, HTTPStatus.forbidden);
		return getCharInfo(_account, _char).serializeToJson;
	}
	@path("/:account/characters/deleted/:char")
	Json getDeletedCharInfo(string _account, string _char){
		enforceHTTP(authenticated, HTTPStatus.unauthorized);
		enforceHTTP(admin || _account==account, HTTPStatus.forbidden);
		return getCharInfo(_account, _char, true).serializeToJson;
	}

	//Moves the character to the deleted vault
	// The new file name will be oldName~"-"~index~".bic" with index starting from 0
	//Returns the new bic file name
	@path("/:account/characters/:char/delete")
	Json postDeleteChar(string _account, string _char){
		enforceHTTP(authenticated, HTTPStatus.unauthorized);
		enforceHTTP(admin || _account==account, HTTPStatus.forbidden);

		import std.file : exists, rename, mkdirRecurse;
		import std.path : buildPath, baseName;

		immutable charFile = getCharFile(_account, _char, false);
		enforceHTTP(charFile.exists, HTTPStatus.notFound, "Character not found");

		immutable deletedVault = getDeletedVaultPath(_account);
		if(!deletedVault.exists){
			mkdirRecurse(deletedVault);
		}

		string target;
		int index = 0;
		do{
			target = buildPath(deletedVault, _char~"-"~(index++).to!string~".bic");
		}while(target.exists);

		mysqlConnection.execute(cfg.sql_queries.on_delete.to!string);

		writeln("Renaming '",charFile,"' to '",target,"'");
		rename(charFile, target);

		return Json(["newBicFile": Json(baseName(target, ".bic"))]);
	}

	@path("/:account/characters/deleted/:char/activate")
	Json postActivateChar(string _account, string _char){
		enforceHTTP(authenticated, HTTPStatus.unauthorized);
		enforceHTTP(admin || _account==account, HTTPStatus.forbidden);

		import std.file : exists, rename, mkdirRecurse;
		import std.path : buildPath, baseName;
		import std.regex : matchFirst, ctRegex;

		immutable charFile = getCharFile(_account, _char, true);
		enforceHTTP(charFile.exists, HTTPStatus.notFound, "Character not found");

		immutable accountVault = getVaultPath(_account);
		immutable newName = _char.matchFirst(ctRegex!r"^(.+?)-\d+$")[1];

		immutable target = buildPath(accountVault, newName~".bic");
		enforceHTTP(!target.exists, HTTPStatus.conflict, "An active character has the same name.");

		mysqlConnection.execute(cfg.sql_queries.on_activate.to!string);

		writeln("Renaming '",charFile,"' to '",target,"'");
		rename(charFile, target);

		return Json(["newBicFile": Json(baseName(target, ".bic"))]);
	}

	Json postLogin(string login, string password){
		import sql : replacePlaceholders, Placeholder;
		import resourcemanager : ResourceManager;

		immutable query = cfg.sql_queries.login.to!string
			.replacePlaceholders(
				Placeholder!string("ACCOUNT", login),
				Placeholder!string("PASSWORD", password)
			);

		bool credsOK = false, isAdmin;
		mysqlConnection.execute(query, (MySQLRow row){
			credsOK = row.success.get!int == 1;
			isAdmin = row.admin.get!int == 1;
		});

		enforceHTTP(credsOK, HTTPStatus.unauthorized);

		authenticated = true;
		account = login;
		admin = isAdmin;

		return getSession();
	}
	Json getSession(){
		import std.traits : hasUDA;

		auto ret = Json.emptyObject;
		foreach(member ; __traits(allMembers, Api)){
			static if(hasUDA!(mixin("Api."~member), "session")){
				ret[member] = mixin(member~".value");
			}
		}
		return ret;
	}
	void postLogout(){
		terminateSession();
		enforceHTTP(false, HTTPStatus.ok);
	}


private:
	@("session"){
		SessionVar!(bool, "authenticated") authenticated;
		SessionVar!(bool, "admin") admin;
		SessionVar!(string, "account") account;
	}
	MySQLClient.LockedConnection mysqlConnection;

	Character getCharInfo(in string account, in string bicName, bool deleted=false){
		import std.file : DirEntry, exists;
		import std.path : buildNormalizedPath;

		immutable path = buildNormalizedPath(
			cfg.paths.servervault.to!string,
			account,
			deleted? cfg.paths.servervault_deleted.to!string : "",
			bicName~".bic");

		enforceHTTP(path.exists, HTTPStatus.notFound, "Character not found");

		return new Character(DirEntry(path));
	}

	immutable Config cfg;

	auto ref getVaultPath(in string account){
		import std.path : buildNormalizedPath;
		return buildNormalizedPath(cfg.paths.servervault.to!string, account);
	}

	auto ref getDeletedVaultPath(in string account){
		import std.path : buildNormalizedPath, isAbsolute;

		immutable deletedVault = cfg.paths.servervault_deleted.to!string;
		if(deletedVault.isAbsolute)
			return buildNormalizedPath(deletedVault, account);
		else
			return buildNormalizedPath(cfg.paths.servervault.to!string, account, deletedVault);
	}

	auto ref getCharFile(in string account, in string bicFile, bool deleted=false){
		import std.path : buildNormalizedPath;
		if(deleted)
			return buildNormalizedPath(getDeletedVaultPath(account), bicFile~".bic");
		return buildNormalizedPath(cfg.paths.servervault.to!string, account, bicFile~".bic");
	}


}