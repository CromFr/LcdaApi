module api.api;

import vibe.d;
debug import std.stdio : writeln;
import mysql : MySQLClient;

import nwn.character;
import config;


class Api{
	import vibe.web.common : PathAttribute;
	import api.character : CharApi;
	import api.account : AccountApi;

	this(){
		import resourcemanager : ResourceManager;
		cfg = ResourceManager.get!Config("cfg");
		mysqlConnection = ResourceManager.getMut!MySQLClient("sql").lockConnection();

		charApi = new CharApi!false(this);
		deletedCharApi = new CharApi!true(this);
		accountApi = new AccountApi(this);
	}

	@path("/:account/characters/")
	auto forwardCharApi(){
		return charApi;
	}
	@path("/:account/characters/deleted/")
	auto forwardDeletedCharApi(){
		return deletedCharApi;
	}

	@path("/:account/account/")
	auto forwardAccountApi(){
		return accountApi;
	}

	Json postLogin(string login, string password){
		import sql: replacePlaceholders, SqlPlaceholder, MySQLRow;

		immutable query = cfg["sql_queries"]["login"].to!string
			.replacePlaceholders(
				SqlPlaceholder("ACCOUNT", login),
				SqlPlaceholder("PASSWORD", password)
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


package:
	@("session"){
		SessionVar!(bool, "authenticated") authenticated;
		SessionVar!(bool, "admin") admin;
		SessionVar!(string, "account") account;
	}
	immutable Config cfg;
	MySQLClient.LockedConnection mysqlConnection;

private:
	CharApi!false charApi;
	CharApi!true deletedCharApi;
	AccountApi accountApi;


}