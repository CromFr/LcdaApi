module nwn2.character;
import nwn2.gff;

class Character{

	this(in string bicFile){
		import nwn2.gff;
		import std.stdio;

		auto gff = new Gff(bicFile);


		name = gff["FirstName"].to!string~" "~gff["LastName"].to!string;

		lvl = 0;
		foreach(n ; gff["ClassList"].to!(GffNode[])){
			lvl += n["ClassLevel"].to!int;
		}
	}


	string name;
	int lvl;


}