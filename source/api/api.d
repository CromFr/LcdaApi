module api.api;

import vibe.d;
import vibe.web.auth;
debug import std.stdio : writeln;
import mysql : MySQLPool;

import lcda.character;
import config;

import api.apidef;




class Api : IApi{
	import api.vault : Vault;
	import api.account : AccountApi;

	this(){
		import resourcemanager : ResourceManager;
		cfg = ResourceManager.get!Config("cfg");
		mysqlConnPool = ResourceManager.getMut!MySQLPool("sql");

		vaultApi = new Vault!false(this);
		backupVaultApi = new Vault!true(this);
		accountApi = new AccountApi(this);
	}

	override{
		ApiInfo apiInfo(){
			immutable apiUrl = cfg["server"]["api_url"].to!string;
			return ApiInfo(
				"LcdaApi",
				apiUrl,
				__TIMESTAMP__,
				"https://github.com/CromFr/LcdaApi",
				"https://github.com/CromFr/LcdaApi/blob/master/source/api/apidef.d",
				apiUrl ~ (apiUrl[$-1] == '/'? null : "/") ~ "client.js",
				);
		}

		IVault!false vault(){
			return vaultApi;
		}
		IVault!true backupVault(){
			return backupVaultApi;
		}
		IAccount account(){
			return accountApi;
		}

		UserInfo user(scope UserInfo user) @safe{
			return user;
		}


		UserInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res) @trusted{
			import sql: preparedStatement, exec;
			auto conn = mysqlConnPool.lockConnection();

			UserInfo ret;

			import vibe.http.auth.basic_auth: checkBasicAuth;
			if(checkBasicAuth(req, (account, password){
					if(passwordAuth(account, password)){
						ret.account = account;
						return true;
					}
					return false;
				})){
				//Nothing to do
			}
			else if(req.session){
				//Cookie auth
				ret.account = req.session.get!string("account", null);
			}
			else{
				//Token auth

				auto token = "PRIVATE-TOKEN" in req.headers;
				if(token is null)
					token = "private-token" in req.query;

				if(token !is null){
					auto prep = conn.preparedStatement("
						SELECT `id`, `account_name`, `name`, `type`, `last_used`
						FROM `api_tokens`
						WHERE `token`=$TOKEN",
						"TOKEN", *token,
						);
					auto result = prep.query();

					enforceHTTP(!result.empty, HTTPStatus.notFound, "No matching token found");

					ret.token = Token(
						result.front[result.colNameIndicies["id"]].get!size_t,
						result.front[result.colNameIndicies["name"]].get!string,
						result.front[result.colNameIndicies["type"]].get!string.to!(Token.Type),
						result.front[result.colNameIndicies["last_used"]].get!DateTime,
						);
					ret.account = result.front[result.colNameIndicies["account_name"]].get!string;
					result.close();

					//Update last used date
					conn.exec("UPDATE `api_tokens` SET `last_used`=NOW() WHERE `id`=" ~ ret.token.id.to!string);
				}
			}

			// GetUser additional info (admin state)
			if(ret.account !is null){
				auto prep = conn.preparedStatement("
					SELECT admin FROM `account` WHERE `name`=$ACCOUNT",
					"ACCOUNT", ret.account,
					);
				auto result = prep.query();
				scope(exit) result.close();
				ret.isAdmin = result.front[result.colNameIndicies["admin"]].get!int > 0;
			}

			//debug if(ret.account !is null){
			//	logInfo("authenticated user: %s%s",
			//		ret.account, ret.isAdmin? " (admin)" : "");
			//}
			return ret;

		}
	}

package:
	immutable Config cfg;
	MySQLPool mysqlConnPool;

	Vault!false vaultApi;
	Vault!true backupVaultApi;
	AccountApi accountApi;

	bool passwordAuth(string account, string password) @trusted{
		import sql: preparedStatement;
		auto conn = mysqlConnPool.lockConnection();

		auto prep = conn.preparedStatement(cfg["sql_queries"]["login"].get!string,
			"ACCOUNT", account,
			"PASSWORD", password,
			);
		auto result = prep.query();
		scope(exit) result.close();

		return !result.empty && result.front[result.colNameIndicies["success"]] == 1;
	}


}
