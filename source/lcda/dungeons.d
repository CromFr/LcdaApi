module lcda.dungeons;

import std.traits: EnumMembers;
import std.path: buildPath;
import std.conv: to;

import utils: buildPathCI;
import nwn.fastgff: GffList;
import resourcemanager;


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

	immutable strref = ResourceManager.get!StrRefResolver("resolver");

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
		StopWatch swBiowareDB, swJournal;
	}

	version(profile){
		swBiowareDB.reset();
		swJournal.reset();
	}


	auto cfg = ResourceManager.get!Config("cfg");
	immutable pcid = accountName ~ charName;

	Nullable!GffField findJournalVar(string varName){
		foreach(i, GffStruct v ; journalVarTable){
			if(v["Name"].get!GffString == varName){
				return Nullable!GffField(v["Value"]);
			}
		}
		return Nullable!GffField();
	}

	Nullable!(const(NWInt)) getVarValue(string var, string prefix){
		import std.string;

		auto idx = var.indexOf('.');
		if(idx != -1){
			//Campaign var
			version(profile){
				swBiowareDB.start();
				scope(exit) swBiowareDB.stop();
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
				auto jvar = findJournalVar(varName);
				if(!jvar.isNull){
					return Nullable!(const(NWInt))(jvar.get.get!GffInt);
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

		version(profile) swBiowareDB.start();
		foreach(i ; 0 .. dungeon.diffMax + 1){
			if(dungeon.chestVar !is null){
				auto hasLootedChest = getVarValue(dungeon.chestVar, diffPrefix(i));
				status.lootedChests ~= hasLootedChest.isNull? false : (hasLootedChest.get == 1);
			}
		}
		version(profile) swBiowareDB.stop();


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
		auto profDatabase = swBiowareDB.peek.total!"msecs";
		auto profJournal = swJournal.peek.total!"msecs";

		import std.stdio: writeln;
		writeln("DUNJ ", accountName, ".", charName, ".bic: BiowareDB=", profDatabase, "ms Journal=", profJournal, "ms");

	}
	return ret;

}