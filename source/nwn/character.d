module nwn.character;

import std.conv;
import std.exception: enforce;



class Character{

	this(in string bicFile, bool isDeleted=false){
		import std.path : baseName;
		import resourcemanager;
		import nwn.gff;
		import nwn.tlk;
		import nwn.twoda;
		import nwn.lcdacompat;

		deleted = isDeleted;

		this.bicFile = bicFile;
		bicFileName = baseName(bicFile, ".bic");
		auto gff = new Gff(bicFile);

		immutable strref = ResourceManager.get!StrRefResolver("resolver");
		immutable class2da = ResourceManager.fetchFile!TwoDA("classes.2da");
		immutable race2da = ResourceManager.fetchFile!TwoDA("racialsubtypes.2da");
		immutable abilities2da = ResourceManager.fetchFile!TwoDA("iprp_abilities.2da");
		immutable alignment2da = ResourceManager.fetchFile!TwoDA("iprp_alignment.2da");
		immutable skills2da = ResourceManager.fetchFile!TwoDA("skills.2da");
		immutable feats2da = ResourceManager.fetchFile!TwoDA("feat.2da");

		//Name
		name = gff["FirstName"].to!string~" "~gff["LastName"].to!string;

		//Level / classes
		lvl = 0;
		foreach(ref classStruct ; gff["ClassList"].as!(GffType.List)){
			immutable classID = classStruct["Class"].as!(GffType.Int);
			immutable classLvl = classStruct["ClassLevel"].as!(GffType.Short);

			lvl += classLvl;
			classes ~= Class(strref[class2da.get!StrRef("Name", classID)], classLvl);
		}

		//Race
		auto raceId = gff["Subrace"].as!GffByte;
		race = strref[race2da.get!StrRef("Name", raceId)];

		//Alignment
		alignment.good_evil = gff["GoodEvil"].as!(GffType.Byte);
		alignment.law_chaos = gff["LawfulChaotic"].as!(GffType.Byte);
		alignment.id = 0;
		alignment.id += alignment.good_evil>=75? 0 : alignment.good_evil>25? 1 : 2;
		alignment.id += alignment.law_chaos>=75? 0 : alignment.law_chaos>25? 3 : 6;
		alignment.name = strref[alignment2da.get!StrRef("Name", alignment.id)];

		//God
		god = gff["Deity"].as!(GffType.ExoString);

		//Abilities
		foreach(i, abilityAdj ; ["StrAdjust","DexAdjust","ConAdjust","IntAdjust","WisAdjust","ChaAdjust"]){
			immutable abilityLbl = abilities2da.get!string("Label", cast(uint)i);
			abilities ~= Ability(
				strref[abilities2da.get!StrRef("Name", cast(uint)i)],
				gff[abilityLbl].as!(GffType.Byte) + race2da.get!int(abilityAdj, raceId)
			);
		}

		//Leveling
		immutable skillsCount = skills2da.rows;
		uint[] skillRanks;
		skillRanks.length = skillsCount;
		foreach(lvlIndex, gffLvl ; gff["LvlStatList"].as!GffList){
			Level lvl;
			//name
			lvl.className = strref[class2da.get!StrRef("Name", gffLvl["LvlStatClass"].as!GffByte)];
			//ability
			if(lvlIndex%4 == 3){
				lvl.ability = strref[abilities2da.get!StrRef("Name", gffLvl["LvlStatAbility"].as!GffByte)];
			}
			//skills
			lvl.skills.length = skillsCount;
			foreach(i, gffSkill ; gffLvl["SkillList"].as!GffList){
				auto earned = gffSkill["Rank"].as!GffByte;
				auto skillName = skills2da.get!string("Name", cast(uint)i);
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
			foreach(gffFeat ; gffLvl["FeatList"].as!GffList){
				lvl.feats ~= strref[feats2da.get!StrRef("FEAT", gffFeat["Feat"].as!GffWord)];
			}
			leveling ~= lvl;
		}

		//Journal
		import nwn.journal: Journal;
		static Journal jrl;
		if(jrl is null){
			import config: Config;
			import std.path: buildPath;
			auto cfg = ResourceManager.get!Config("cfg");
			jrl = new Journal(buildPath(cfg["paths"]["module"].get!string, "module.jrl"));
		}

		GffNode* journalNodrop;
		foreach(ref item ; gff["ItemList"].as!GffList){
			import std.stdio; writeln(item["Tag"].to!string); stdout.flush();
			if(item["Tag"].to!string == "journalNODROP"){
				journalNodrop = &item;
				break;
			}
		}
		if(journalNodrop){
			//ignore chars without journal
			import std.stdio; writeln("====================> journalNODROP on "~bicFile); stdout.flush();
			foreach(ref var ; (*journalNodrop)["VarTable"].as!GffList){
				immutable name = var["Name"].to!string;
				string questTag;
				if(name.length>1 && name[0]=='j'){
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

				if(questTag !is null){
					const quest = questTag in jrl;
					if(quest){
						const entryId = var["Value"].to!int;
						if(entryId > 0){
							const entry = entryId in *quest;
							if(entry){
								journal ~= JournalEntry(
									quest.name,
									entry.end,
									quest.priority,
									entry.description);
							}
						}
					}
				}
			}
		}
	}

	bool deleted;

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
		uint finished;
		uint priority;
		string description;
	}
	JournalEntry[] journal;


	string bicFile;
	string bicFileName;
}


class LightCharacter{
	this(in string bicFile){
		import std.path : baseName;
		import resourcemanager;
		import nwn.gff;
		import nwn.tlk;
		import nwn.twoda;
		import nwn.lcdacompat;

		bicFileName = baseName(bicFile, ".bic");
		auto gff = new Gff(bicFile);

		immutable strref = ResourceManager.get!StrRefResolver("resolver");
		immutable class2da = ResourceManager.fetchFile!TwoDA("classes.2da");
		immutable race2da = ResourceManager.fetchFile!TwoDA("racialsubtypes.2da");
		immutable abilities2da = ResourceManager.fetchFile!TwoDA("iprp_abilities.2da");

		//Name
		name = gff["FirstName"].to!string~" "~gff["LastName"].to!string;

		//Level / classes
		lvl = 0;
		foreach(ref classStruct ; gff["ClassList"].as!(GffType.List)){
			immutable classID = classStruct["Class"].as!(GffType.Int);
			immutable classLvl = classStruct["ClassLevel"].as!(GffType.Short);

			lvl += classLvl;
			classes ~= Character.Class(strref[class2da.get!StrRef("Name", classID)], classLvl);
		}

		//Race
		auto raceId = gff["Subrace"].as!GffByte;
		race = strref[race2da.get!StrRef("Name", raceId)];
	}

	string name;
	string race;
	int lvl;
	Character.Class[] classes;
	string bicFileName;
}