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
			import sql: preparedStatement;

			string accountToCheck;
			if(user.isAdmin)
				accountToCheck = user.account;
			else
				accountToCheck = _account;

			enforceHTTP(api.passwordAuth(accountToCheck, oldPassword), HTTPStatus.conflict,
				"Old password is incorrect");

			auto setPasswdQuery = api.cfg["sql_queries"]["set_password"].get!(Json[]);
			foreach(ref query ; setPasswdQuery){

				auto prepared = api.mysqlConnection.preparedStatement(query.get!string,
					"ACCOUNT", _account,
					"NEW_PASSWORD", newPassword,
					);

				enforceHTTP(prepared.exec(), HTTPStatus.notFound,
					"Could not set password (probably account not found)");
			}
		}

		Token[] tokenList(in string _account) @trusted{
			import sql: preparedStatement;
			auto prepared = api.mysqlConnection.preparedStatement("
				SELECT `id`, `name`, `type`, `last_used`
				FROM `api_tokens` WHERE `account_name`=$ACCOUNT",
				"ACCOUNT", _account,
				);

			Token[] ret;

			auto res = prepared.query();
			foreach(ref row ; res){
				ret ~= Token(
					row[res.colNameIndicies["id"]].get!size_t,
					row[res.colNameIndicies["name"]].get!string,
					row[res.colNameIndicies["type"]].get!string.to!(Token.Type),
					row[res.colNameIndicies["last_used"]].get!DateTime);
			}
			return ret;
		}

		Token newToken(in string _account, in string tokenName, Token.Type tokenType) @trusted{
			import sql: preparedStatement;
			auto prepared = api.mysqlConnection.preparedStatement("
				INSERT INTO `api_tokens`
				(`account_name`, `name`, `type`, `token`)
				VALUES ($ACCOUNT, $TOKENNAME, $TYPE, SUBSTRING(MD5(RAND()), -32))",
				"ACCOUNT", _account,
				"TOKENNAME", tokenName,
				"TYPE", tokenType,
				);
			enforceHTTP(prepared.exec(), HTTPStatus.conflict, "Couldn't insert token");

			return getToken(_account, api.mysqlConnection.lastInsertID);
		}

		Token getToken(string _account, size_t _tokenId) @trusted{

			import sql: preparedStatement;
			auto prepared = api.mysqlConnection.preparedStatement("
				SELECT `id`, `name`, `type`, `last_used`
				FROM `api_tokens` WHERE `account_name`=$ACCOUNT AND `id`=$TOKENID",
				"ACCOUNT", _account,
				"TOKENID", _tokenId,
				);

			auto res = prepared.query();

			enforceHTTP(!res.empty, HTTPStatus.notFound,
				"Could not retrieve token ID=" ~ _tokenId.to!string ~ " on account '" ~ _account ~ "'");

			return Token(
				res.front[res.colNameIndicies["id"]].get!size_t,
				res.front[res.colNameIndicies["name"]].get!string,
				res.front[res.colNameIndicies["type"]].get!string.to!(Token.Type),
				res.front[res.colNameIndicies["last_used"]].get!DateTime);
		}

		void deleteToken(in string _account, size_t _tokenId) @trusted{
			import sql: preparedStatement;
			auto prepared = api.mysqlConnection.preparedStatement("
				DELETE FROM `api_tokens`
				WHERE `account_name`=$ACCOUNT AND `id`=$TOKENID",
				"ACCOUNT", _account,
				"TOKENID", _tokenId,
				);
			enforceHTTP(prepared.exec(), HTTPStatus.notFound,
				"Could not delete token ID=" ~ _tokenId.to!string ~ " on account '" ~ _account ~ "'");
		}

	}

	@noRoute
	UserInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res) @safe{
		return api.authenticate(req, res);
	}


private:
	Api api;

}
