import vibe.d;
import std.typecons;
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

		import std.path;
		import std.file;

		immutable charFile = buildNormalizedPath(
			cfg.paths.servervault.to!string,
			_account,
			_char~".bic");

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
	@path("/:account/characters/:char/delete")
	void _postDeleteChar(string _account, string _char){
		enforceHTTP(authenticated, HTTPStatus.unauthorized);
		enforceHTTP(admin || _account==account, HTTPStatus.forbidden);

		import std.file : exists, isDir, rename, mkdir;
		import std.path : buildNormalizedPath;

		auto accountVault = buildNormalizedPath(
			cfg.paths.servervault.to!string,
			_account);

		auto charToDelete = buildNormalizedPath(accountVault, _char~".bic");
		enforceHTTP(charToDelete.exists, HTTPStatus.notFound, "Character not found");

		auto destinationFolder = buildNormalizedPath(
				accountVault,
				cfg.paths.servervault_deleted.to!string);

		if(!destinationFolder.exists){
			mkdir(destinationFolder);
		}


		auto target = buildNormalizedPath(destinationFolder, _char~".bic");
		if(target.exists){
			import std.regex : ctRegex, matchFirst;
			enum rgx = ctRegex!r"^(.+?)(\d*)$";
			auto match = _char.matchFirst(rgx);
			if(match.empty)throw new Exception("Unable to parse character name: "~_char);

			string newName = match[1];
			int index = match[2].to!int;

			while(target.exists){
				target = buildNormalizedPath(destinationFolder, newName~(++index).to!string~".bic");
			}
		}

		import std.stdio : writeln;
		writeln("Renaming '",accountVault,"' to '",target,"'");
		rename(accountVault, target);
	}

	Json _postLogin(string login, string password){
		import mysql : MySQLClient, MySQLRow;
		import resourcemanager;
		auto conn = ResourceManager.getMut!MySQLClient("sql").lockConnection();
		//TODO: will lockConnection retrieve an already locked connection instead of creating a new one?

		//TODO: move query to settings?
		//TODO: Check if fields are correctly escaped
		//TODO: salt this hash
		bool credsOK;
		conn.execute("SELECT (`password`=SHA(?)) FROM `account` WHERE `name`=?", password, login, (MySQLRow row){
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
		import std.file : DirEntry;
		import std.path : buildNormalizedPath;

		return new Character(DirEntry(buildNormalizedPath(
			cfg.paths.servervault.to!string,
			account,
			deleted? cfg.paths.servervault_deleted.to!string : "",
			bicName~".bic"
			)));
	}

	immutable Config cfg;


}