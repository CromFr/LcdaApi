module nwn2.character;

import std.conv;

class Character{

	this(in string bicFile, bool isDeleted=false){
		import std.path : baseName;
		import resourcemanager;
		import nwn2.gff;
		import nwn2.tlk;
		import nwn2.twoda;

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
		foreach(n ; gff["ClassList"].to!(GffNode[])){
			immutable classID = n["Class"].to!int;
			immutable classLvl = n["ClassLevel"].to!int;

			lvl += classLvl;
			classes ~= Class(strref.get(class2da.get!uint("Name", classID)), classLvl);
		}

		//Race
		auto raceId = gff["Subrace"].to!int;
		race = strref.get(race2da.get!uint("Name", raceId));

		//Alignment
		alignment.good_evil = gff["GoodEvil"].to!int;
		alignment.law_chaos = gff["LawfulChaotic"].to!int;
		alignment.id = 0;
		alignment.id += alignment.good_evil>=75? 0 : alignment.good_evil>25? 1 : 2;
		alignment.id += alignment.law_chaos>=75? 0 : alignment.law_chaos>25? 3 : 6;
		alignment.name = strref.get(alignment2da.get!uint("Name", alignment.id));

		//God
		god = gff["Deity"].to!string;

		//Abilities
		foreach(i, abilityAdj ; ["StrAdjust","DexAdjust","ConAdjust","IntAdjust","WisAdjust","ChaAdjust"]){
			abilities ~= Ability(
				strref.get(abilities2da.get!uint("Name", cast(uint)i)),
				gff[abilities2da.get!string("Label", cast(uint)i)].to!int + race2da.get!int(abilityAdj, raceId)
			);
		}

		//Leveling
		immutable skillsCount = skills2da.rows;
		uint[] skillRanks;
		skillRanks.length = skillsCount;
		foreach(lvlIndex, gffLvl ; gff["LvlStatList"].to!(GffNode[])){
			Level lvl;
			//name
			lvl.className = strref.get(class2da.get!uint("Name", gffLvl["LvlStatClass"].to!uint));
			//ability
			if(lvlIndex%4 == 3){
				lvl.ability = strref.get(abilities2da.get!uint("Name", gffLvl["LvlStatAbility"].to!uint));
			}
			//skills
			lvl.skills.length = skillsCount;
			foreach(i, gffSkill ; gffLvl["SkillList"].to!(GffNode[])){
				auto earned = gffSkill["Rank"].to!uint;
				auto skillName = skills2da.get!string("Name", cast(uint)i);
				if(skillName!="***" && skillName!=""){
					skillRanks[i] += earned;
					lvl.skills[i] = LevelingSkill(
						strref.get(skillName.to!uint),
						skillRanks[i],
						earned
						);
				}
			}
			//feats
			foreach(gffFeat ; gffLvl["FeatList"].to!(GffNode[])){
				lvl.feats ~= strref.get(feats2da.get!uint("FEAT", gffFeat["Feat"].to!uint));
			}
			leveling ~= lvl;
		}
	}

	bool deleted;

	string name;

	int lvl;
	struct Class{
		string name;
		int lvl;
	}
	Class[] classes;

	struct LevelingSkill{
		string name;
		uint value;
		int valueDiff;
	}
	struct Level{
		string className;
		string ability;
		LevelingSkill[] skills;
		string[] feats;
	}
	Level[] leveling;

	string race;

	struct Alignment{
		uint id;
		string name;
		int good_evil;
		int law_chaos;
	}
	Alignment alignment;
	string god;

	struct Ability{string label; int value;}
	Ability[] abilities;



	string bicFile;
	string bicFileName;
}