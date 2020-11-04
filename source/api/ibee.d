module api.ibee;

import vibe.d;
import vibe.web.auth;
import sql;

import api.api;
import api.apidef;
import lcda.item;

@requiresAuth
class IbeeApi: IIbee {
	this(Api api){
		this.api = api;

		// Prepare statements
		auto conn = api.mysqlConnPool.lockConnection();

		prepGetBank = conn.prepare("
			SELECT `ibee_bank`
			FROM `account` WHERE `name`=?"
		);
		prepGetStash = conn.prepare("
			SELECT `item_name`, `item_type`, `item_iconname`, `item_stack`
			FROM `coffreibee` WHERE `active`=1 AND `account_name`=?"
		);
	}
	private{
		Prepared prepGetBank;
		Prepared prepGetStash;
	}
	override{
		UserInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res) @safe{
			return api.authenticate(req, res);
		}


		ulong bank(string _account) @trusted {
			auto conn = api.mysqlConnPool.lockConnection();

			auto result = conn.query(prepGetBank, _account);
			scope(exit) result.close();

			enforceHTTP(!result.empty, HTTPStatus.notFound,
				"Could not retrieve bank amount for account '" ~ _account ~ "'");

			return result.front[0].get!ulong;
		}

		Item[] stash(string _account) @trusted {
			auto conn = api.mysqlConnPool.lockConnection();

			auto result = conn.query(prepGetStash, _account);
			scope(exit) result.close();

			Item[] ret;
			foreach(ref row ; result){
				ret ~= Item(
					row[result.colNameIndicies["item_name"]].get!string.removeBracedText,
					row[result.colNameIndicies["item_stack"]].get!int.to!uint,
					row[result.colNameIndicies["item_type"]].get!int.to!uint,
					row[result.colNameIndicies["item_iconname"]].get!string,
					[],
				);
			}
			return ret;
		}
	}

private:
	Api api;
}