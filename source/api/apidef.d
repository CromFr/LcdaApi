module api.apidef;
import vibe.d;
import vibe.web.auth;


private auto getReq(HTTPServerRequest req, HTTPServerResponse res) @safe {
	return req;
}
private auto getRes(HTTPServerRequest req, HTTPServerResponse res) @safe {
	return res;
}

struct UserInfo{
	string account;
	bool isAdmin = false;
	bool isAccountAuthorized(string _account) @safe{
		return account == _account || isAdmin;
	}
	bool isVaultCharPublic(string _account, string _char) @safe{
		return isCharPublic!false(_account, _char);
	}
	bool isBackupVaultCharPublic(string _account, string _char) @safe{
		return isCharPublic!true(_account, _char);
	}

private:
	bool isCharPublic(bool backupVault)(in string _account, in string _char) @trusted{
		import resourcemanager: ResourceManager;
		import api.api: Api;
		auto api = ResourceManager.getMut!Api("api");
		static if(!backupVault)
			auto metadata = api.vault.meta(_account, _char);
		else
			auto metadata = api.backupVault.meta(_account, _char);
		return metadata.isPublic;
	}
}

string getAccount(HTTPServerRequest req, HTTPServerResponse res){return "yolo";}

/// REST Api root
@requiresAuth
interface IApi{

	/// Api info structure
	static struct ApiInfo{
		/// Name of the API endpoint
		string name;
		/// Build date in "www mmm dd hh:mm:ss yyyy" format
		string buildDate;

		string upstream;
		string reference;
	}

	/// Api "welcome page" containing basic info
	@path("/")
	@noAuth
	ApiInfo getApiInfo() @safe;

	@path("/vault/")
	@noAuth
	@property IVault!false vault() @safe;

	@path("/backupvault/")
	@noAuth
	@property IVault!true backupVault() @safe;

	@path("/account/")
	@noAuth
	@property IAccount account() @safe;


	@path("/user")
	@anyAuth
	UserInfo getUser(scope UserInfo user) @safe;


	@noRoute
	UserInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res) @safe;
}

@requiresAuth
@path("/:account/")
interface IVault(bool deletedChar){
	import lcda.character;

	static if(!deletedChar)
		private enum AuthIsCharPublic = Role.VaultCharPublic;
	else
		private enum AuthIsCharPublic = Role.BackupVaultCharPublic;

	@path("/")
	@method(HTTPMethod.GET)
	@auth(Role.AccountAuthorized)
	LightCharacter[] getCharList(string _account) @safe;

	@path("/:char")
	@method(HTTPMethod.GET)
	@auth(Role.AccountAuthorized | AuthIsCharPublic)
	Character charInfo(string _account, string _char) @safe;


	@path("/:char/download")
	@method(HTTPMethod.GET)
	@auth(Role.AccountAuthorized | AuthIsCharPublic)
	@before!getReq("req") @before!getRes("res")
	void download(string _account, string _char, HTTPServerRequest req, HTTPServerResponse res) @safe;


	static struct MovedCharInfo{
		string account;
		/// New character file name
		string bicFileName;
		/// True if the character has been moved to the backup vault
		bool isDisabled;

		@property string path(){
			return (isDisabled? "/backupvault/" : "/vault/") ~ account ~ "/"  ~ bicFileName;
		}
	}

	static if(deletedChar == false){
		///Moves the character to the backupvault
		/// The new file name will be oldName~"-"~index~".bic" with index starting from 0
		///Returns the new bic file name
		@path("/:char/delete")
		@method(HTTPMethod.POST)
		@auth(Role.AccountAuthorized)
		MovedCharInfo deleteChar(string _account, string _char) @safe;
	}
	else{
		@path("/:char/restore")
		@method(HTTPMethod.POST)
		@auth(Role.AccountAuthorized)
		MovedCharInfo restoreChar(string _account, string _char) @safe;
	}


	static struct Metadata{
	@optional:
		@name("public") bool isPublic = false;
	}

	@path("/:char/meta"){
		@method(HTTPMethod.GET)
		@auth(Role.AccountAuthorized | AuthIsCharPublic)
		Metadata meta(string _account, string _char) const @safe;

		@method(HTTPMethod.POST)
		@auth(Role.AccountAuthorized)
		void meta(string _account, string _char, Metadata metadata) @safe;
	}

	@noRoute
	UserInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res) @safe;
}

interface IAccount{
	@path("/:account")
	@method(HTTPMethod.GET)
	bool exists(string _account) @safe;


	@path("/password")
	@method(HTTPMethod.POST)
	void changePassword(string _account, string oldPassword, string newPassword, UserInfo user) @safe;


	/// Get the list of active tokens name
	@path("/:account/token")
	@method(HTTPMethod.GET)
	string[] tokenList(string _account) @safe;

	/// Generate new auth token
	/// Returns: The string
	@path("/:account/token")
	@method(HTTPMethod.POST)
	string newToken(string _account, string tokenName) @safe;

	/// Remove an existing token
	@path("/:account/token")
	@method(HTTPMethod.DELETE)
	void deleteToken(string _account, string tokenName) @safe;


	@noRoute
	UserInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res) @safe;
}