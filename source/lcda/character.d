module lcda.character;

import std.conv;
import std.string: toLower;
import std.exception: enforce;
import std.typecons: Nullable;
import nwn.fastgff;

import api.apidef: Character, LightCharacter, Metadata;


Character buildCharacter(in string account, in string bicFile){
	Character character;

	import std.path : baseName;
	import resourcemanager;
	import nwn.fastgff;
	import nwn.tlk;
	import nwn.twoda;
	import lcda.compat;
	import lcda.dungeons;


	version(profile){
		import std.datetime.stopwatch: StopWatch;
		StopWatch sw;
	}

	version(profile){
		sw.reset();
		sw.start();
	}

	auto gff = new FastGff(bicFile);

	version(profile){
		sw.stop();
		immutable profParsing = sw.peek.total!"msecs";
	}

	const strref = ResourceManager.get!StrRefResolver("resolver");
	const class2da = ResourceManager.fetchFile!TwoDA("classes.2da");
	const race2da = ResourceManager.fetchFile!TwoDA("racialsubtypes.2da");
	const abilities2da = ResourceManager.fetchFile!TwoDA("iprp_abilities.2da");
	const alignment2da = ResourceManager.fetchFile!TwoDA("iprp_alignment.2da");
	const skills2da = ResourceManager.fetchFile!TwoDA("skills.2da");
	const feats2da = ResourceManager.fetchFile!TwoDA("feat.2da");


	version(profile){
		sw.reset();
		sw.start();
	}

	fillLightCharacterProperties(gff, bicFile, character);
	auto raceId = gff["Subrace"].get!GffByte;
	character.raceECL = race2da.get!ubyte("ECL", raceId, 0);
	size_t[size_t] classLookupMap;
	foreach(i, const ref cl ; character.classes){
		classLookupMap[cl.id] = i;
	}

	//Alignment
	character.alignment.good_evil = gff["GoodEvil"].get!GffByte;
	character.alignment.law_chaos = gff["LawfulChaotic"].get!GffByte;
	uint alignmentId = 0;
	alignmentId += character.alignment.good_evil>=75? 0 : character.alignment.good_evil>25? 1 : 2;
	alignmentId += character.alignment.law_chaos>=75? 0 : character.alignment.law_chaos>25? 3 : 6;
	character.alignment.name = strref[alignment2da.get!StrRef("Name", alignmentId).get(0)];

	//God
	character.god = gff["Deity"].get!GffString;

	//Gold
	character.gold = gff["Gold"].get!GffDWord;

	//Abilities
	foreach(i, abilityAdj ; ["StrAdjust","DexAdjust","ConAdjust","IntAdjust","WisAdjust","ChaAdjust"]){
		immutable abilityLbl = abilities2da.get!string("Label", cast(uint)i);
		character.abilities ~= Character.Ability(
			strref[abilities2da.get!StrRef("Name", cast(uint)i).get(0)],
			gff[abilityLbl].get!GffByte + race2da.get!int(abilityAdj, raceId).get(0)
		);
	}

	//Feats
	size_t[size_t] featLookupMap;
	foreach(i, gffFeat ; gff["FeatList"].get!GffList){
		immutable id = gffFeat["Feat"].get!GffWord;
		immutable name = strref[feats2da.get!StrRef("FEAT", id).get(0)];
		immutable icon = feats2da.get!string("ICON", id).toLower;
		immutable category = feats2da.get!string("FeatCategory", id);

		featLookupMap[id] = character.feats.length;
		character.feats ~= Character.Feat(id, name, category, icon);
	}

	//Skills
	size_t[size_t] skillLookupMap;
	foreach(id, gffFeat ; gff["SkillList"].get!GffList){
		if(skills2da.get!int("REMOVED", id, 0) > 0)
			continue;

		immutable name = strref[skills2da.get!StrRef("Name", id).get(0)];
		immutable icon = skills2da.get!string("Icon", id).toLower;
		immutable rank = gffFeat["Rank"].get!GffByte;

		size_t abilityIndex;
		switch(skills2da.get!string("KeyAbility", id)){
			case "STR": abilityIndex = 0; break;
			case "DEX": abilityIndex = 1; break;
			case "CON": abilityIndex = 2; break;
			case "INT": abilityIndex = 3; break;
			case "WIS": abilityIndex = 4; break;
			case "CHA": abilityIndex = 5; break;
			default: assert(0, "Invalid KeyAbility value in skills.2da");
		}

		skillLookupMap[id] = character.skills.length;
		character.skills ~= Character.Skill(id, name, icon, rank, abilityIndex);
	}


	//Leveling
	immutable skillsCount = skills2da.rows;
	uint[] skillRanks;
	skillRanks.length = skillsCount;
	size_t[4] levelClassCount;// class index => level count
	foreach(lvlIndex, gffLvl ; gff["LvlStatList"].get!GffList){
		Character.Level lvl;
		//class
		auto classId = gffLvl["LvlStatClass"].get!GffByte;
		lvl.classIndex = classLookupMap[classId];
		lvl.classLevel = ++levelClassCount[lvl.classIndex];

		//ability
		if(lvlIndex%4 == 3){
			lvl.ability = strref[abilities2da.get!StrRef("Name", gffLvl["LvlStatAbility"].get!GffByte).get(0)];
		}
		//skills
		lvl.skills.length = skillsCount;
		foreach(i, gffSkill ; gffLvl["SkillList"].get!GffList){
			auto earned = gffSkill["Rank"].get!GffByte;
			if(auto skillIndex = i in skillLookupMap){
				skillRanks[i] += earned;
				lvl.skills[i] = Character.Level.LevelingSkill(
					*skillIndex,
					skillRanks[i],
					earned
					);
			}
		}
		//feats
		GffWord[] lvlAutoFeats;// feat IDs

		auto featsTableName = class2da.get("FeatsTable", classId);
		auto featsTable = ResourceManager.fetchFile!TwoDA(featsTableName.toLower~".2da");
		immutable featsTableGrantedIdx = featsTable.columnIndex("GrantedOnLevel");
		immutable featsTableFeatIdx = featsTable.columnIndex("FeatIndex");

		foreach(i ; 0 .. featsTable.rows){
			const featLvl = featsTable.get!int(featsTableGrantedIdx, i);
			if(!featLvl.isNull && featLvl == lvl.classLevel){
				auto feat = featsTable.get!GffWord(featsTableFeatIdx, i);
				if(!feat.isNull)
					lvlAutoFeats ~= feat.get;
			}
		}
		if(lvlIndex == 0){
			auto raceFeatsTableName = race2da.get("FeatsTable", raceId);
			if(raceFeatsTableName !is null){
				auto raceFeatsTable = ResourceManager.fetchFile!TwoDA(raceFeatsTableName.toLower~".2da");
				immutable raceFeatsTableFeatIdx = raceFeatsTable.columnIndex("FeatIndex");

				foreach(i ; 0 .. raceFeatsTable.rows){
					auto feat = raceFeatsTable.get!GffWord(raceFeatsTableFeatIdx, i);
					if(!feat.isNull)
						lvlAutoFeats ~= feat.get;
				}
			}
		}

		foreach(i, gffFeat ; gffLvl["FeatList"].get!GffList){
			auto feat = gffFeat["Feat"].get!GffWord in featLookupMap;
			if(feat){
				lvl.featIndices ~= *feat;

				//Automatically given feat detection
				foreach(featId ; lvlAutoFeats){
					if(featId == character.feats[*feat].id){
						character.feats[*feat].automatic = true;
					}
				}
			}
		}
		character.leveling ~= lvl;
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
	foreach(i, item ; gff["ItemList"].get!GffList){
		if(item["Tag"].get!GffString == "journalNODROP"){
			journalVarTable = cast(GffList)item["VarTable"].get!GffList;//todo: horrible cast
			break;
		}
	}

	int[string] questEntryIds;
	if(journalVarTable.length > 0){
		//ignore chars without journal
		foreach(i, var ; journalVarTable){
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
				character.journal ~= Character.QuestEntry(
					quest.name,
					entry.end+1,
					quest.priority,
					entry.description);
			}
		}
		else{
			character.journal ~= Character.QuestEntry(
				quest.name,
				0,
				quest.priority,
				"Quête non découverte");
		}
	}

	version(profile){
		sw.stop();
		immutable profBasic = sw.peek.total!"msecs";

		sw.reset();
		sw.start();
	}

	//dungeons status
	character.dungeons = getDungeonStatus(account, character.name, journalVarTable);

	version(profile){
		sw.stop();
		auto profDungeons = sw.peek.total!"msecs";

		import std.stdio: writeln;
		writeln("CHAR ", account, ".", bicFile.baseName, ": Parsing=", profParsing, "ms Basic=", profBasic, "ms Dungeons=", profDungeons, "ms");
	}

	return character;
}


