module api.api;

import vibe.d;
debug import std.stdio : writeln;
import mysql : MySQLClient;

import lcda.character;
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

	@path("/")
	auto getInfo(){
		return [
			"name": "lcdaapi",
			"buildDate": __TIMESTAMP__,
			"upstream": "https://github.com/CromFr/LcdaAccountManager",
		].serializeToJson;
	}

	@path("/:account/characters/")
	auto forwardCharApi(){
		return charApi;
	}
	@path("/:account/deletedchars/")
	auto forwardDeletedCharApi(){
		return deletedCharApi;
	}

	@path("/:account/account/")
	auto forwardAccountApi(){
		return accountApi;
	}

	Json postLogin(string login, string password, HTTPServerRequest req){
		import sql: replacePlaceholders, SqlPlaceholder, MySQLRow;

		immutable loginQuery = cfg["sql_queries"]["login"].to!string
			.replacePlaceholders(
				SqlPlaceholder("ACCOUNT", login),
				SqlPlaceholder("PASSWORD", password)
			);

		bool credsOK = false, isAdmin;
		mysqlConnection.execute(loginQuery, (MySQLRow row){
			credsOK = row.success.get!int == 1;
			isAdmin = row.admin.get!int == 1;
		});

		enforceHTTP(credsOK, HTTPStatus.unauthorized);

		authenticated = true;
		account = login;
		admin = isAdmin;

		string masterToken;
		if(auto mt = "master" in accountApi.getTokens(login, req))
			masterToken = mt.to!string;
		else{
			immutable insertQuery =
				"INSERT INTO `api_tokens`
				(`account_name`, `name`, `token`)
				VALUES
				('$ACCOUNT', 'master', SUBSTRING(MD5(RAND()), -32))"
				.replacePlaceholders(
					SqlPlaceholder("ACCOUNT", login),
				);

			mysqlConnection.execute(insertQuery);

			masterToken = accountApi.getTokens(login, req)["master"].to!string;
		}
		return ["session": getSession(), "token": Json(masterToken)].serializeToJson;
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
	immutable Config cfg;
	MySQLClient.LockedConnection mysqlConnection;

	struct AuthInfo{
		bool authenticated;
		bool admin;
		string account;
	}

	AuthInfo authenticate(HTTPServerRequest req){
		if(authenticated){
			//Cookie auth
			return AuthInfo(authenticated, admin, account);
		}
		//else if(req.username !is null && req.password !is null){
		//	// Basic auth
		//	import sql;
		//	immutable query = cfg["sql_queries"]["login"].to!string
		//		.replacePlaceholders(
		//			SqlPlaceholder("ACCOUNT", req.username),
		//			SqlPlaceholder("PASSWORD", req.password)
		//		);

		//	bool success = false, isAdmin;
		//	mysqlConnection.execute(query, (MySQLRow row){
		//		success = row.success.get!int == 1;
		//		isAdmin = row.admin.get!int == 1;
		//	});

		//	return AuthInfo(success, isAdmin, req.username);
		//}

		auto token = "PRIVATE-TOKEN" in req.headers;
		if(token is null)
			token = "private-token" in req.query;

		if(token){
			import sql;
			immutable query = cfg["sql_queries"]["check_token"].to!string
				.replacePlaceholders(
					SqlPlaceholder("TOKEN", *token)
				);

			auto res = AuthInfo(false, false, null);
			mysqlConnection.execute(query, (MySQLRow row){
				res.authenticated = true;
				res.admin = row.admin.get!int == 1;
				res.account = row.account.get!string;
			});
			return res;
		}
		return AuthInfo(false, false, null);
	}

private:
	@("session"){
		SessionVar!(bool, "authenticated") authenticated;
		SessionVar!(bool, "admin") admin;
		SessionVar!(string, "account") account;
	}
	CharApi!false charApi;
	CharApi!true deletedCharApi;
	AccountApi accountApi;


}