module nwn.character;

import std.conv;

class Character{

	this(in string bicFile, bool isDeleted=false){
		import std.path : baseName;
		import resourcemanager;
		import nwn.gff;
		import nwn.tlk;
		import nwn.twoda;

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
		auto raceId = gff["Subrace"].as!(GffType.Byte);
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
		foreach(lvlIndex, gffLvl ; gff["LvlStatList"].as!(GffType.List)){
			Level lvl;
			//name
			lvl.className = strref[class2da.get!StrRef("Name", gffLvl["LvlStatClass"].as!(GffType.Byte))];
			//ability
			if(lvlIndex%4 == 3){
				lvl.ability = strref[abilities2da.get!StrRef("Name", gffLvl["LvlStatAbility"].as!(GffType.Byte))];
			}
			//skills
			lvl.skills.length = skillsCount;
			foreach(i, gffSkill ; gffLvl["SkillList"].to!(GffNode[])){
				auto earned = gffSkill["Rank"].as!(GffType.Byte);
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
			foreach(gffFeat ; gffLvl["FeatList"].to!(GffNode[])){
				lvl.feats ~= strref[feats2da.get!StrRef("FEAT", gffFeat["Feat"].as!(GffType.Word))];
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

unittest{
	import resourcemanager;
	import nwn.gff;
	import nwn.tlk;

	//TODO: make character.d independent of ResourceManager

	//auto strresolv = new StrRefResolver(
	//	new Tlk("unittest/data/dialog.tlk"),
	//	null);
	//ResourceManager.store("resolver", strresolv);
	//ResourceManager.path.add("/home/crom/Documents/Neverwinter Nights 2/override/LcdaClientSrc/lcda2da.hak/");

	//new Character("unittest/vault/CromFr/krogar.bic");

	//ResourceManager.remove!StrRefResolver("resolver");
}