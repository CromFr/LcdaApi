module api.character;

import vibe.d;
import mysql : MySQLClient, MySQLRow;

import nwn2.character;
import api.api;

class CharApi{
	this(Api api){
		this.api = api;

	}

	@path("/")
	Json getCharList(string _account){
		enforceHTTP(api.authenticated, HTTPStatus.unauthorized);
		enforceHTTP(api.admin || _account==api.account, HTTPStatus.forbidden);

		//TODO cache list in a session var, invalidate cache on new file

		import std.file : dirEntries, SpanMode;
		import std.algorithm : sort, map;
		import std.array : array;

		return getVaultPath(_account)
			.dirEntries("*.bic", SpanMode.shallow)
			.map!(a => new Character(a))
			.map!(a => LightCharacter(a.name,a.race,a.lvl,a.classes,a.bicFileName))
			.array
			.sort!"a.name<b.name"
			.array
			.serializeToJson;
	}
	@path("/deleted/")
	Json getDeletedCharList(string _account){
		enforceHTTP(api.authenticated, HTTPStatus.unauthorized);
		enforceHTTP(api.admin || _account==api.account, HTTPStatus.forbidden);

		import std.file : dirEntries, SpanMode, exists, isDir;
		import std.algorithm : sort, map;
		import std.array : array;

		auto deletedVaultPath = getDeletedVaultPath(_account);

		if(deletedVaultPath.exists && deletedVaultPath.isDir){
			return deletedVaultPath
				.dirEntries("*.bic", SpanMode.shallow)
				.map!(a => new Character(a))
				.map!(a => LightCharacter(a.name,a.race,a.lvl,a.classes,a.bicFileName))
				.array
				.sort!"a.name<b.name"
				.array
				.serializeToJson;
		}
		return Json.emptyArray;
	}


	@path("/:char/download")
	auto getCharacterDownload(string _account, string _char, HTTPServerRequest req, HTTPServerResponse res){
		enforceHTTP(api.authenticated, HTTPStatus.unauthorized);
		enforceHTTP(api.admin || _account==api.account, HTTPStatus.forbidden);

		import std.file: exists, isFile;
		immutable charFile = getCharFile(_account, _char);

		enforceHTTP(charFile.exists && charFile.isFile, HTTPStatus.notFound, "Character '"~_char~"' not found");

		return serveStaticFile(charFile)(req, res);
	}


	@path("/:char")
	Json getActiveCharInfo(string _account, string _char){
		enforceHTTP(api.authenticated, HTTPStatus.unauthorized);
		enforceHTTP(api.admin || _account==api.account, HTTPStatus.forbidden);

		return getChar(_account, _char, false).serializeToJson;
	}
	@path("/deleted/:char")
	Json getDeletedCharInfo(string _account, string _char){
		enforceHTTP(api.authenticated, HTTPStatus.unauthorized);
		enforceHTTP(api.admin || _account==api.account, HTTPStatus.forbidden);

		return getChar(_account, _char, true).serializeToJson;
	}



	///Moves the character to the deleted vault
	/// The new file name will be oldName~"-"~index~".bic" with index starting from 0
	///Returns the new bic file name
	@path("/:char/delete")
	Json postDeleteChar(string _account, string _char){
		enforceHTTP(api.authenticated, HTTPStatus.unauthorized);
		enforceHTTP(api.admin || _account==api.account, HTTPStatus.forbidden);

		import std.file : exists, isFile, rename, mkdirRecurse;
		import std.path : buildPath, baseName;

		immutable charFile = getCharFile(_account, _char, false);
		enforceHTTP(charFile.exists && charFile.isFile, HTTPStatus.notFound, "Character '"~_char~"' not found");

		immutable deletedVault = getDeletedVaultPath(_account);
		if(!deletedVault.exists){
			mkdirRecurse(deletedVault);
		}

		string target;
		int index = 0;
		do{
			target = buildPath(deletedVault, _char~"-"~(index++).to!string~".bic");
		}while(target.exists);

		api.mysqlConnection.execute(api.cfg.sql_queries.on_delete.to!string);

		debug{
			import std.stdio : writeln;
			writeln("Renaming '",charFile,"' to '",target,"'");
		}
		rename(charFile, target);

		return Json(["newBicFile": Json(baseName(target, ".bic"))]);
	}

	@path("/deleted/:char/activate")
	Json postActivateChar(string _account, string _char){
		enforceHTTP(api.authenticated, HTTPStatus.unauthorized);
		enforceHTTP(api.admin || _account==api.account, HTTPStatus.forbidden);

		import std.file : exists, isFile, rename, mkdirRecurse;
		import std.path : buildPath, baseName;
		import std.regex : matchFirst, ctRegex;

		immutable charFile = getCharFile(_account, _char, true);
		enforceHTTP(charFile.exists && charFile.isFile, HTTPStatus.notFound, "Character '"~_char~"' not found");

		immutable accountVault = getVaultPath(_account);
		immutable newName = _char.matchFirst(ctRegex!r"^(.+?)-\d+$")[1];

		immutable target = buildPath(accountVault, newName~".bic");
		enforceHTTP(!target.exists, HTTPStatus.conflict, "An active character has the same name.");

		api.mysqlConnection.execute(api.cfg.sql_queries.on_activate.to!string);

		debug{
			import std.stdio : writeln;
			writeln("Renaming '",charFile,"' to '",target,"'");
		}
		rename(charFile, target);

		return Json(["newBicFile": Json(baseName(target, ".bic"))]);
	}


	struct LightCharacter{
		string name;
		string race;
		int lvl;
		Character.Class[] classes;
		string bicFileName;
	}

private:
	Api api;

	Character getChar(in string account, in string bicName, bool deleted=false){
		import std.file : DirEntry, exists, isFile;

		immutable path = getCharFile(account, bicName, deleted);
		enforceHTTP(path.exists && path.isFile, HTTPStatus.notFound, "Character '"~bicName~"' not found");
		return new Character(DirEntry(path));
	}

	auto ref getVaultPath(in string accountName){
		import std.path : buildNormalizedPath, baseName;
		assert(accountName.baseName == accountName, "account name should not be a path");
		return buildNormalizedPath(api.cfg.paths.servervault.to!string, accountName);
	}

	auto ref getDeletedVaultPath(in string accountName){
		import std.path : buildNormalizedPath, baseName, isAbsolute;
		assert(accountName.baseName == accountName, "account name should not be a path");

		immutable deletedVault = api.cfg.paths.servervault_deleted.to!string;
		if(deletedVault.isAbsolute)
			return buildNormalizedPath(deletedVault, accountName);
		else
			return buildNormalizedPath(api.cfg.paths.servervault.to!string, accountName, deletedVault);
	}

	auto ref getCharFile(in string accountName, in string bicFile, bool deleted=false){
		import std.path : buildNormalizedPath, baseName;
		assert(accountName.baseName == accountName, "account name should not be a path");
		assert(bicFile.baseName == bicFile, "bic file name should not be a path");

		if(deleted)
			return buildNormalizedPath(getDeletedVaultPath(accountName), bicFile~".bic");
		return buildNormalizedPath(api.cfg.paths.servervault.to!string, accountName, bicFile~".bic");
	}

}