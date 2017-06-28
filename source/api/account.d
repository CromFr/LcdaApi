module api.account;

import vibe.d;
debug import std.stdio : writeln;

import api.api;

class AccountApi{
	this(Api api){
		this.api = api;
	}

	@path("/exists")
	Json getExists(string _account, HTTPServerRequest req){
		auto auth = api.authenticate(req);
		enforceHTTP(auth.authenticated, HTTPStatus.unauthorized);
		enforceHTTP(auth.admin || _account==auth.account, HTTPStatus.forbidden);

		import std.path : buildPath, exists, isDir;
		immutable accountPath = buildPath(
			api.cfg["paths"]["servervault"].to!string,
			_account);

		return Json(accountPath.exists && accountPath.isDir);
	}

	@path("/password")
	void postPassword(string _account, string oldPassword, string newPassword, HTTPServerRequest req){
		auto auth = api.authenticate(req);
		enforceHTTP(auth.authenticated, HTTPStatus.unauthorized);
		enforceHTTP(auth.admin || _account==auth.account, HTTPStatus.forbidden);

		import sql: replacePlaceholders, SqlPlaceholder, MySQLRow;

		string accountToCheck;
		if(auth.admin)
			accountToCheck = auth.account;
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

		enforceHTTP(false, HTTPStatus.ok);
	}



private:
	Api api;

}