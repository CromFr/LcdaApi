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
			import std.path : buildPath;
			import std.file: exists, isDir;
			immutable accountPath = buildPath(
				api.cfg["paths"]["servervault"].to!string,
				_account);

			// TODO: check using MySQL instead
			return accountPath.exists && accountPath.isDir;
		}

		void changePassword(string _account, string oldPassword, string newPassword, UserInfo user) @trusted{
			import sql: preparedStatement;
			auto conn = api.mysqlConnPool.lockConnection();

			string accountToCheck;
			if(user.isAdmin)
				accountToCheck = user.account;
			else
				accountToCheck = _account;

			enforceHTTP(api.passwordAuth(accountToCheck, oldPassword), HTTPStatus.conflict,
				"Old password is incorrect");

			auto setPasswdQuery = api.cfg["sql_queries"]["set_password"].get!(Json[]);
			foreach(ref query ; setPasswdQuery){

				auto affectedRows = conn.preparedStatement(query.get!string,
					"ACCOUNT", _account,
					"NEW_PASSWORD", newPassword,
					).exec();

				enforceHTTP(affectedRows > 0, HTTPStatus.notFound,
					"Could not set password (probably account not found)");
			}
		}

		Token[] tokenList(in string _account) @trusted{
			Token[] ret;

			import sql: preparedStatement;
			auto conn = api.mysqlConnPool.lockConnection();
			auto prep = conn.preparedStatement("
				SELECT `id`, `name`, `type`, `last_used`
				FROM `api_tokens` WHERE `account_name`=$ACCOUNT",
				"ACCOUNT", _account,
				);
			auto result = prep.query();
			scope(exit) result.close();

			foreach(ref row ; result){
				ret ~= Token(
					row[result.colNameIndicies["id"]].get!size_t,
					row[result.colNameIndicies["name"]].get!string,
					row[result.colNameIndicies["type"]].get!string.to!(Token.Type),
					row[result.colNameIndicies["last_used"]].get!DateTime);
			}
			return ret;
		}

		TokenWithValue newToken(in string _account, in string tokenName, Token.Type tokenType) @trusted{
			import sql: preparedStatement;
			auto conn = api.mysqlConnPool.lockConnection();

			ulong tokenId;
			{
				auto affectedRows = conn.preparedStatement("
					INSERT INTO `api_tokens`
					(`account_name`, `name`, `type`, `token`)
					VALUES ($ACCOUNT, $TOKENNAME, $TYPE, SUBSTRING(MD5(RAND()), -32))",
					"ACCOUNT", _account,
					"TOKENNAME", tokenName,
					"TYPE", cast(string)tokenType,
					).exec();

				enforceHTTP(affectedRows, HTTPStatus.conflict, "Couldn't insert token");
				tokenId = conn.lastInsertID;
			}
			string tokenValue;
			{
				auto prep = conn.preparedStatement("
					SELECT `token`
					FROM `api_tokens` WHERE `account_name`=$ACCOUNT AND `id`=$TOKENID",
					"ACCOUNT", _account,
					"TOKENID", tokenId,
					);
				auto result = prep.query();
				scope(exit) result.close();

				enforceHTTP(!result.empty, HTTPStatus.notFound,
					"Could not retrieve token ID=" ~ tokenId.to!string ~ " on account '" ~ _account ~ "'");

				tokenValue = result.front[result.colNameIndicies["token"]].get!string;
			}

			return TokenWithValue(getToken(_account, tokenId), tokenValue);
		}

		Token getToken(string _account, ulong _tokenId) @trusted{

			import sql: preparedStatement;
			auto conn = api.mysqlConnPool.lockConnection();
			auto prep = conn.preparedStatement("
				SELECT `id`, `name`, `type`, `last_used`
				FROM `api_tokens` WHERE `account_name`=$ACCOUNT AND `id`=$TOKENID",
				"ACCOUNT", _account,
				"TOKENID", _tokenId,
				);
			auto result = prep.query();
			scope(exit) result.close();

			enforceHTTP(!result.empty, HTTPStatus.notFound,
				"Could not retrieve token ID=" ~ _tokenId.to!string ~ " on account '" ~ _account ~ "'");

			return Token(
				result.front[result.colNameIndicies["id"]].get!size_t,
				result.front[result.colNameIndicies["name"]].get!string,
				result.front[result.colNameIndicies["type"]].get!string.to!(Token.Type),
				result.front[result.colNameIndicies["last_used"]].get!DateTime);
		}

		void deleteToken(in string _account, ulong _tokenId) @trusted{
			import sql: preparedStatement;
			auto conn = api.mysqlConnPool.lockConnection();
			auto affectedRows = conn.preparedStatement("
				DELETE FROM `api_tokens`
				WHERE `account_name`=$ACCOUNT AND `id`=$TOKENID",
				"ACCOUNT", _account,
				"TOKENID", _tokenId,
				).exec();
			enforceHTTP(affectedRows > 0, HTTPStatus.notFound,
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
