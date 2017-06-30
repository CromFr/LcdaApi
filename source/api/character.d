module api.character;

import vibe.d;
import mysql : MySQLClient, MySQLRow;
debug import std.stdio: writeln;

import nwn.character;
import api.api;

class CharListCache{
	ulong hash;
	Json data;
}
struct CharacterMetadata{
@optional:
	@name("public") bool isPublic = false;
}

class CharApi(bool deletedChar){
	this(Api api){
		this.api = api;

	}

	@path("/")
	Json getList(string _account, HTTPServerRequest req){
		auto auth = api.authenticate(req);
		enforceHTTP(auth.authenticated, HTTPStatus.unauthorized);
		enforceHTTP(auth.admin || _account==auth.account, HTTPStatus.forbidden);

		import std.file: dirEntries, SpanMode, getTimes;
		import std.algorithm: sort, map;
		import std.array: array;
		import resourcemanager: ResourceManager, ResourceException;

		immutable vaultPath = getVaultPath(_account, deletedChar);

		CharListCache cache;
		auto hash = vaultPath
			.dirEntries("*.bic", SpanMode.shallow)
			.map!((file){
				import std.conv: to;
				SysTime acc, mod;
				file.getTimes(acc, mod);
				return file.name~"="~acc.to!string;
			})
			.join(":")
			.hashOf;

		try{
			cache = ResourceManager.getMut!CharListCache("cache/"~(deletedChar? "deleted/" : null)~_account);
			if(hash == cache.hash){
				return cache.data;
			}
		}
		catch(ResourceException){
			cache = new CharListCache;
			ResourceManager.store("cache/"~(deletedChar? "deleted/" : null)~_account, cache);
		}

		cache.hash = hash;
		cache.data = vaultPath
			.dirEntries("*.bic", SpanMode.shallow)
			.map!(a => new LightCharacter(a))
			.array
			.sort!"a.name<b.name"
			.array
			.serializeToJson;

		return cache.data;
	}

	@path("/:char")
	Json getCharInfo(string _account, string _char, HTTPServerRequest req){
		if(!getMetaData(_account, _char).isPublic){
			auto auth = api.authenticate(req);
			enforceHTTP(auth.authenticated, HTTPStatus.unauthorized);
			enforceHTTP(auth.admin || _account==auth.account, HTTPStatus.forbidden);
		}

		return getChar(_account, _char, deletedChar).serializeToJson;
	}


	@path("/:char/download")
	auto getDownload(string _account, string _char, HTTPServerRequest req, HTTPServerResponse res){
		if(!getMetaData(_account, _char).isPublic){
			auto auth = api.authenticate(req);
			enforceHTTP(auth.authenticated, HTTPStatus.unauthorized);
			enforceHTTP(auth.admin || _account==auth.account, HTTPStatus.forbidden);
		}

		import std.file: exists, isFile;
		immutable charFile = getCharFile(_account, _char, deletedChar);

		enforceHTTP(charFile.exists && charFile.isFile, HTTPStatus.notFound, "Character '"~_char~"' not found");

		return serveStaticFile(charFile)(req, res);
	}

	static if(!deletedChar){
		///Moves the character to the deleted vault
		/// The new file name will be oldName~"-"~index~".bic" with index starting from 0
		///Returns the new bic file name
		@path("/:char/delete")
		Json postDeleteChar(string _account, string _char, HTTPServerRequest req){
			auto auth = api.authenticate(req);
			enforceHTTP(auth.authenticated, HTTPStatus.unauthorized);
			enforceHTTP(auth.admin || _account==auth.account, HTTPStatus.forbidden);

			import std.file : exists, isFile, rename, mkdirRecurse;
			import std.path : buildPath, baseName;
			import sql: replacePlaceholders, SqlPlaceholder;

			immutable charFile = getCharFile(_account, _char, deletedChar);
			enforceHTTP(charFile.exists && charFile.isFile, HTTPStatus.notFound, "Character '"~_char~"' not found");

			immutable deletedVault = getVaultPath(_account, true);
			if(!deletedVault.exists){
				mkdirRecurse(deletedVault);
			}

			string target;
			int index = 0;
			do{
				target = buildPath(deletedVault, _char~"-"~(index++).to!string~".bic");
			}while(target.exists);


			auto queries = api.cfg["sql_queries"]["on_delete"].get!(Json[]);
			foreach(ref query ; queries){
				api.mysqlConnection.execute(
					query.to!string.replacePlaceholders(
						SqlPlaceholder("ACCOUNT", _account),
						SqlPlaceholder("CHAR", _char),
					)
				);
			}

			debug{
				import std.stdio : writeln;
				writeln("Renaming '",charFile,"' to '",target,"'");
			}
			charFile.rename(target);
			if((charFile~".meta").exists){
				(charFile~".meta").rename(target~".meta");
			}
			return Json(["newBicFile": Json(baseName(target, ".bic"))]);
		}
	}

