module nwn2.character;

import std.conv;

class Character{

	this(in string bicFile){
		import std.path : baseName;
		import nwn2.resman;
		import nwn2.gff;
		import nwn2.tlk;
		import nwn2.twoda;

		this.bicFile = bicFile;
		bicFileName = baseName(bicFile, ".bic");

		auto strref = ResMan.get!StrRefResolver("resolver");
		auto gff = new Gff(bicFile);
		auto class2da = ResMan.findFileRes!TwoDA("classes.2da");
		auto race2da = ResMan.findFileRes!TwoDA("racialsubtypes.2da");
		auto abilities2da = ResMan.findFileRes!TwoDA("iprp_abilities.2da");
		auto alignment2da = ResMan.findFileRes!TwoDA("iprp_alignment.2da");

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
		race = strref.get(race2da.get!uint("Name", gff["Subrace"].to!int));

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
		foreach(i ; 0..6){
			abilities ~= Ability(
				strref.get(abilities2da.get!uint("Name", i)),
				gff[abilities2da.get!string("Label", i)].to!int
			);
		}
	}


	string name;

	int lvl;
	struct Class{
		string name;
		int lvl;
	}
	Class[] classes;

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