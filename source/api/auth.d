module api.auth;

import vibe.d;


import api.apidef;
import api.api;



/// Web pages, CORS restricted. THIS NOT A REST INTERFACE
class Authenticator{

	this(Api api){
		this.api = api;
	}

	/// Login page
	void getLogin(scope HTTPServerRequest req, scope HTTPServerResponse res){
		render!("login.dt", req)(res);
	}

	/// Login action
	void postLogin(string account, string password, scope HTTPServerRequest req, scope HTTPServerResponse res){
		enforceHTTP(api.passwordAuth(account, password), HTTPStatus.unauthorized, "Bad user / password");

		this.account = account;

		auto redir = req.query.get("redirect", "/user");
		redirect(redir);
	}

	/// Stops the session
	void postLogout(scope HTTPServerRequest req, scope HTTPServerResponse res){
		res.terminateSession();
	}


	void getGenToken(scope HTTPServerRequest req, scope HTTPServerResponse res,
		string tokenName, Token.Type tokenType = Token.Type.restricted){
		render!("gentoken.dt", req, tokenName, tokenType)(res);
	}

	void postGenToken(scope HTTPServerRequest req, scope HTTPServerResponse res,
		string account, string password, string tokenName, Token.Type tokenType = Token.Type.restricted, string redir = "/user"
		){
		enforceHTTP(api.passwordAuth(account, password), HTTPStatus.unauthorized, "Bad user / password");

		auto token = api.accountApi.newToken(account, tokenName, tokenType);

		redir ~= (redir.indexOf('?') >= 0? "&" : "?") ~ "token="~urlEncode(token.value);

		redirect(redir);
	}

	SessionVar!(string, "account") account;

private:
	Api api;


}
