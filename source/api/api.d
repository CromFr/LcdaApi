module api.api;

import vibe.d;
debug import std.stdio : writeln;
import mysql : MySQLClient;

import nwn2.character;
import config;


@path("/api")
class Api{
	import vibe.web.common : PathAttribute;
	import api.character : CharApi;
	import api.account : AccountApi;

	this(){
		import resourcemanager : ResourceManager;
		cfg = ResourceManager.get!Config("cfg");
		mysqlConnection = ResourceManager.getMut!MySQLClient("sql").lockConnection();

		charApi = new CharApi(this);
		accountApi = new AccountApi(this);
	}

	@path("/:account/characters/")
	auto forwardCharApi(){
		return charApi;
	}

	@path("/:account/account/")
	auto forwardAccountApi(){
		return accountApi;
	}

	Json postLogin(string login, string password){
		import sql: replacePlaceholders, Placeholder, MySQLRow;

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


package:
	@("session"){
		SessionVar!(bool, "authenticated") authenticated;
		SessionVar!(bool, "admin") admin;
		SessionVar!(string, "account") account;
	}
	immutable Config cfg;
	MySQLClient.LockedConnection mysqlConnection;

private:
	CharApi charApi;
	AccountApi accountApi;


}