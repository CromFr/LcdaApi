module nwn2.twoda;

import std.string;
import std.conv : to;

class TwoDA{

	class ParseException : Exception{
		this(in string s){super(s);}
	}

	this(string filepath){
		import std.file;

		foreach(lineIndex, line ; readText(filepath).splitLines){
			if(lineIndex<2)continue;

			auto data = extractRowData(line);

			if(lineIndex==2){
				header = data;
			}
			else{
				if(data.length != header.length+1){
					throw new ParseException("Incorrect number of fields: "~filepath~":"~lineIndex.to!string);
				}

				int lineNo = data[0].to!int;
				if(lineNo >= values.length)
					values.length = lineNo+1;
				values[lineNo] = data[1..$];
			}

		}

	}

	const auto ref get(T)(in string colName, in int line){
		size_t index = size_t.max;
		foreach(i, cn ; header){
			if(cn==colName){
				index = i;
				break;
			}
		}
		if(index!=size_t.max)
			return values[line][index].to!T;
		else
			throw new Exception("Column '"~colName~"' not found");
	}

	@property{
		const size_t rows(){
			return values.length;
		}
	}

private:
	string[] header;
	string[][] values;

	auto ref extractRowData(in string line){
		import std.uni;
		string[] ret;


		enum State{
			Whitespace,
			Field,
			QuotedField,
		}
		string fieldBuf;
		auto state = State.Whitespace;
		foreach(ref c ; line~" "){
			switch(state){
				case State.Whitespace:
					if(c.isWhite)
						continue;
					else{
						fieldBuf = "";
						if(c=='"')
							state = State.QuotedField;
						else{
							fieldBuf ~= c;
							state = State.Field;
						}
					}
					break;

				case State.Field:
					if(c.isWhite){
						if(fieldBuf=="****")
							ret ~= "";
						else
							ret ~= fieldBuf;
						state = State.Whitespace;
					}
					else
						fieldBuf ~= c;
					break;

				case State.QuotedField:
					if(c=='"'){
						ret ~= fieldBuf;
						state = State.Whitespace;
					}
					else
						fieldBuf ~= c;
					break;

				default: assert(0);
			}
		}
		return ret;
	}
}