module api.api;

import vibe.d;
import vibe.web.auth;
debug import std.stdio : writeln;
import mysql : Connection;

import lcda.character;
import config;

import api.apidef;




class Api : IApi{
	import api.vault : Vault;
	import api.account : AccountApi;

	this(){
		import resourcemanager : ResourceManager;
		cfg = ResourceManager.get!Config("cfg");
		mysqlConnection = ResourceManager.getMut!Connection("sql");

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
				"https://github.com/CromFr/LcdaAccountManager",
				"https://github.com/CromFr/LcdaAccountManager/blob/master/source/api/apidef.d",
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
					import sql: preparedStatement;
					auto prepared = mysqlConnection.preparedStatement(cfg["sql_queries"]["check_token"].get!string,
						"TOKEN", *token,
						);
					auto result = prepared.query();

					enforceHTTP(!result.empty, HTTPStatus.notFound,
						"No matching token found");
					ret.tokenName = result.front[result.colNameIndicies["token_name"]].get!string;
					ret.account = result.front[result.colNameIndicies["account"]].get!string;
				}
			}

			// GetUser additional info (admin state)
			if(ret.account !is null){
				import sql: preparedStatement;
				auto prepared = mysqlConnection.preparedStatement("
					SELECT isAdmin FROM `account` WHERE `name`=$ACCOUNT",
					"ACCOUNT", ret.account,
					);
				auto result = prepared.query();
				ret.isAdmin = result.front[result.colNameIndicies["isAdmin"]].get!int > 0;
			}

			debug if(ret.account !is null){
				logInfo("authenticated user: %s%s",
					ret.account, ret.isAdmin? " (admin)" : "");
			}
			return ret;

		}
	}

package:
	immutable Config cfg;
	Connection mysqlConnection;

	bool passwordAuth(string account, string password) @trusted{
		import sql: preparedStatement;
		auto prepared = mysqlConnection.preparedStatement(cfg["sql_queries"]["login"].get!string,
			"ACCOUNT", account,
			"PASSWORD", password,
			);

		auto res = prepared.query();

		return !res.empty && res.front[res.colNameIndicies["success"]].get!int == 1;
	}

private:
	Vault!false vaultApi;
	Vault!true backupVaultApi;
	AccountApi accountApi;

}
