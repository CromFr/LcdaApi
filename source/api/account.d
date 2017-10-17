module api.account;

import vibe.d;
import vibe.web.auth;
debug import std.stdio : writeln;

import api.api;
import api.apidef;

@requiresAuth
class AccountApi: IAccount{
	this(Api api){
		this.api = api;
	}

	override {
		@auth(Role.AccountAuthorized)
		bool exists(string _account){
			import std.path : buildPath, exists, isDir;
			immutable accountPath = buildPath(
				api.cfg["paths"]["servervault"].to!string,
				_account);

			// TODO: check using MySQL instead
			return accountPath.exists && accountPath.isDir;
		}

		@auth(Role.AccountAuthorized)
		void changePassword(string _account, string oldPassword, string newPassword, UserInfo user) @trusted{
			import sql: replacePlaceholders, SqlPlaceholder, MySQLRow;

			string accountToCheck;
			if(user.isAdmin)
				accountToCheck = user.account;
			else
				accountToCheck = _account;

			immutable loginQuery = api.cfg["sql_queries"]["login"].to!string
				.replacePlaceholders(
					SqlPlaceholder("ACCOUNT", accountToCheck),
					SqlPlaceholder("PASSWORD", oldPassword)
				);

			bool credsOK = false;
			api.mysqlConnection.execute(loginQuery, (MySQLRow row){
				credsOK = row.success.get!int == 1;
			});
			enforceHTTP(credsOK, HTTPStatus.conflict, "Old password is incorrect");


			auto setPasswdQuery = api.cfg["sql_queries"]["set_password"].get!(Json[]);
			foreach(ref query ; setPasswdQuery){
				api.mysqlConnection.execute(
					query.to!string.replacePlaceholders(
						SqlPlaceholder("ACCOUNT", _account),
						SqlPlaceholder("NEW_PASSWORD", newPassword)
					)
				);
			}
		}

		@auth(Role.AccountAuthorized)
		string[] tokenList(in string _account) @trusted{
			import sql: replacePlaceholders, SqlPlaceholder, MySQLRow;
			immutable query = "SELECT `name` FROM `api_tokens` WHERE `account_name`='$ACCOUNT'".to!string
				.replacePlaceholders(
					SqlPlaceholder("ACCOUNT", _account)
				);

			string[] ret;
			api.mysqlConnection.execute(query, (MySQLRow row){
				ret ~= row.name.get!string;
			});
			return ret;
		}

		@auth(Role.AccountAuthorized)
		string newToken(in string _account, in string tokenName) @trusted{
			import sql: replacePlaceholders, SqlPlaceholder, MySQLRow;
			immutable insertQuery = "
				INSERT INTO `api_tokens`
				(`account_name`, `name`, `token`)
				VALUES
				('$ACCOUNT', '$TOKENNAME', SUBSTRING(MD5(RAND()), -32))"
				.replacePlaceholders(
					SqlPlaceholder("ACCOUNT", _account),
					SqlPlaceholder("TOKENNAME", tokenName),
				);
			bool bInserted = false;
			api.mysqlConnection.execute(insertQuery, (MySQLRow row){
				bInserted = true;
			});
			enforceHTTP(bInserted, HTTPStatus.notAcceptable, "Couldn't insert token");

			immutable getQuery = "SELECT `token` FROM `api_tokens` WHERE `account_name`='$ACCOUNT' AND `name`='$TOKENNAME'"
				.replacePlaceholders(
					SqlPlaceholder("ACCOUNT", _account),
					SqlPlaceholder("TOKENNAME", tokenName),
				);

			string ret;
			api.mysqlConnection.execute(getQuery, (MySQLRow row){
				ret = row.name.get!string;
			});
			return ret;
		}

		@auth(Role.AccountAuthorized)
		void deleteToken(in string _account, in string tokenName) @trusted{
			import sql: replacePlaceholders, SqlPlaceholder, MySQLRow;
			immutable getQuery = "DELETE FROM `api_tokens` WHERE `account_name`='$ACCOUNT' AND `name`='$TOKENNAME'"
				.replacePlaceholders(
					SqlPlaceholder("ACCOUNT", _account),
					SqlPlaceholder("TOKENNAME", tokenName),
				);

			bool bDeleted = false;
			api.mysqlConnection.execute(getQuery, (MySQLRow row){
				bDeleted = true;
			});

			enforceHTTP(bDeleted, HTTPStatus.notAcceptable, "Couldn't delete token");
		}

	}

	@noRoute
	UserInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res) @safe{
		return api.authenticate(req, res);
	}


private:
	Api api;

}
