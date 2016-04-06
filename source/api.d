import vibe.d;
debug import std.stdio : writeln;

import nwn2.character;
import config;


private string implementJsonIface(API)(){
	import std.traits;
	import std.meta : AliasSeq;
	import std.string : format;
	string ret;

	foreach(member ; __traits(allMembers, API)){
		static if(__traits(getProtection, mixin("API."~member))=="package"
			&& isCallable!(mixin("API."~member))
			&& member[0]=='_'){

			enum attributes = __traits(getFunctionAttributes, mixin("API."~member));
			alias UDAs = AliasSeq!(__traits(getAttributes, mixin("API."~member)));
			alias ParamNames = ParameterIdentifierTuple!(mixin("API."~member));
			alias ParamTypes = Parameters!(mixin("API."~member));
			alias Return = ReturnType!(mixin("API."~member));

			enum paramTypes = ParamTypes.stringof[1..$-1].split(", ");

			//UDAs
			foreach(uda ; UDAs)
				ret ~= "@"~uda.stringof~" ";
			ret ~= "\n";
			//Return type
			static if(is(Return==void))
				ret ~= "void ";
			else
				ret ~= "Json ";
			//Name
			ret ~= member[1..$];
			//Parameters
			ret ~= "(";
			static if(ParamNames.length>0){
				foreach(i, name ; ParamNames){
					static if(i>0) ret ~= ", ";
					ret ~= paramTypes[i]~" "~name;
				}
			}
			ret ~= ") ";
			//Function attributes
			ret ~= [attributes].join(" ")~"{\n";
			//Body
			ret ~= "\treturn this."~member~"(";
			static if(ParamNames.length>0)
				ret ~= [ParamNames].join(", ");
			ret ~= ")";
			//Body - Serialization
			static if(!is(Return==void) && !is(Return==Json))
				ret ~= ".serializeToJson()";
			ret ~= ";\n";
			//end
			ret ~= "}\n";
		}

	}
	return ret;
}
/// Json API
///    /api/login login password
///    /api/logout
///    /api/:account/characters/list
///    /api/:account/characters/:char/
///    /api/:account/characters/:char/delete
///    /api/:account/characters/:char/download
///    /api/:account/characters/deleted/:char/
///    /api/:account/characters/deleted/:char/activate
///    /api/:account/characters/deleted/:char/download
///
@path("/api")
class Api{
	this(){
		import resourcemanager : ResourceManager;
		cfg = ResourceManager.get!Config("cfg");
	}

	mixin(implementJsonIface!Api);

	@path("/:account/characters/:char/download")
	auto getCharacterDownload(string _account, string _char, HTTPServerRequest req, HTTPServerResponse res){
		enforceHTTP(authenticated, HTTPStatus.unauthorized);
		enforceHTTP(admin || _account==account, HTTPStatus.forbidden);

		import std.file: exists;
		immutable charFile = getCharFile(_account, _char);

		enforceHTTP(charFile.exists, HTTPStatus.notFound, "Character not found");

		return serveStaticFile(charFile)(req, res);
	}


package:
	alias CharList = Tuple!(Character[],"active",Character[],"deleted");

	@path("/:account/characters/list")
	CharList _getCharList(string _account){
		enforceHTTP(authenticated, HTTPStatus.unauthorized);
		enforceHTTP(admin || _account==account, HTTPStatus.forbidden);

		//TODO: what if _account="../../secureThing" ?

		import std.file : DirEntry, dirEntries, SpanMode, exists, isDir;
		import std.path : buildNormalizedPath;
		import std.algorithm : sort;

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

		return CharList(activeChars, deletedChars);
	}
	@path("/:account/characters/:char")
	Character _getActiveCharInfo(string _account, string _char){
		enforceHTTP(authenticated, HTTPStatus.unauthorized);
		enforceHTTP(admin || _account==account, HTTPStatus.forbidden);
		return getCharInfo(_account, _char);
	}
	@path("/:account/characters/deleted/:char")
	Character _getDeletedCharInfo(string _account, string _char){
		enforceHTTP(authenticated, HTTPStatus.unauthorized);
		enforceHTTP(admin || _account==account, HTTPStatus.forbidden);
		return getCharInfo(_account, _char, true);
	}

	//Moves the character to cfg.paths.servervault_deleted.
	// The new file name will be oldName~"-"~index~".bic" with index starting from 0
	//Returns the new bic file name
	@path("/:account/characters/:char/delete")
	Json _postDeleteChar(string _account, string _char){
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

		writeln("Renaming '",charFile,"' to '",target,"'");
		rename(charFile, target);

		return Json(["newBicFile": Json(baseName(target, ".bic"))]);
	}

	@path("/:account/characters/deleted/:char/activate")
	Json _postActivateChar(string _account, string _char){
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

		writeln("Renaming '",charFile,"' to '",target,"'");
		rename(charFile, target);

		return Json(["newBicFile": Json(baseName(target, ".bic"))]);
	}

	Json _postLogin(string login, string password){
		import mysql : MySQLClient, MySQLRow;
		import sql;
		import resourcemanager;
		auto conn = ResourceManager.getMut!MySQLClient("sql").lockConnection();
		//TODO: will lockConnection retrieve an already locked connection instead of creating a new one?

		immutable query = cfg.sql_queries.login.to!string
			.replacePlaceholders(
				Placeholder!string("ACCOUNT", login),
				Placeholder!string("PASSWORD", password)
			);

		bool credsOK;
		conn.execute(query, (MySQLRow row){
			credsOK = row[0].get!int == 1;
		});

		enforceHTTP(credsOK, HTTPStatus.unauthorized);

		authenticated = true;
		account = login;

		return _getSession();
	}
	Json _getSession(){
		import std.traits : hasUDA;

		auto ret = Json.emptyObject;
		foreach(member ; __traits(allMembers, Api)){
			static if(hasUDA!(mixin("Api."~member), session)){
				ret[member] = mixin(member~".value");
			}
		}
		return ret;
	}
	void _postLogout(){
		terminateSession();

		//enforceHTTP(false, HTTPStatus.ok);//TODO: There must be a better way
	}

private:
	enum session;
	@session{
		SessionVar!(bool, "authenticated") authenticated;
		SessionVar!(bool, "admin") admin;
		SessionVar!(string, "account") account;
	}

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