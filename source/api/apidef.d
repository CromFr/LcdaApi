/// Public REST API Documentation
module api.apidef;

import vibe.d;
import vibe.web.auth;


private auto getReq(HTTPServerRequest req, HTTPServerResponse res) @safe {
	return req;
}
private auto getRes(HTTPServerRequest req, HTTPServerResponse res) @safe {
	return res;
}

/// User information structure
struct UserInfo{
	import std.typecons: Nullable;

	/// User account (Bioware account)
	string account;
	/// true if the user has admin privileges
	bool isAdmin = false;
	/// Used API token name (null if password authenticated)
	Nullable!string tokenName;

	bool isAccountAuthorized(string _account) @safe{
		return account == _account || isAdmin;
	}
	bool isVaultCharPublic(string _account, string _char) @safe{
		return isCharPublic!false(_account, _char);
	}
	bool isBackupVaultCharPublic(string _account, string _char) @safe{
		return isCharPublic!true(_account, _char);
	}
	bool isPasswordAuthenticated() @safe{
		return tokenName.isNull;
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

/// REST Api root
@requiresAuth
interface IApi{

	/// Api info structure
	static struct ApiInfo{
		/// Name of the API endpoint
		string name;
		/// URL where the api is originally served (url used in the clientFile)
		string apiUrl;
		/// Build date in "www mmm dd hh:mm:ss yyyy" format
		string buildDate;
		/// Git repository URL for the source code
		string source;
		/// API documentation
		string documentation;
		/// Client JS file URL to connect to the API
		string clientFile;
	}

	/// Api "welcome page" containing basic info
	@path("/")
	@method(HTTPMethod.GET)
	@noAuth
	ApiInfo apiInfo() @safe;

	/// Forward to vault API. All calls to the forwarded API will use @path as prefix.
	@path("/vault/")
	@noAuth
	@property IVault!false vault() @safe;

	/// Forward to backup vault API. All calls to the forwarded API will use @path as prefix.
	@path("/backupvault/")
	@noAuth
	@property IVault!true backupVault() @safe;

	/// Forward to account API. All calls to the forwarded API will use @path as prefix.
	@path("/account/")
	@noAuth
	@property IAccount account() @safe;

	/// Get the current user information.
	///
	/// Users can be authenticated using the following methods:
	/// $(LI API token stored in request header `PRIVATE-TOKEN`)
	/// $(LI API token stored as URL parameter `private-token`)
	/// $(LI HTTPS basic auth with account name and password)
	/// $(LI Session cookie obtained via POST `/auth/login?account=...&password=...`)
	@path("/user")
	@method(HTTPMethod.GET)
	@anyAuth
	UserInfo user(scope UserInfo user) @safe;


	@noRoute
	UserInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res) @safe;
}

/// REST Api for managing the player servervault characters.
/// Accessed with path prefix /vault/ or /backupvault/
@requiresAuth
interface IVault(bool deletedChar){
	import lcda.character;

	static if(!deletedChar)
		private enum AuthIsCharPublic = Role.VaultCharPublic;
	else
		private enum AuthIsCharPublic = Role.BackupVaultCharPublic;

	/// Lists the characters owned by the player.
	///
	/// Character information is limited and not guaranteed to be up to date.
	@path("/:account/")
	@method(HTTPMethod.GET)
	@auth(Role.AccountAuthorized)
	LightCharacter[] list(string _account) @safe;

	/// Get all information about a single character
	@path("/:account/:char")
	@method(HTTPMethod.GET)
	@auth(Role.AccountAuthorized | AuthIsCharPublic)
	Character character(string _account, string _char) @safe;

	/// Download the character BIC file
	@path("/:account/:char/download")
	@method(HTTPMethod.GET)
	@auth(Role.AccountAuthorized | AuthIsCharPublic)
	@before!getReq("req") @before!getRes("res")
	void downloadChar(string _account, string _char, HTTPServerRequest req, HTTPServerResponse res) @safe;


	/// Information to keep track of a moved character
	static struct MovedCharInfo{
		this(string account, string bicFileName, bool isDisabled){
			this.account = account;
			this.bicFileName = bicFileName;
			this.isDisabled = isDisabled;
			path = (isDisabled? "/backupvault/" : "/vault/") ~ account ~ "/"  ~ bicFileName;
		}
		@disable this();

		/// Owner account
		string account;
		/// New character file name
		string bicFileName;
		/// True if the character has been moved to the backup vault
		bool isDisabled;
		/// New API path to the character
		string path;
	}

	static if(deletedChar == false){
		///Moves the character to the backupvault
		/// The new file name will be oldName~"-"~index~".bic" with index starting from 0
		@path("/:account/:char/delete")
		@method(HTTPMethod.POST)
		@auth(Role.AccountAuthorized)
		MovedCharInfo deleteChar(string _account, string _char) @safe;
	}
	else{
		/// Moves the character to the active Vault, where the character can be selected in nwn2
		@path("/:account/:char/restore")
		@method(HTTPMethod.POST)
		@auth(Role.AccountAuthorized)
		MovedCharInfo restoreChar(string _account, string _char) @safe;
	}

	/// Character metadata (ex: is the character public)
	static struct Metadata{
	@optional:
		bool isPublic = false;
		string subTitle = null;
		string notes = null;
	}

	@path("/:account/:char/meta"){
		/// Get character metadata
		@method(HTTPMethod.GET)
		@auth(Role.AccountAuthorized | AuthIsCharPublic)
		Metadata meta(string _account, string _char) const @safe;

		/// Set character metadata
		@method(HTTPMethod.POST)
		@auth(Role.AccountAuthorized)
		void meta(string _account, string _char, Metadata metadata) @safe;
	}

	@noRoute
	UserInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res) @safe;
}

/// REST Api for managing the player account.
/// Accessed with path prefix /account/
@requiresAuth
interface IAccount{
	/// Check if account is registered
	@path("/:account")
	@method(HTTPMethod.GET)
	@anyAuth
	bool exists(string _account) @safe;


	/// Change the user account password
	///
	/// Require old account password, or the authenticated admin user current password
	@path("/:account/password")
	@method(HTTPMethod.POST)
	@auth(Role.AccountAuthorized)
	void changePassword(string _account, string oldPassword, string newPassword, UserInfo user) @safe;


	static struct Token{
		size_t id;
		string name;
		enum Type{
			admin = "admin", restricted = "restricted"
		}
		Type type;
		DateTime lastUsed;
	}
	/// Get the list of active tokens name
	@path("/:account/tokens")
	@method(HTTPMethod.GET)
	@auth(Role.AccountAuthorized)
	Token[] tokenList(string _account) @safe;

	/// Generate new auth token
	/// Returns: the generated token
	@noRoute
	@path("/:account/tokens")
	@method(HTTPMethod.POST)
	@auth(Role.AccountAuthorized)
	Token newToken(string _account, string tokenName, Token.Type tokenType) @safe;

	/// Get info about a specific token
	@path("/:account/tokens/:tokenId")
	@method(HTTPMethod.GET)
	@auth(Role.AccountAuthorized & Role.PasswordAuthenticated)
	Token getToken(string _account, size_t _tokenId) @safe;

	/// Remove an existing token
	@path("/:account/tokens/:tokenId")
	@method(HTTPMethod.DELETE)
	@auth(Role.AccountAuthorized & Role.PasswordAuthenticated)
	void deleteToken(string _account, size_t _tokenId) @safe;


	@noRoute
	UserInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res) @safe;
}