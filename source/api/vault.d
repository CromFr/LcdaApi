module api.vault;

import vibe.d;
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


		LightCharacter[] list(string _account) @trusted{
			import std.file: dirEntries, SpanMode, getTimes, exists;
			import std.algorithm: sort, map;
			import std.array: array;
			import resourcemanager: ResourceManager, ResourceException;
			import std.file: exists, isDir;

			immutable vaultPath = getVaultPath(_account, deletedChar);
			enforceHTTP(vaultPath.exists && vaultPath.isDir, HTTPStatus.notFound,
				"Account / Vault not found");

			static struct CachedList{
				this() @disable;
				this(in string vaultPath, LightCharacter[] list){
					this.vaultPath = vaultPath;
					this.list = list;
					hash = calcHash();
				}
				string vaultPath;
				LightCharacter[] list;

				ulong hash;
				ulong calcHash() const{
					return vaultPath
						.dirEntries("*.bic*", SpanMode.shallow)
						.map!((file){
							import std.conv: to;
							SysTime acc, mod;
							file.getTimes(acc, mod);
							return file.name~"="~acc.to!string;
						})
						.join(":")
						.hashOf;
				}
			}

			import cache: Cache;
			return cast(LightCharacter[]) Cache.get!(const CachedList)(vaultPath,
				function(in CachedList rec, lastAccess){
					return !rec.vaultPath.exists
					|| rec.hash != rec.calcHash();
				},
				{
					scope(success){
						import std.stdio : writeln, stdout;
						writeln("Generated character list ", _account ~ (deletedChar ? "/deleted" : null));
						stdout.flush();
					}
					return CachedList(vaultPath,
						vaultPath.dirEntries("*.bic", SpanMode.shallow)
						         .map!(a => LightCharacter(a, true))
						         .array
						         .sort!"a.name<b.name"
						         .array);
				}).list;
		}

		Character character(string _account, string _char) @trusted{
			import cache;
			import std.file: exists, isFile, timeLastModified;

			immutable file = getCharPath(_account, _char, deletedChar);
			enforceHTTP(file.exists && file.isFile, HTTPStatus.notFound,
				"Character '"~_char~"' not found");

			static struct CachedCharacter{
				string filePath;
				SysTime lastModified;
				Character character;
			}

			return cast(Character) Cache.get!(const CachedCharacter)(file,
				function(in CachedCharacter rec, lastAccess){
					return !rec.filePath.exists
					|| rec.filePath.timeLastModified > rec.lastModified
					|| (lastAccess - Clock.currTime()) > dur!"minutes"(15);
				},
				{
					scope(success){
						import std.stdio : writeln, stdout;
						writeln("Generated character info ", _account ~ (deletedChar ? "/deleted/" : "/") ~ _char);
						stdout.flush();
					}
					return CachedCharacter(
						file,
						file.timeLastModified,
						getChar(_account, _char, deletedChar));
				}).character;
		}


		void downloadChar(string _account, string _char, HTTPServerRequest req, HTTPServerResponse res){
			import std.file: exists, isFile;
			import std.path : baseName;

			immutable charFile = getCharPath(_account, _char, deletedChar);
			enforceHTTP(charFile.exists && charFile.isFile, HTTPStatus.notFound,
				"Character '"~charFile~"' not found");

			res.headers["Content-Disposition"] = "filename=\"" ~ charFile.baseName ~ "\"";
			serveStaticFile(charFile)(req, res);
		}

		static if(!deletedChar){
			MovedCharInfo deleteChar(string _account, string _char) @trusted{
				import std.file : exists, isFile, rename, mkdirRecurse;
				import std.path : buildPath, baseName;

				immutable charFile = getCharPath(_account, _char, deletedChar);
				enforceHTTP(charFile.exists && charFile.isFile, HTTPStatus.notFound,
					"Character '"~_char~"' not found");

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
					import sql: preparedStatement;
					auto conn = api.mysqlConnPool.lockConnection();
					conn.preparedStatement(query.get!string,
						"ACCOUNT", _account,
						"CHAR", _char,
						).exec();
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
				//import sql: replacePlaceholders, SqlPlaceholder;

				immutable charFile = getCharPath(_account, _char, deletedChar);
				enforceHTTP(charFile.exists && charFile.isFile, HTTPStatus.notFound,
					"Character '"~_char~"' not found");

				immutable accountVault = getVaultPath(_account, false);
				immutable newName = _char.matchFirst(ctRegex!`^(.+?)-\d+$`)[1];

				immutable target = buildPath(accountVault, newName~".bic");
				enforceHTTP(!target.exists, HTTPStatus.conflict, "An active character has the same name.");


				auto queries = api.cfg["sql_queries"]["on_activate"].get!(Json[]);
				foreach(ref query ; queries){
					import sql: preparedStatement;
					auto conn = api.mysqlConnPool.lockConnection();
					conn.preparedStatement(query.get!string,
						"ACCOUNT", _account,
						"CHAR", _char,
						).exec();
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
			import std.file : exists, isFile, readText;

			Metadata metadata;

			immutable charPath = getCharPath(_account, _char, deletedChar);
			enforceHTTP(charPath.exists && charPath.isFile, HTTPStatus.notFound,
					"Character '"~_char~"' not found");

			immutable charMetaPath = charPath~".meta";
			if(charMetaPath.exists){
				metadata = charMetaPath
					.readText
					.deserializeJson!Metadata;
			}

			return metadata;
		}

		void meta(string _account, string _char, Metadata metadata){
			import std.file : exists, isFile;

			immutable charPath = getCharPath(_account, _char, deletedChar);
			enforceHTTP(charPath.exists && charPath.isFile, HTTPStatus.notFound,
					"Character '"~_char~"' not found");

			immutable charMetaPath = charPath~".meta";
			charMetaPath.writeFile(cast(immutable ubyte[])metadata.serializeToJsonString);
		}

	}


private:
	Api api;


	Character getChar(in string account, in string bicName, bool deleted){
		import std.file : DirEntry, exists, isFile;

		immutable path = getCharPath(account, bicName, deleted);
		enforceHTTP(path.exists && path.isFile, HTTPStatus.notFound, "Character '"~bicName~"' not found");
		return Character(account, DirEntry(path));
	}

	string getCharPath(in string accountName, in string bicFile, bool deleted) const{
		import std.path : buildNormalizedPath, baseName;
		enforceHTTP(accountName.baseName == accountName, HTTPStatus.badRequest, "account name should not be a path");
		enforceHTTP(bicFile.baseName == bicFile, HTTPStatus.badRequest, "bic file name should not be a path");

		return buildNormalizedPath(getVaultPath(accountName, deleted), bicFile~".bic");
	}

	string getVaultPath(in string accountName, bool deleted) const{
		import std.path : buildNormalizedPath, baseName, isAbsolute;
		enforceHTTP(accountName.baseName == accountName, HTTPStatus.badRequest, "account name should not be a path");

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