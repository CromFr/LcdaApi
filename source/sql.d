module sql;

import mysql;
public import mysql: Connection;

debug import std.stdio;


Prepared preparedStatement(VT...)(Connection conn, in string sql, VT placeholders){
	static assert(placeholders.length % 2 == 0, "Need a pair number of placeholders");

	//Check if there is a valid placeholder at index offset
	// ret[0]: Placeholder value index
	// ret[1]: Placeholder name length. 0 if not found
	auto getPlaceholder(in string str, size_t offset){
		import std.traits: isSomeString;
		import std.typecons: tuple;

		static struct Ret {
			size_t valueIndex;
			size_t nameLength;
		}
		Ret ret;

		foreach(i, ph ; placeholders){
			static if(i % 2 == 0){
				static assert(isSomeString!(typeof(ph)), "Placeholders must be key value pairs, where the key is a string");

				immutable len = ph.length;
				if(offset + 1 + len <= str.length && str[offset + 1 .. offset + 1 + len] == ph){
					ret.valueIndex = i;
					ret.nameLength = len + 1;
					return ret;
				}
			}
		}
		return ret;
	}

	string statement;
	//size_t[] placeholderValuesIdx;
	size_t phNameIndex = 0;
	size_t[][placeholders.length / 2] placeholderMap;

	// Find and registers placeholders
	for(size_t i = 0 ; i < sql.length ; i++){
		if(sql[i] == '$'){
			auto ph = getPlaceholder(sql, i);
			if(ph.nameLength > 0){
				placeholderMap[ph.valueIndex / 2] ~= phNameIndex++;
				statement ~= "?";
				i += ph.nameLength - 1;
				continue;
			}
		}
		statement ~= sql[i];
	}

	// Create the prepared statement
	Prepared ret = prepare(conn, statement);

	// Fill prepared statement arguments
	foreach(i, ph ; placeholders){
		static if(i % 2 == 1){
			foreach(index ; placeholderMap[i / 2])
				ret.setArg(index, placeholders[i]);
		}
	}

	return ret;
}



