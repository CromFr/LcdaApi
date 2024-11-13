module sql;

import mysql;
import std.conv: to;
import std.variant;

public import std.variant: Variant;
public import mysql: Connection, MySQLPool, prepare, Prepared, exec, query;

debug import std.stdio;

struct PreparedCustom {
	package this(Connection conn, in string sql, in string[] placeholderNames){

		string sqlStatement;

		// Find and registers placeholders
		for(size_t i = 0 ; i < sql.length ; i++){
			if(sql[i] == '$'){
				bool found = false;
				foreach(nameIndex, ref phName ; placeholderNames){
					assert(i + 1 < sql.length && phName.length > 0, "Cannot have a zero-length placeholder");

					if(i + 1 + phName.length <= sql.length && sql[i + 1 .. i + 1 + phName.length] == phName){

						placeholderIndices ~= nameIndex;

						sqlStatement ~= "?";
						i += phName.length;
						found = true;
						break;
					}
				}

				if(found)
					continue;


			}
			sqlStatement ~= sql[i];
		}

		prep = conn.prepare(sqlStatement);
	}

	void setArgs(Variant[] args){
		//assert(args.length == placeholderIndices.length,
		//	"Wrong number of placeholders: Need " ~ placeholderIndices.length.to!string ~ ", "
		//	~ args.length.to!string~" provided for query '" ~ prep.sql ~ "'");

		Variant[] values;
		values.length = placeholderIndices.length;
		foreach(i, valueIndex ; placeholderIndices){
			values[i] = args[valueIndex];
		}

		prep.setArgs(values);
	}
	void setArgs(VT...)(VT args){
		Variant[args.length] values;
		foreach(i, arg ; args){
			static if(is(arg: Variant))
				values[i] = arg;
			else
				values[i] = Variant(arg);
		}
		setArgs(values);
	}

	Prepared prep;
	//alias prep this;

private:
	size_t[] placeholderIndices;
}

// For consistency with mysql-native
PreparedCustom prepareCustom(Connection conn, in string sql, in string[] placeholderNames){
	return PreparedCustom(conn, sql, placeholderNames);
}
ulong exec(T...)(Connection conn, ref PreparedCustom prepared, T args)
	if(T.length > 0 && !is(T[0] == Variant[]))
{
	prepared.setArgs(args);
	return exec(conn, prepared.prep);
}
ResultRange query(T...)(Connection conn, ref PreparedCustom prepared, T args)
	if(T.length > 0 && !is(T[0] == Variant[]) && !is(T[0] == ColumnSpecialization) && !is(T[0] == ColumnSpecialization[]))
{
	prepared.setArgs(args);
	return query(conn, prepared.prep);
}
