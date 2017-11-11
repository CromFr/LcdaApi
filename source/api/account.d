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
		bool exists(string _account){
			import std.path : buildPath, exists, isDir;
			immutable accountPath = buildPath(
				api.cfg["paths"]["servervault"].to!string,
				_account);

			// TODO: check using MySQL instead
			return accountPath.exists && accountPath.isDir;
		}

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

		Token[] tokenList(in string _account) @trusted{
			import sql: replacePlaceholders, SqlPlaceholder, MySQLRow;
			immutable query = "
				SELECT `id`, `name`, `type`, `last_used`
				FROM `api_tokens` WHERE `account_name`='$ACCOUNT'"
				.replacePlaceholders(
					SqlPlaceholder("ACCOUNT", _account)
				);

			Token[] ret;
			api.mysqlConnection.execute(query, (MySQLRow row){
				ret ~= Token(
					row.id.get!size_t,
					row.name.get!string,
					row.type.get!string.to!(Token.Type),
					row.last_used.get!DateTime);
			});
			return ret;
		}

		Token newToken(in string _account, in string tokenName, Token.Type tokenType) @trusted{
			import sql: replacePlaceholders, SqlPlaceholder, MySQLRow;
			immutable insertQuery = "
				INSERT INTO `api_tokens`
				(`account_name`, `name`, `type`, `token`)
				VALUES
				('$ACCOUNT', '$TOKENNAME', '$TYPE', SUBSTRING(MD5(RAND()), -32))"
				.replacePlaceholders(
					SqlPlaceholder("ACCOUNT", _account),
					SqlPlaceholder("TOKENNAME", tokenName),
					SqlPlaceholder("TYPE", tokenType),
				);
			bool bInserted = false;
			api.mysqlConnection.execute(insertQuery, (MySQLRow row){
				bInserted = true;
			});
			enforceHTTP(bInserted, HTTPStatus.conflict, "Couldn't insert token");

			return getToken(_account, api.mysqlConnection.insertID);
		}

		Token getToken(string _account, size_t _tokenId) @trusted{
			import sql: replacePlaceholders, SqlPlaceholder, MySQLRow;
			immutable query = "
				SELECT `id`, `name`, `type`, `last_used`
				FROM `api_tokens` WHERE `account_name`='$ACCOUNT' AND `id`=$TOKENID"
				.replacePlaceholders(
					SqlPlaceholder("ACCOUNT", _account),
					SqlPlaceholder("TOKENID", _tokenId),
				);

			bool found = false;
			Token ret;
			api.mysqlConnection.execute(query, (MySQLRow row){
				ret = Token(
					row.id.get!size_t,
					row.name.get!string,
					row.type.get!string.to!(Token.Type),
					row.last_used.get!DateTime);
				found = true;
			});

			enforceHTTP(found, HTTPStatus.notFound,
				"Could not retrieve token ID=" ~ _tokenId.to!string ~ " on account '" ~ _account ~ "'");
			return ret;
		}

		void deleteToken(in string _account, size_t _tokenId) @trusted{
			import sql: replacePlaceholders, SqlPlaceholder, MySQLRow;
			immutable getQuery = "DELETE FROM `api_tokens` WHERE `account_name`='$ACCOUNT' AND `id`='$TOKENID'"
				.replacePlaceholders(
					SqlPlaceholder("ACCOUNT", _account),
					SqlPlaceholder("TOKENID", _tokenId),
				);

			bool bDeleted = false;
			api.mysqlConnection.execute(getQuery, (MySQLRow row){
				bDeleted = true;
			});

			enforceHTTP(bDeleted, HTTPStatus.notFound, "Couldn't delete token");
		}

	}

	@noRoute
	UserInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res) @safe{
		return api.authenticate(req, res);
	}


private:
	Api api;

}
