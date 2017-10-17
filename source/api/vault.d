module api.vault;

import vibe.d;
import mysql : MySQLClient, MySQLRow;
debug import std.stdio: writeln;

import lcda.character;
import api.api;
import api.apidef;
import vibe.web.auth;

class CharListCache{
	ulong hash;
	LightCharacter[] data;
}

@requiresAuth
class Vault(bool deletedChar): IVault!deletedChar{
	this(Api api){
		this.api = api;
	}

	override{
		UserInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res) @safe{
			return api.authenticate(req, res);
		}


		LightCharacter[] getCharList(string _account) @trusted{
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
				.map!(a => LightCharacter(a))
				.array
				.sort!"a.name<b.name"
				.array;

			return cache.data;
		}

		Character charInfo(string _account, string _char) @trusted{
			return getChar(_account, _char, deletedChar);
		}


		void download(string _account, string _char, HTTPServerRequest req, HTTPServerResponse res){
			import std.file: exists, isFile;
			immutable charFile = getCharFile(_account, _char, deletedChar);
			serveStaticFile(charFile)(req, res);
		}

		static if(!deletedChar){
			MovedCharInfo deleteChar(string _account, string _char) @trusted{
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
				return MovedCharInfo(_account, baseName(target, ".bic"), true);
			}
		}

		static if(deletedChar){
			MovedCharInfo restoreChar(string _account, string _char) @trusted{
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

				return MovedCharInfo(_account, baseName(target, ".bic"), false);
			}
		}

		Metadata meta(string _account, string _char) const{
			import std.file : exists, readText;

			Metadata metadata;

			immutable charMetaPath = getCharFile(_account, _char, deletedChar)~".meta";
			if(charMetaPath.exists){
				metadata = charMetaPath
					.readText
					.deserializeJson!Metadata;
			}

			return metadata;
		}

		void meta(string _account, string _char, Metadata metadata){
			immutable charMetaPath = getCharFile(_account, _char, deletedChar)~".meta";
			charMetaPath.writeFile(metadata.serializeToJsonString.to!(ubyte[]));
		}

	}


private:
	Api api;


	Character getChar(in string account, in string bicName, bool deleted){
		import std.file : DirEntry, exists, isFile;

		immutable path = getCharFile(account, bicName, deleted);
		enforceHTTP(path.exists && path.isFile, HTTPStatus.notFound, "Character '"~bicName~"' not found");
		return Character(account, DirEntry(path), api.mysqlConnection);
	}

	string getCharFile(in string accountName, in string bicFile, bool deleted) const{
		import std.path : buildNormalizedPath, baseName;
		assert(accountName.baseName == accountName, "account name should not be a path");
		assert(bicFile.baseName == bicFile, "bic file name should not be a path");

		return buildNormalizedPath(getVaultPath(accountName, deleted), bicFile~".bic");
	}

	string getVaultPath(in string accountName, bool deleted) const{
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

}