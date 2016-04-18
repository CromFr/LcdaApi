module api.account;

import vibe.d;
debug import std.stdio : writeln;

import api.api;

class AccountApi{
	this(Api api){
		this.api = api;
	}

	@path("/exists")
	Json getExists(string _account){
		import std.path : buildPath, exists, isDir;
		immutable accountPath = buildPath(
			api.cfg.paths.servervault.to!string,
			_account);

		return Json(accountPath.exists && accountPath.isDir);
	}

	@path("/password")
	void postPassword(string _account, string oldPassword, string newPassword){
		enforceHTTP(api.authenticated, HTTPStatus.unauthorized);
		enforceHTTP(api.admin || _account==api.account, HTTPStatus.forbidden);

		import sql: replacePlaceholders, Placeholder, MySQLRow;

		string accountToCheck;
		if(api.admin)
			accountToCheck = api.account;
		else
			accountToCheck = _account;

		immutable loginQuery = api.cfg.sql_queries.login.to!string
			.replacePlaceholders(
				Placeholder!string("ACCOUNT", accountToCheck),
				Placeholder!string("PASSWORD", oldPassword)
			);

		bool credsOK = false;
		api.mysqlConnection.execute(loginQuery, (MySQLRow row){
			credsOK = row.success.get!int == 1;
		});
		enforceHTTP(credsOK, HTTPStatus.conflict, "Old password is incorrect");


		immutable setPasswdQuery = api.cfg.sql_queries.set_password.to!string
			.replacePlaceholders(
				Placeholder!string("ACCOUNT", _account),
				Placeholder!string("NEW_PASSWORD", newPassword)
			);
		api.mysqlConnection.execute(setPasswdQuery);

		enforceHTTP(false, HTTPStatus.ok);
	}



private:
	Api api;

}