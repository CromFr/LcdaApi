module api.api;

import vibe.d;
import vibe.web.auth;
debug import std.stdio : writeln;
import mysql : MySQLClient;

import lcda.character;
import config;

import api.apidef;




class Api : IApi{
	import api.vault : Vault;
	import api.account : AccountApi;

	this(){
		import resourcemanager : ResourceManager;
		cfg = ResourceManager.get!Config("cfg");
		mysqlConnection = ResourceManager.getMut!MySQLClient("sql").lockConnection();

		vaultApi = new Vault!false(this);
		backupVaultApi = new Vault!true(this);
		accountApi = new AccountApi(this);
	}

	override{
		ApiInfo getApiInfo(){
			return ApiInfo(
				"LcdaApi",
				__TIMESTAMP__,
				"https://github.com/CromFr/LcdaAccountManager",
				"https://github.com/CromFr/LcdaAccountManager/blob/master/source/api/apidef.d",
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

		UserInfo getUser(scope UserInfo user) @safe{
			return user;
		}


		UserInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res) @trusted{
			auto ret = UserInfo(null, false);

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
					import sql;
					immutable query = cfg["sql_queries"]["check_token"].to!string
						.replacePlaceholders(
							SqlPlaceholder("TOKEN", *token)
						);

					mysqlConnection.execute(query, (MySQLRow row){
						ret.account = row.account.get!string;
					});
				}
			}

			// GetUser additional info (admin state)
			if(ret.account !is null){
				import sql;
				immutable userInfoQuery = "SELECT * FROM `account` WHERE `name`='$ACCOUNT'"
					.replacePlaceholders(
						SqlPlaceholder("ACCOUNT", ret.account)
					);

				mysqlConnection.execute(userInfoQuery, (MySQLRow row){
					ret.isAdmin = row.admin.get!int == 1;
				});
			}

			if(ret.account !is null) logInfo("authenticated user: %s", ret);
			return ret;
		}
	}

package:
	immutable Config cfg;
	MySQLClient.LockedConnection mysqlConnection;

private:
	Vault!false vaultApi;
	Vault!true backupVaultApi;
	AccountApi accountApi;

	bool passwordAuth(string account, string password) @trusted{
		import sql: replacePlaceholders, SqlPlaceholder, MySQLRow;

		//Login check
		immutable loginQuery = cfg["sql_queries"]["login"].to!string
			.replacePlaceholders(
				SqlPlaceholder("ACCOUNT", account),
				SqlPlaceholder("PASSWORD", password)
			);

		bool credsOK = false;
		mysqlConnection.execute(loginQuery, (MySQLRow row){
			credsOK = row.success.get!int == 1;
		});

		return credsOK;
	}
}