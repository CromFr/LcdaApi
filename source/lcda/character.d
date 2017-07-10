module lcda.character;

import std.conv;
import std.exception: enforce;

import mysql : MySQLClient;

class Character{
	import lcda.dungeons: DungeonStatus;

	this(in string account, in string bicFile, ref MySQLClient.LockedConnection mysqlConnection){
		import std.path : baseName;
		import resourcemanager;
		import nwn.fastgff;
		import nwn.tlk;
		import nwn.twoda;
		import lcda.compat;
		import lcda.dungeons;

		this.bicFile = bicFile;
		bicFileName = baseName(bicFile, ".bic");
		auto gff = new FastGff(bicFile);

		immutable strref = ResourceManager.get!StrRefResolver("resolver");
		immutable class2da = ResourceManager.fetchFile!TwoDA("classes.2da");
		immutable race2da = ResourceManager.fetchFile!TwoDA("racialsubtypes.2da");
		immutable abilities2da = ResourceManager.fetchFile!TwoDA("iprp_abilities.2da");
		immutable alignment2da = ResourceManager.fetchFile!TwoDA("iprp_alignment.2da");
		immutable skills2da = ResourceManager.fetchFile!TwoDA("skills.2da");
		immutable feats2da = ResourceManager.fetchFile!TwoDA("feat.2da");

		//Name
		immutable lastName = gff["LastName"].get!GffLocString.resolve(strref);
		name = gff["FirstName"].get!GffLocString.resolve(strref)~(lastName !is null ? (" "~lastName) : null);

		//Level / classes
		lvl = 0;
		foreach(i, GffStruct classStruct ; gff["ClassList"].get!(GffList)){
			immutable classID = classStruct["Class"].get!(GffInt);
			immutable classLvl = classStruct["ClassLevel"].get!(GffShort);

			lvl += classLvl;
			classes ~= Class(strref[class2da.get!StrRef("Name", classID)], classLvl);
		}

		//Race
		auto raceId = gff["Subrace"].get!GffByte;
		race = strref[race2da.get!StrRef("Name", raceId)];

		//Alignment
		alignment.good_evil = gff["GoodEvil"].get!GffByte;
		alignment.law_chaos = gff["LawfulChaotic"].get!GffByte;
		alignment.id = 0;
		alignment.id += alignment.good_evil>=75? 0 : alignment.good_evil>25? 1 : 2;
		alignment.id += alignment.law_chaos>=75? 0 : alignment.law_chaos>25? 3 : 6;
		alignment.name = strref[alignment2da.get!StrRef("Name", alignment.id)];

		//God
		god = gff["Deity"].get!GffString;

		//Abilities
		foreach(i, abilityAdj ; ["StrAdjust","DexAdjust","ConAdjust","IntAdjust","WisAdjust","ChaAdjust"]){
			immutable abilityLbl = abilities2da.get!string("Label", cast(uint)i);
			abilities ~= Ability(
				strref[abilities2da.get!StrRef("Name", cast(uint)i)],
				gff[abilityLbl].get!GffByte + race2da.get!int(abilityAdj, raceId)
			);
		}

		//Leveling
		immutable skillsCount = skills2da.rows;
		uint[] skillRanks;
		skillRanks.length = skillsCount;
		foreach(lvlIndex, GffStruct gffLvl ; gff["LvlStatList"].get!GffList){
			Level lvl;
			//name
			lvl.className = strref[class2da.get!StrRef("Name", gffLvl["LvlStatClass"].get!GffByte)];
			//ability
			if(lvlIndex%4 == 3){
				lvl.ability = strref[abilities2da.get!StrRef("Name", gffLvl["LvlStatAbility"].get!GffByte)];
			}
			//skills
			lvl.skills.length = skillsCount;
			foreach(i, GffStruct gffSkill ; gffLvl["SkillList"].get!GffList){
				auto earned = gffSkill["Rank"].get!GffByte;
				auto skillName = skills2da.get("Name", cast(StrRef)i);
				if(skillName!="***" && skillName!=""){
					skillRanks[i] += earned;
					lvl.skills[i] = LevelingSkill(
						strref[skillName.to!StrRef],
						skillRanks[i],
						earned
						);
				}
			}
			//feats
			foreach(i, GffStruct gffFeat ; gffLvl["FeatList"].get!GffList){
				lvl.feats ~= strref[feats2da.get!StrRef("FEAT", gffFeat["Feat"].get!GffWord)];
			}
			leveling ~= lvl;
		}

		//Journal
		import lcda.journal: Journal;
		static Journal jrl;
		if(jrl is null){
			import config: Config;
			import std.path: buildPath;
			auto cfg = ResourceManager.get!Config("cfg");
			jrl = new Journal(buildPath(cfg["paths"]["module"].get!string, "module.jrl"));
		}


		GffList journalVarTable;
		foreach(i, GffStruct item ; gff["ItemList"].get!GffList){
			if(item["Tag"].get!GffString == "journalNODROP"){
				journalVarTable = item["VarTable"].get!GffList;
				break;
			}
		}

		int[string] questEntryIds;
		if(journalVarTable.length > 0){
			//ignore chars without journal
			foreach(i, GffStruct var ; journalVarTable){
				immutable name = var["Name"].get!GffString;
				string questTag;
				if(name.length>1 && name[0]=='j' && name!="j63"){
					try{
						name[1..$].to!int;
						questTag = journalVarToTag(name);
					}
					catch(ConvException e){}
				}
				else if(name.length>3 && name[0..3]=="qs#"){
					import std.algorithm: splitter;
					import std.array: array;
					immutable split = name.splitter('#').array;
					if(split.length==2){
						questTag = split[1];
					}
				}
				else if(name=="quete_illithids"){
					questTag = name;
				}

				if(questTag !is null){
					questEntryIds[questTag] = var["Value"].get!GffInt;
				}
			}
		}

		foreach(ref questTag, ref quest ; jrl){
			auto entryId = questTag in questEntryIds;
			if(entryId && *entryId>0){
				const entry = *entryId in quest;
				if(entry){
					journal ~= JournalEntry(
						quest.name,
						entry.end+1,
						quest.priority,
						entry.description);
				}
			}
			else{
				journal ~= JournalEntry(
					quest.name,
					0,
					quest.priority,
					"Quête non découverte");
			}
		}


		//dungeons status
		dungeons = getDungeonStatus(account, name, journalVarTable, mysqlConnection);
	}

