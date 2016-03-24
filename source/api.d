import vibe.d;
import std.typecons;

import nwn2.character;

interface RestAPI{

	alias CharList = Tuple!(Character[],"active",Character[],"deleted");

	@path("/:account/char/list")
	CharList getCharList(string _account);

	@path("/:account/char/:char")
	Character getCharInfo(string _account, string _char);

	@path("/:account/char/:char/delete")
	void postDeleteChar(string _account, string _char);

	void postLogin(string login, string password);
	void postLogout();
}



class Api : RestAPI{

	CharList getCharList(string _account){
		//enforceHTTP(authenticated, HTTPStatus.forbidden);
		//enforceHTTP(admin || _account==account, HTTPStatus.forbidden);

		//TODO: what if _account="../../secureThing" ?

		import std.file : DirEntry, dirEntries, SpanMode, exists, isDir;
		import std.path : buildNormalizedPath;
		import std.algorithm : sort;

		auto activeVault = DirEntry(buildNormalizedPath(
				"/home/crom/Documents/Neverwinter Nights 2/servervault/",//TODO: get from config
				_account));

		auto activeChars = activeVault
				.dirEntries("*.bic", SpanMode.shallow)
				.map!(a => new Character(a))
				.array
				.sort!"a.name<b.name"
				.array;



		auto deletedVaultPath = buildNormalizedPath(activeVault, "deleted");
		Character[] deletedChars = null;
		if(deletedVaultPath.exists && deletedVaultPath.isDir){
			deletedChars = DirEntry(deletedVaultPath)
					.dirEntries("*.bic", SpanMode.shallow)
					.map!(a => new Character(a))
					.array
					.sort!"a.name<b.name"
					.array;
		}

		return CharList(activeChars, deletedChars);
	}
	Character getCharInfo(string _account, string _char){
		enforceHTTP(authenticated, HTTPStatus.forbidden);
		enforceHTTP(admin || _account==account, HTTPStatus.forbidden);

		import std.file : DirEntry;
		import std.path : buildNormalizedPath;

		return new Character(DirEntry(buildNormalizedPath(
				"/home/crom/Documents/Neverwinter Nights 2/servervault/",//TODO: get from config
				_account,
				_char~".bic"
				)));

	}
	void postDeleteChar(string _account, string _char){}
	void postLogin(string login, string password){
		import mysql;
		import nwn2.resman;
		import app : ConnectionWrap;
		auto conn = ResMan.get!ConnectionWrap("sql");

		//TODO: move query to settings?
		//TODO: Check if fields are correctly escaped
		bool credsOK;
		conn.execute("SELECT (`password`=SHA(?)) FROM `account` WHERE `name`=?", password, login, (MySQLRow row){
			credsOK = row[0].get!int == 1;
		});

		enforceHTTP(credsOK, HTTPStatus.forbidden);

		authenticated = true;
		account = login;
	}
	void postLogout(){
		terminateSession();
	}

private:
	SessionVar!(bool, "authenticated") authenticated;
	SessionVar!(bool, "admin") admin;
	SessionVar!(string, "account") account;

}