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
			//TODO: Sort journal by priority/name
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


private string journalVarToTag(in string journalVar){
	switch(journalVar){
		case "j1": return "quete_auservicedunpeureux";
		case "j2": return "quete_mineraijorik";
		case "j3": return "quete_rats";
		case "j4": return "quete_enlevementmeribona";
		case "j5": return "quete_pierrederappelgalaetor";
		case "j6": return "quete_casque_herbert";
		case "j7": return "quete_nettoyerlavermine";
		case "j8": return "quete_poissonnier";
		case "j9": return "quete_preuvesanglante";
		case "j10": return "quete_romeofaitsonromeo";
		case "j11": return "quete_dentsdorc";
		case "j12": return "quete_tourdesmagespierre";
		case "j13": return "quete_nessie";
		case "j14": return "quete_tuergramshh";
		case "j15": return "quete_trappeur";
		case "j16": return "quete_queuelezard";
		case "j17": return "quete_tuershalva";
		case "j18": return "quete_elementaires";
		case "j19": return "quete_herisson";
		case "j20": return "quete_kahrk";
		case "j21": return "quete_wiverne";
		case "j22": return "quete_mineraiadamantium";
		case "j23": return "quete_eowildir";
		case "j24": return "quete_espritimaskari";
		case "j25": return "quete_residuspectral";
		case "j26": return "quete_convoidetresse";
		case "j27": return "quete_grabugeaubateauivre";
		case "j28": return "quete_gnolls";
		case "j29": return "quete_anneauxgnolls";
		case "j30": return "quete_recherche";
		case "j31": return "quete_spectres";
		case "j32": return "quete_tishiste";
		case "j33": return "quete_mephos";
		case "j34": return "quete_pirates";
		case "j35": return "quete_epervier";
		case "j36": return "quete_ossement";
		case "j37": return "quete_zherghul";
		case "j38": return "quete_ibee";
		case "j39": return "quete_crane";
		case "j40": return "quete_tentacule_boss";
		case "j41": return "quete_venin";
		case "j42": return "quete_boss_araignee";
		case "j43": return "quete_poudre_fee";
		case "j44": return "quete_ailedragon_boss";
		case "j45": return "quete_brochealenna";
		case "j46": return "quete_dinerdecon";
		case "j47": return "quete_epeejerk";
		case "j48": return "quete_chatperdu";
		case "j49": return "quete_cartestresor";
		case "j50": return "quete_fees";
		case "j51": return "quete_artefact";
		case "j52": return "serpent";
		case "j53": return "quete_geants";
		case "j54": return "quete_choseoutremonde";
		case "j55": return "quete_tetesgeants";
		case "j56": return "quete_poeme_elrendir";
		case "j57": return "quete_ames_torturees";
		case "j58": return "quete_enfant_citadelle";
		case "j59": return "quete_berenice_citadelle";
		case "j60": return "quete_secrets_citadelle";
		case "j61": return "quete_seigneur_damne";
		case "j62": return "quete_taskylos";
		case "j63": return "quete_illithids";
		default: assert(0, "Unknown journal variable: '"~journalVar~"'");
	}
}