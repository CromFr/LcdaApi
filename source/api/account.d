module api.account;

import vibe.d;
import vibe.web.auth;
debug import std.stdio : writeln;

import sql;
import api.api;
import api.apidef;

@requiresAuth
class AccountApi: IAccount{
	this(Api api){
		this.api = api;

		// Prepare statements
		auto conn = api.mysqlConnPool.lockConnection();

		foreach(ref query ; api.cfg["sql_queries"]["set_password"].get!(Json[])){
			prepSetPassword ~= conn.prepareCustom(query.get!string, ["ACCOUNT", "NEW_PASSWORD"]);
		}
		prepGetTokens = conn.prepare("
			SELECT `id`, `name`, `type`, `last_used`
			FROM `api_tokens` WHERE `account_name`=?");
		prepGetToken = conn.prepare("
			SELECT `id`, `name`, `type`, `last_used`
			FROM `api_tokens` WHERE `account_name`=? AND `id`=?");
		prepNewToken = conn.prepare("
			INSERT INTO `api_tokens`
			(`account_name`, `name`, `type`, `token`)
			VALUES (?, ?, ?, SUBSTRING(MD5(RAND()), -32))");
		prepGetTokenValue = conn.prepare("
			SELECT `token`
			FROM `api_tokens`
			WHERE `account_name`=? AND `id`=?");
		prepDeleteToken = conn.prepare("
			DELETE FROM `api_tokens`
			WHERE `account_name`=? AND `id`=?");

	}
	private{
		PreparedCustom[] prepSetPassword;
		Prepared prepGetTokens;
		Prepared prepGetToken;
		Prepared prepNewToken;
		Prepared prepGetTokenValue;
		Prepared prepDeleteToken;
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
			auto conn = api.mysqlConnPool.lockConnection();

			string accountToCheck;
			if(user.isAdmin)
				accountToCheck = user.account;
			else
				accountToCheck = _account;

			enforceHTTP(api.passwordAuth(accountToCheck, oldPassword), HTTPStatus.conflict,
				"Old password is incorrect");

			foreach(ref prep ; prepSetPassword){
				auto affectedRows = conn.exec(prep, _account, newPassword);

				enforceHTTP(affectedRows > 0, HTTPStatus.notFound,
					"Could not set password (probably account not found)");
			}
		}

		Token[] tokenList(in string _account) @trusted{
			auto conn = api.mysqlConnPool.lockConnection();

			auto result = conn.query(prepGetTokens, _account);
			scope(exit) result.close();

			Token[] ret;
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
			auto conn = api.mysqlConnPool.lockConnection();

			ulong tokenId;
			{
				auto affectedRows = conn.exec(prepNewToken, _account, tokenName, cast(string)tokenType);

				enforceHTTP(affectedRows, HTTPStatus.conflict, "Couldn't insert token");
				tokenId = conn.lastInsertID;
			}
			string tokenValue;
			{
				auto result = conn.query(prepGetTokenValue, _account, tokenId);
				scope(exit) result.close();

				enforceHTTP(!result.empty, HTTPStatus.notFound,
					"Could not retrieve token ID=" ~ tokenId.to!string ~ " on account '" ~ _account ~ "'");

				tokenValue = result.front[result.colNameIndicies["token"]].get!string;
			}

			return TokenWithValue(getToken(_account, tokenId), tokenValue);
		}

		Token getToken(string _account, ulong _tokenId) @trusted{
			auto conn = api.mysqlConnPool.lockConnection();

			auto result = conn.query(prepGetToken, _account, _tokenId);
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
			auto conn = api.mysqlConnPool.lockConnection();

			auto affectedRows = conn.exec(prepDeleteToken, _account, _tokenId);

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
