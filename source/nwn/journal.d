module nwn.journal;
import nwn.gff;

class Journal{
	this(in string modulejrlPath){
		static bool[string] hiddenQuests;
		if(hiddenQuests is null){
			import resourcemanager: ResourceManager, ResourceException;
			import config: Config;
			import vibe.data.json: Json;
			import std.algorithm: map;
			auto cfg = ResourceManager.get!Config("cfg");
			foreach(ref questTag ; cfg["journal"]["hidden_quests"].get!(Json[]).map!(a=>a.get!string)){
				hiddenQuests[questTag] = true;
			}
		}



		auto gff = new Gff(modulejrlPath);

		foreach(ref gffQuest ; gff["Categories"].as!GffList){
			immutable tag = gffQuest["Tag"].to!string;
			if(tag !in hiddenQuests){
				auto quest = Quest(
						gffQuest["Name"].to!string,
						gffQuest["Priority"].to!int,
						null
					);

				foreach(ref entry ; gffQuest["EntryList"].as!GffList){
					quest.entries[entry["ID"].to!uint] = Entry(
						entry["Text"].to!string,
						entry["End"].to!bool
						);
				}

				quests[tag] = quest;
			}

		}
	}

	Quest[string] quests;
	alias quests this;

	static struct Quest{
		string name;
		int priority;
		Entry[uint] entries;
		alias entries this;
	}
	static struct Entry{
		string description;
		bool end;
	}
}