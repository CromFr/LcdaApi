module nwn.dungeons;

import std.traits: EnumMembers;
import std.path: buildNormalizedPath;

import mysql : MySQLClient;
import nwn.gff: GffNode;


struct Dungeon{
	string name;
	string areaName;
	int diffMax = 1;

package:
	string chestVar;
	string bossKilledVar;//VARNAME for a journalNODROP var, or DBNAME.VARNAME for a campaign var
	string areaResref;//internal
	string diffName = null;//internal

}
Dungeon[] dungeonList;


void initDungeonInfo(){
	import nwn.lcdacompat;
	import nwn.gff;
	import resourcemanager;
	import config;

	auto cfg = ResourceManager.get!Config("cfg");
	immutable modulePath = cfg["paths"]["module"].to!string;


	foreach(d ; EnumMembers!Dungeons){
		Dungeon dungeon;
		dungeon.name = d.name;
		dungeon.bossKilledVar = d.bossKilledVar;
		dungeon.chestVar = d.chestVar;
		dungeon.areaResref = d.areaResref;

		auto areaARE = new Gff(buildNormalizedPath(modulePath, dungeon.areaResref~".are"));
		dungeon.areaName = areaARE["Name"].to!string;

		auto areaGIT = new Gff(buildNormalizedPath(modulePath, dungeon.areaResref~".git"));
		if(auto varTable = "VarTable" in areaGIT){
			foreach(const ref varNode ; varTable.as!(GffType.List)){
				switch(varNode["Name"].to!string){
					case "difficulty_name":
						dungeon.diffName = varNode["Value"].to!string;
						break;
					case "difficulty_max":
						dungeon.diffMax = varNode["Value"].to!int;
						break;
					default:
						break;
				}
			}
		}

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

DungeonStatus[] getDungeonStatus(in string accountName, in string charName, in GffNode[] journalVarTable, ref MySQLClient.LockedConnection mysqlConnection){
	import std.typecons: Nullable;
	import resourcemanager;
	import config;
	import nwn.lcdacompat;
	import nwn.gff;
	import nwn.biowaredb;

	auto cfg = ResourceManager.get!Config("cfg");

	Nullable!(BDBVariable.Value) getVarValue(string var, string prefix){
		import std.string;

		auto idx = var.indexOf('.');
		if(idx != -1){
			//Campaign var
			immutable dbName = var[0..idx].toLower;
			immutable varName = prefix ~ var[idx+1 .. $];

			BiowareDB db;
			try db = ResourceManager.getMut!BiowareDB(dbName);
			catch(ResourceException e){
				db = new BiowareDB(buildNormalizedPath(cfg["paths"]["database"].to!string, "quete"));
				ResourceManager.store(dbName, db);
			}

			return db.getVariableValue(accountName, charName, varName);
		}
		else{
			//Journal var
			immutable varName = prefix ~ var;
			foreach(const ref v ; journalVarTable){
				if(v["Name"].to!string == varName){
					return Nullable!(BDBVariable.Value)(BDBVariable.Value(cast(NWInt)v["Value"].to!NWInt));
				}
			}
			return Nullable!(BDBVariable.Value)();
		}
	}

	DungeonStatus[] ret;
	foreach(const ref dungeon ; dungeonList){
		DungeonStatus status;
		status.name = dungeon.name;
		status.areaName = dungeon.areaName;
		status.diffMax = dungeon.diffMax;

		foreach(i ; 0..dungeon.diffMax){
			auto hasLootedChest = getVarValue(dungeon.chestVar, diffPrefix(i));
			status.lootedChests ~= hasLootedChest.isNull? false : (hasLootedChest.get == 1);

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