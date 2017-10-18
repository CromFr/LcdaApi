import vibe.d;






/// Web pages, CORS restricted
class Authenticator{

	/// Login page
	void getLogin(scope HTTPServerRequest req, scope HTTPServerResponse res){
		render!("login.dt")(res);
	}

	/// Login action
	void postLogin(string account, string password, scope HTTPServerRequest req, scope HTTPServerResponse res){

		this.account = account;

		auto redirectTarget = req.params.get("redirect", "/user");
		redirect(redirectTarget);
	}

	/// Start a session and give a cookie that can be used with the Api
	//void postLogout(scope HTTPServerRequest req, scope HTTPServerResponse res){
	//	sessionEnd();
	//}

	//void getSession(scope HTTPServerRequest req, scope HTTPServerResponse res);

	///// Create a new application token
	//void getCreateToken(string appName);

	SessionVar!(string, "account") account;
}
