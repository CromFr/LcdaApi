module lcda.dungeons;

import std.traits: EnumMembers;
import std.path: buildNormalizedPath;

import mysql : MySQLClient;
import nwn.fastgff: GffList;


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

		auto areaARE = new FastGff(buildNormalizedPath(modulePath, dungeon.areaResref~".are"));
		dungeon.areaName = areaARE["Name"].get!GffLocString.resolve(strref);

		auto areaGIT = new FastGff(buildNormalizedPath(modulePath, dungeon.areaResref~".git"));
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

DungeonStatus[] getDungeonStatus(in string accountName, in string charName, ref GffList journalVarTable, ref MySQLClient.LockedConnection mysqlConnection){
	import std.typecons: Nullable;
	import resourcemanager;
	import config;
	import nwn.fastgff;
	import nwn.biowaredb;
	import lcda.compat;

	auto cfg = ResourceManager.get!Config("cfg");
	immutable pcid = accountName ~ charName;

	Nullable!(const(NWInt)) getVarValue(string var, string prefix){
		import std.string;

		auto idx = var.indexOf('.');
		if(idx != -1){
			//Campaign var
			immutable dbName = var[0..idx].toLower;
			immutable varName = prefix ~ var[idx+1 .. $];

			BiowareDB db;
			try db = ResourceManager.getMut!BiowareDB(dbName);
			catch(ResourceException e){
				db = new BiowareDB(buildNormalizedPath(cfg["paths"]["database"].to!string, dbName));
				ResourceManager.store(dbName, db);
			}

			return db.getVariableValue!NWInt(pcid, varName);
		}
		else{
			//Journal var
			immutable varName = prefix ~ var;
			foreach(i, GffStruct v ; journalVarTable){
				if(v["Name"].get!GffString == varName){
					return Nullable!(const(NWInt))(v["Value"].get!GffInt);
				}
			}
			return Nullable!(const(NWInt))();
		}
	}


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
		import sql;
		immutable query =
			"SELECT difficulty FROM score_dungeons WHERE account_name='$ACCOUNT' AND character_name='$CHARACTER' AND dungeon='$DUNGEON'"
			.replacePlaceholders(
				SqlPlaceholder("ACCOUNT", accountName),
				SqlPlaceholder("CHARACTER", charName),
				SqlPlaceholder("DUNGEON", dungeon.diffName),
			);
		mysqlConnection.execute(query, (MySQLRow row){
			status.unlockedDiff = row.difficulty.get!int;
		});

		ret ~= status;
	}
	return ret;

}