/// Public REST API Documentation
module api.apidef;

import vibe.d;
import vibe.web.auth;

debug(NoAuth){
	debug static assert(1);
	else static assert(0, "version NoAuth cannot be used with release builds");
}


auto getReq(HTTPServerRequest req, HTTPServerResponse res) @safe {
	return req;
}
auto getRes(HTTPServerRequest req, HTTPServerResponse res) @safe {
	return res;
}

/// User information structure
struct UserInfo{
	import std.typecons: Nullable;

	/// User account (Bioware account)
	string account;
	/// true if the user has admin privileges
	bool isAdmin = false;
	/// Used API token (null if password authenticated)
	Nullable!Token token;


	bool isAccountAuthorized(string _account) @safe{
		debug(NoAuth)
			return true;
		else
			return account == _account || isAdmin;
	}
	bool isVaultCharPublic(string _account, string _char) @safe{
		return isCharPublic!false(_account, _char);
	}
	bool isBackupVaultCharPublic(string _account, string _char) @safe{
		return isCharPublic!true(_account, _char);
	}
	bool isPasswordAuthenticated() @safe{
		return token.isNull;
	}
	bool isAdminToken() @safe{
		debug(NoAuth)
			return true;
		else
			return !token.isNull && token.get.type == Token.Type.admin;
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


struct Token{
	size_t id;
	string name;
	enum Type{
		admin = "admin", restricted = "restricted"
	}
	Type type;
	DateTime lastUsed;
}
struct TokenWithValue{
	Token info;
	alias info this;
	string value;
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


/// Type returned by IVault.meta
///
/// Character metadata (ex: is the character public)
struct Metadata{
@optional:
	bool isPublic = false;
	string subTitle = null;
	string notes = null;
}

/// Type returned by IVault.character
struct Character{
	/// Character first and last name
	string name;

	/// Current level
	int lvl;
	/// Class info
	static struct Class{
		@ignore size_t id;
		string name; /// Class name
		int lvl; /// Levels in this class
		string icon; /// Class icon file name
	}
	/// Class list
	Class[] classes;

	/// Current XP
	ulong xp;
	/// Lower XP and upper XP cap for this level
	ulong[2] xpBounds;

	/// Feat information
	static struct Feat{
		@ignore size_t id;
		string name; /// feat name
		string category; /// feat category
		string icon; /// feat icon file name
		bool automatic = false; /// true if the feat has been acquired automatically with a class or race.
	}
	/// List of feats acquired by the character
	Feat[] feats;

	/// Skill information
	static struct Skill{
		@ignore size_t id;
		string name; /// Skill name
		string icon; /// Skill icon file name
		ubyte rank; /// Points spent in this skill
		size_t abilityIndex; /// Ability that gives a bonus in this skill
	}
	/// Skill list
	Skill[] skills;

	/// Level-up information
	static struct Level{
		size_t classIndex; /// Index in Character.classes
		size_t classLevel; /// Levels in this class after leveling up
		string ability; /// Ability bonus if any (every 4 levels)
		/// Skill levelup information
		static struct LevelingSkill{
			size_t skillIndex; /// Index in Character.skills
			uint value; /// Ranks in this skill after leveling up
			int valueDiff; /// Added / removed rank amount
		}
		LevelingSkill[] skills; /// Increased skills
		size_t[] featIndices; /// Index in Character.feats
	}
	/// Character build information (chosen feats / skills /... for each level)
	Level[] leveling;

	/// Sub-race name
	string race;

	/// Sub-race level adjustment
	ubyte raceECL;

	/// Alignment information
	static struct Alignment{
		string name; /// Resulting alignment name (e.g. "Lawful Good")
		int good_evil; /// Percent in the good / evil axis
		int law_chaos; /// Percent in the law / chaos axis
	}
	/// Character alignment
	Alignment alignment;

	/// God name
	string god;

	/// Ability information
	static struct Ability{
		string label; /// Ability name
		int value; /// Ability score
	}
	/// Character abilities. They are ordered Str, Dex, Con, Int, Wis, Cha
	Ability[] abilities;

	/// Quest entry
	static struct QuestEntry{
		string name;
		uint state;
		uint priority;
		string description;
	}
	/// Character journal / quest list
	QuestEntry[] journal;

	/// Dungeon state (unlocked / completed / ...)
	static struct DungeonStatus{
		string name; /// Dungeon name
		string areaName; /// Dungeon main area name
		int diffMax; /// Max difficulty available

		bool[] lootedChests; /// for each difficulty, true if the chest has been looted
		int unlockedDiff = 0; /// Unlocked difficulty
	}
	/// Dungeon list
	DungeonStatus[] dungeons;

	/// Character BIC file name
	string bicFileName;
}

/// Type returned by IVault.list
struct LightCharacter{
	string name; /// Character first and last name
	string race; /// Sub-race name
	int lvl; /// Current level
	Character.Class[] classes; /// Class list
	string bicFileName; /// Character BIC file name

	/// Current XP
	ulong xp;
	/// Lower XP and upper XP cap for this level
	ulong[2] xpBounds;

	Metadata metadata; /// Character metadata (public, description, ...)
}

/// REST Api for managing the player servervault characters.
/// Accessed with path prefix /vault/ or /backupvault/
@requiresAuth
interface IVault(bool deletedChar){
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

	/// Single item information
	static struct Item {
		string name; /// Item name (may contain NWN2 markup)
		uint type; /// Base item type (index in baseitems.2da)
		string icon; /// Icon file name
		string[] properties; /// Item magical properties
	}

	/// Get currently equipped items (except creature items)
	@path("/:account/:char/equipment")
	@method(HTTPMethod.GET)
	@auth(Role.AccountAuthorized | AuthIsCharPublic)
	Item[string] equipment(string _account, string _char) @safe;

	/// Get all items in the inventory
	@path("/:account/:char/inventory")
	@method(HTTPMethod.GET)
	@auth(Role.AccountAuthorized | AuthIsCharPublic)
	Item[] inventory(string _account, string _char) @safe;

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
	@auth(Role.AccountAuthorized)
	bool exists(string _account) @safe;


	/// Change the user account password
	///
	/// Require old account password, or the authenticated admin user current password
	@path("/:account/password")
	@method(HTTPMethod.POST)
	@auth(Role.AccountAuthorized & (Role.PasswordAuthenticated | Role.AdminToken))
	void changePassword(string _account, string oldPassword, string newPassword, UserInfo user) @safe;


	/// Get the list of active tokens name
	@path("/:account/tokens")
	@method(HTTPMethod.GET)
	@auth(Role.AccountAuthorized & (Role.PasswordAuthenticated | Role.AdminToken))
	Token[] tokenList(string _account) @safe;

	/// Generate new auth token
	/// Returns: the generated token random
	@noRoute
	@path("/:account/tokens")
	@method(HTTPMethod.POST)
	@auth(Role.AccountAuthorized & (Role.PasswordAuthenticated | Role.AdminToken))
	TokenWithValue newToken(string _account, string tokenName, Token.Type tokenType) @safe;

	/// Get info about a specific token
	@path("/:account/tokens/:tokenId")
	@method(HTTPMethod.GET)
	@auth(Role.AccountAuthorized & (Role.PasswordAuthenticated | Role.AdminToken))
	Token getToken(string _account, ulong _tokenId) @safe;

	/// Remove an existing token
	///
	/// TODO: allow to remove current token without an admin token
	@path("/:account/tokens/:tokenId")
	@method(HTTPMethod.DELETE)
	@auth(Role.AccountAuthorized & (Role.PasswordAuthenticated | Role.AdminToken))
	void deleteToken(string _account, ulong _tokenId) @safe;

	@noRoute
	UserInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res) @safe;
}