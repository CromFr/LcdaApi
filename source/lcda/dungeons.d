module lcda.dungeons;

import std.traits: EnumMembers;
import std.path: buildPath;
import std.conv: to;

import utils: buildPathCI;
import nwn.fastgff: GffList;
import nwn.types;
import resourcemanager;
import mysql;


struct Dungeon{
	string name;
	string areaName;
	int diffMax = 0;

package:
	string chestVar;//VARNAME for a journalNODROP var, or DBNAME.VARNAME for a campaign var
	string area;//internal
	string diffName = null;//internal

}
Dungeon[] dungeonList;


private struct DungeonDef{
	string name;
	string area;
	string chestVar;
}


string diffPrefix(uint i){
	import std.conv: to;
	return i==0? null : "d"~i.to!string~"_";
}

void initDungeonInfo(){
	import resourcemanager;
	import config;
	import vibe.data.json;
	import nwn.fastgff;
	import nwn.tlk;
	import lcda.compat;

	const strref = ResourceManager.get!StrRefResolver("resolver");

	auto cfg = ResourceManager.get!Config("cfg");
	immutable modulePath = cfg["paths"]["module"].to!string;


	foreach(d ; cfg["dungeons"]["list"].get!(Json[])){
		Dungeon dungeon;
		dungeon.name = d["name"].get!string;
		dungeon.chestVar = d["chestVar"].get!string;
		dungeon.area = d["area"].get!string;

		auto areaARE = new FastGff(buildPathCI(modulePath, dungeon.area~".are"));
		dungeon.areaName = areaARE["Name"].get!GffLocString.resolve(strref);

		auto areaGIT = new FastGff(buildPathCI(modulePath, dungeon.area~".git"));
		auto varTable = "VarTable" in areaGIT.root;
		if(!varTable.isNull){
			foreach(i, varNode ; varTable.get.get!GffList){
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


import api.apidef: Character;
Character.DungeonStatus[] getDungeonStatus(in string accountName, in string charName, ref GffList journalVarTable){
	import std.typecons: Nullable;
	import resourcemanager;
	import config;
	import nwn.fastgff;
	import lcda.compat;


	version(profile){
		import std.datetime.stopwatch: StopWatch;
		StopWatch swSqlDB, swJournal;
	}

	version(profile){
		swSqlDB.reset();
		swJournal.reset();
	}

	Nullable!(const GffField) findJournalVar(string varName){
		foreach(i, v ; journalVarTable){
			if(v["Name"].get!GffString == varName){
				return Nullable!(const GffField)(v["Value"]);
			}
		}
		return Nullable!(const GffField)();
	}

	Nullable!(const(NWInt)) getVarValue(string var, string prefix){
		import std.string;

		auto idx = var.indexOf('.');
		if(idx != -1){
			//Campaign var
			version(profile){
				swSqlDB.start();
				scope(exit) swSqlDB.stop();
			}

			immutable dbName = var[0..idx].toLower;
			immutable varName = prefix ~ var[idx+1 .. $];

			auto mysqlConnPool = ResourceManager.getMut!MySQLPool("sql");
			auto res = mysqlConnPool
				.lockConnection()
				.query("
					SELECT `value` FROM `cam_" ~ dbName ~ "`
					WHERE `account_name`=?
					  AND `character_name`=?
					  AND `name`=?",
					accountName, charName, varName
				);
			scope(exit) res.close();
			if(!res.empty)
				return Nullable!(const(NWInt))(res.front[0].get!string.to!NWInt);
			return Nullable!(const(NWInt))(0);
		}
		else{
			//Journal var
			if(journalVarTable.length > 0){
				version(profile){
					swJournal.start();
					scope(exit) swJournal.stop();
				}

				immutable varName = prefix ~ var;
				auto jvar = findJournalVar(varName);
				if(!jvar.isNull){
					return Nullable!(const(NWInt))(jvar.get.get!GffInt);
				}
			}
			return Nullable!(const(NWInt))();
		}
	}

	Character.DungeonStatus[] ret;
	foreach(const ref dungeon ; dungeonList){
		Character.DungeonStatus status;
		status.name = dungeon.name;
		status.areaName = dungeon.areaName;
		status.diffMax = dungeon.diffMax;

		version(profile) swSqlDB.start();
		foreach(i ; 0 .. dungeon.diffMax + 1){
			if(dungeon.chestVar !is null){
				auto hasLootedChest = getVarValue(dungeon.chestVar, diffPrefix(i));
				status.lootedChests ~= hasLootedChest.isNull? false : (hasLootedChest.get == 1);
			}
		}
		version(profile) swSqlDB.stop();


		//Difficulty unlocked
		version(profile) swJournal.start();

		auto var = findJournalVar("qs#dungeon#" ~ dungeon.diffName);
		if(!var.isNull){
			status.unlockedDiff = var.get.get!GffString.to!int;
		}

		version(profile) swJournal.stop();

		ret ~= status;
	}

	version(profile){
		auto profDatabase = swSqlDB.peek.total!"msecs";
		auto profJournal = swJournal.peek.total!"msecs";

		import std.stdio: writeln;
		writeln("DUNJ ", accountName, ".", charName, ".bic: SqlDB=", profDatabase, "ms Journal=", profJournal, "ms");

	}
	return ret;

}