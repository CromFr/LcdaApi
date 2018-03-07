module lcda.dungeons;

import std.traits: EnumMembers;
import std.path: buildPath;

import utils: buildPathCI;
import nwn.fastgff: GffList;
import resourcemanager;


struct Dungeon{
	string name;
	string areaName;
	int diffMax = 0;

package:
	string chestVar;
	string bossKilledVar;//VARNAME for a journalNODROP var, or DBNAME.VARNAME for a campaign var
	string areaResref;//internal
	string diffName = null;//internal

}
Dungeon[] dungeonList;


void initDungeonInfo(){
	import resourcemanager;
	import config;
	import nwn.fastgff;
	import nwn.tlk;
	import lcda.compat;

	immutable strref = ResourceManager.get!StrRefResolver("resolver");

	auto cfg = ResourceManager.get!Config("cfg");
	immutable modulePath = cfg["paths"]["module"].to!string;


	foreach(d ; EnumMembers!Dungeons){
		Dungeon dungeon;
		dungeon.name = d.name;
		dungeon.bossKilledVar = d.bossKilledVar;
		dungeon.chestVar = d.chestVar;
		dungeon.areaResref = d.areaResref;

		auto areaARE = new FastGff(buildPathCI(modulePath, dungeon.areaResref~".are"));
		dungeon.areaName = areaARE["Name"].get!GffLocString.resolve(strref);

		auto areaGIT = new FastGff(buildPathCI(modulePath, dungeon.areaResref~".git"));
		auto varTable = "VarTable" in areaGIT.root;
		if(!varTable.isNull){
			foreach(i, GffStruct varNode ; varTable.get.get!GffList){
				switch(varNode["Name"].get!GffString){
					case "difficulty_name":
						dungeon.diffName = varNode["Value"].get!GffString;
						break;
					case "difficulty_max":
						dungeon.diffMax = varNode["Value"].get!GffInt;
						break;
					default:
						break;
				}
			}
		}

		areaARE = null;
		areaGIT = null;

		dungeonList ~= dungeon;
	}
}


struct DungeonStatus{
	string name;
	string areaName;
	int diffMax;

	bool[] lootedChests;
	bool[] killedBoss;
	int unlockedDiff = 0;
}

DungeonStatus[] getDungeonStatus(in string accountName, in string charName, ref GffList journalVarTable){
	import std.typecons: Nullable;
	import resourcemanager;
	import config;
	import nwn.fastgff;
	import nwn.biowaredb;
	import lcda.compat;


	version(profile){
		import std.datetime.stopwatch: StopWatch;
		StopWatch swDatabase, swJournal, swSQL;
	}

	version(profile){
		swDatabase.reset();
		swJournal.reset();
		swSQL.reset();
	}


	auto cfg = ResourceManager.get!Config("cfg");
	immutable pcid = accountName ~ charName;

	Nullable!(const(NWInt)) getVarValue(string var, string prefix){
		import std.string;

		auto idx = var.indexOf('.');
		if(idx != -1){
			//Campaign var
			version(profile){
				swDatabase.start();
				scope(exit) swDatabase.stop();
			}

			immutable dbName = var[0..idx].toLower;
			immutable varName = prefix ~ var[idx+1 .. $];

			BiowareDB db;
			try db = ResourceManager.getMut!BiowareDB(dbName);
			catch(ResourceException e){
				db = new BiowareDB(buildPath(cfg["paths"]["database"].to!string, dbName));
				ResourceManager.store(dbName, db);
			}

			return db.getVariableValue!NWInt(pcid, varName);
		}
		else{
			//Journal var
			if(journalVarTable.length > 0){
				version(profile){
					swJournal.start();
					scope(exit) swJournal.stop();
				}

				immutable varName = prefix ~ var;
				foreach(i, GffStruct v ; journalVarTable){
					if(v["Name"].get!GffString == varName){
						return Nullable!(const(NWInt))(v["Value"].get!GffInt);
					}
				}
			}
			return Nullable!(const(NWInt))();
		}
	}

	import sql: preparedStatement, MySQLPool, prepare;
	static MySQLPool connPool;
	if(connPool is null)
		connPool = ResourceManager.getMut!MySQLPool("sql");
	auto conn = connPool.lockConnection();
	auto prep = conn.prepare("
		SELECT difficulty
		FROM score_dungeons
		WHERE account_name=? AND character_name=? AND dungeon=?
		ORDER BY difficulty DESC LIMIT 1");

	DungeonStatus[] ret;
	foreach(const ref dungeon ; dungeonList){
		DungeonStatus status;
		status.name = dungeon.name;
		status.areaName = dungeon.areaName;
		status.diffMax = dungeon.diffMax;

		foreach(i ; 0 .. dungeon.diffMax + 1){
			if(dungeon.chestVar !is null){
				auto hasLootedChest = getVarValue(dungeon.chestVar, diffPrefix(i));
				status.lootedChests ~= hasLootedChest.isNull? false : (hasLootedChest.get == 1);
			}

			auto hasKilledBoss = getVarValue(dungeon.bossKilledVar, diffPrefix(i));
			status.killedBoss ~= !hasKilledBoss.isNull;

		}


		//Difficulty unlocked
		version(profile) swSQL.start();

		prep.setArgs(accountName, charName, dungeon.diffName);
		auto result = prep.query();
		scope(exit) result.close();

		if(!result.empty)
			status.unlockedDiff = result.front[result.colNameIndicies["difficulty"]].get!int;

		version(profile) swSQL.stop();

		ret ~= status;
	}

	version(profile){
		auto profDatabase = swDatabase.peek.total!"msecs";
		auto profJournal = swJournal.peek.total!"msecs";
		auto profSQL = swSQL.peek.total!"msecs";

		import std.stdio: writeln;
		writeln("DUNJ ", accountName, ".", charName, ".bic: Database=", profDatabase, "ms Journal=", profJournal, "ms SQL=", profSQL, "ms");

	}
	return ret;

}