	string name;

	int lvl;
	static struct Class{
		string name;
		int lvl;
	}
	Class[] classes;

	static struct LevelingSkill{
		string name;
		uint value;
		int valueDiff;
	}
	static struct Level{
		string className;
		string ability;
		LevelingSkill[] skills;
		string[] feats;
	}
	Level[] leveling;

	string race;

	static struct Alignment{
		uint id;
		string name;
		int good_evil;
		int law_chaos;
	}
	Alignment alignment;
	string god;

	static struct Ability{string label; int value;}
	Ability[] abilities;

	static struct JournalEntry{
		string name;
		uint state;
		uint priority;
		string description;
	}
	JournalEntry[] journal;

	DungeonStatus[] dungeons;


	string bicFile;
	string bicFileName;
}


class LightCharacter{
	this(in string bicFile){
		import std.path : baseName;
		import resourcemanager;
		import nwn.fastgff;
		import nwn.tlk;
		import nwn.twoda;
		import lcda.compat;

		bicFileName = baseName(bicFile, ".bic");
		auto gff = new FastGff(bicFile);

		immutable strref = ResourceManager.get!StrRefResolver("resolver");
		immutable class2da = ResourceManager.fetchFile!TwoDA("classes.2da");
		immutable race2da = ResourceManager.fetchFile!TwoDA("racialsubtypes.2da");
		immutable abilities2da = ResourceManager.fetchFile!TwoDA("iprp_abilities.2da");

		//Name
		name = gff["FirstName"].get!GffLocString.resolve(strref)~" "~gff["LastName"].get!GffLocString.resolve(strref);

		//Level / classes
		lvl = 0;
		foreach(i, GffStruct classStruct ; gff["ClassList"].get!GffList){
			immutable classID = classStruct["Class"].get!GffInt;
			immutable classLvl = classStruct["ClassLevel"].get!GffShort;

			lvl += classLvl;
			classes ~= Character.Class(strref[class2da.get!StrRef("Name", classID)], classLvl);
		}

		//Race
		auto raceId = gff["Subrace"].get!GffByte;
		race = strref[race2da.get!StrRef("Name", raceId)];
	}

	string name;
	string race;
	int lvl;
	Character.Class[] classes;
	string bicFileName;
}