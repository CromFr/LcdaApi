module api.auth;

import vibe.d;


import api.apidef;
import api.api;

struct TranslationContext {
	import std.typetuple: TypeTuple;
	alias languages = TypeTuple!("en_US", "fr_FR");
	mixin translationModule!"localization";

	enum enforceExistingKeys = true;
}

/// Web pages, CORS restricted. THIS NOT A REST INTERFACE
@translationContext!TranslationContext
class Authenticator{

	this(Api api){
		this.api = api;
	}


	void getGenToken(scope HTTPServerRequest req, scope HTTPServerResponse res,
		string tokenName, Token.Type tokenType = Token.Type.restricted, string redir = "/user"){
		render!("gentoken.dt", req, tokenName, tokenType, redir)(res);
	}

	void postGenToken(scope HTTPServerRequest req, scope HTTPServerResponse res,
		string account, string password, string tokenName, Token.Type tokenType = Token.Type.restricted, string redir = "/user"
		){
		enforceHTTP(api.passwordAuth(account, password), HTTPStatus.unauthorized, "Bad user / password");

		auto token = api.accountApi.newToken(account, tokenName, tokenType);

		redir ~= (redir.indexOf('?') >= 0? "&" : "?") ~ "token="~urlEncode(token.value);

		redirect(redir);
	}

private:
	Api api;


}
