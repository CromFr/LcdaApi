module nwn.journal;
import nwn.gff;

class Journal{
	this(in string modulejrlPath){
		auto gff = new Gff(modulejrlPath);

		foreach(ref gffQuest ; gff["Categories"].as!GffList){
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

			quests[gffQuest["Tag"].to!string] = quest;
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