LightCharacter buildLightCharacter(in string bicFile, bool parseMetadata = false){
	LightCharacter lightCharacter;
	auto gff = new FastGff(bicFile);

	fillLightCharacterProperties(gff, bicFile, lightCharacter);

	if(parseMetadata){
		import std.file : exists, readText;
		import vibe.d: deserializeJson;

		immutable charMetaPath = bicFile ~ ".meta";
		if(charMetaPath.exists){
			lightCharacter.metadata = charMetaPath
				.readText
				.deserializeJson!Metadata;
		}
		else{
			lightCharacter.metadata = Metadata();
		}
	}

	return lightCharacter;
}


private void fillLightCharacterProperties(T)(FastGff gff, in string fileName, ref T character) if(is(T: LightCharacter) || is(T: Character)){
	import std.path : baseName;
	import resourcemanager;
	import nwn.tlk;
	import nwn.twoda;
	import lcda.compat;

	const strref = ResourceManager.get!StrRefResolver("resolver");
	const class2da = ResourceManager.fetchFile!TwoDA("classes.2da");
	const race2da = ResourceManager.fetchFile!TwoDA("racialsubtypes.2da");
	const xpTable = ResourceManager.fetchFile!TwoDA("exptable.2da");

	with(character){
		bicFileName = baseName(fileName, ".bic");

		//Name
		immutable lastName = gff["LastName"].get!GffLocString.resolve(strref);
		name = gff["FirstName"].get!GffLocString.resolve(strref)~(lastName !is null ? (" "~lastName) : null);

		//Level / classes
		lvl = 0;
		foreach(i, classStruct ; gff["ClassList"].get!GffList){
			immutable classID = classStruct["Class"].get!GffInt;
			immutable classLvl = classStruct["ClassLevel"].get!GffShort;
			immutable className = strref[class2da.get!StrRef("Name", classID).get(0)];
			immutable classIcon = class2da.get!string("Icon", classID).toLower;

			lvl += classLvl;
			classes ~= Character.Class(classID, className, classLvl, classIcon);
		}

		//Race
		auto raceId = gff["Subrace"].get!GffByte;
		race = strref[race2da.get!StrRef("Name", raceId).get(0)];

		immutable raceECL = race2da.get!StrRef("ECL", raceId, 0);
		xp = gff["Experience"].get!GffDWord;
		xpBounds = [
			xpTable.get!ulong("XP", lvl == 1 ? 0 : (lvl - 1 + raceECL)).get,
			xpTable.get!ulong("XP", lvl + raceECL).get,
		];
	}

}