	static if(deletedChar){
		@path("/:char/activate")
		Json postActivateChar(string _account, string _char, HTTPServerRequest req){
			auto auth = api.authenticate(req);
			enforceHTTP(auth.authenticated, HTTPStatus.unauthorized);
			enforceHTTP(auth.admin || _account==auth.account, HTTPStatus.forbidden);

			import std.file : exists, isFile, rename, mkdirRecurse;
			import std.path : buildPath, baseName;
			import std.regex : matchFirst, ctRegex;
			import sql: replacePlaceholders, SqlPlaceholder;

			immutable charFile = getCharFile(_account, _char, deletedChar);
			enforceHTTP(charFile.exists && charFile.isFile, HTTPStatus.notFound, "Character '"~_char~"' not found");

			immutable accountVault = getVaultPath(_account, false);
			immutable newName = _char.matchFirst(ctRegex!`^(.+?)-\d+$`)[1];

			immutable target = buildPath(accountVault, newName~".bic");
			enforceHTTP(!target.exists, HTTPStatus.conflict, "An active character has the same name.");

			auto queries = api.cfg["sql_queries"]["on_activate"].get!(Json[]);
			foreach(ref query ; queries){
				api.mysqlConnection.execute(
					query.to!string.replacePlaceholders(
						SqlPlaceholder("ACCOUNT", _account),
						SqlPlaceholder("CHAR", _char),
					)
				);
			}

			debug{
				import std.stdio : writeln;
				writeln("Renaming '",charFile,"' to '",target,"'");
			}
			charFile.rename(target);
			if((charFile~".meta").exists){
				(charFile~".meta").rename(target~".meta");
			}

			return Json(["newBicFile": Json(baseName(target, ".bic"))]);
		}
	}



	@path("/:char/meta"){
		void setMeta(string _account, string _char, HTTPServerRequest req){
			auto auth = api.authenticate(req);
			enforceHTTP(auth.authenticated, HTTPStatus.unauthorized);
			enforceHTTP(auth.admin || _account==auth.account, HTTPStatus.forbidden);

			setMetadata(_account, _char, req.json);
			enforceHTTP(false, HTTPStatus.ok);//TODO: must be a better way
		}
		Json getMeta(string _account, string _char, HTTPServerRequest req){
			immutable meta = getMetaData(_account, _char);
			if(!meta.isPublic){
				auto auth = api.authenticate(req);
				enforceHTTP(auth.authenticated, HTTPStatus.unauthorized);
				enforceHTTP(auth.admin || _account==auth.account, HTTPStatus.forbidden);
			}
			return meta.serializeToJson;
		}
	}


private:
	Api api;


	Character getChar(in string account, in string bicName, bool deleted){
		import std.file : DirEntry, exists, isFile;

		immutable path = getCharFile(account, bicName, deleted);
		enforceHTTP(path.exists && path.isFile, HTTPStatus.notFound, "Character '"~bicName~"' not found");
		return new Character(account, DirEntry(path), api.mysqlConnection);
	}

	auto ref getCharFile(in string accountName, in string bicFile, bool deleted){
		import std.path : buildNormalizedPath, baseName;
		assert(accountName.baseName == accountName, "account name should not be a path");
		assert(bicFile.baseName == bicFile, "bic file name should not be a path");

		return buildNormalizedPath(getVaultPath(accountName, deleted), bicFile~".bic");
	}

	auto ref getVaultPath(in string accountName, bool deleted){
		import std.path : buildNormalizedPath, baseName, isAbsolute;
		assert(accountName.baseName == accountName, "account name should not be a path");

		if(!deleted){
			return buildNormalizedPath(api.cfg["paths"]["servervault"].to!string, accountName);
		}
		else{
			immutable deletedVault = api.cfg["paths"]["servervault_deleted"].to!string;
			if(deletedVault.isAbsolute)
				return buildNormalizedPath(deletedVault, accountName);
			else
				return buildNormalizedPath(api.cfg["paths"]["servervault"].to!string, accountName, deletedVault);
		}

	}


	//Metadata
	void setMetadata(string account, string character, Json metadata){
		auto md = metadata.deserializeJson!CharacterMetadata;

		immutable charMetaPath = getCharFile(account, character, deletedChar)~".meta";
		charMetaPath.writeFile(cast(ubyte[])md.serializeToJsonString);
	}
	CharacterMetadata getMetaData(string account, string character){
		import std.file : exists, readText;

		CharacterMetadata metadata;

		immutable charMetaPath = getCharFile(account, character, deletedChar)~".meta";
		if(charMetaPath.exists){
			metadata = charMetaPath
				.readText
				.deserializeJson!CharacterMetadata;
		}

		return metadata;
	}

}