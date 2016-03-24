module devlib;
debug{
	///Prints line numbers on a mixin string
	///
	///Put on the same line of the mixin:
	///  pragma(msg, formatMixin!(yourMixinString));
	string formatMixin(string MIXIN, int line=__LINE__)(){
		import std.string : rightJustify;
		import std.conv : to;
		string ret;
		foreach(i, l ; MIXIN.split("\n")){
		//	pragma(msg, l.rightJustify(3), "| ", l);

			ret ~= (line+i).to!string.rightJustify(3)~"| "~l~"\n";
		}
		return ret;
	}

}