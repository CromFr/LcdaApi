module sql;

import std.typecons;
public import mysql: MySQLRow;

//TODO: T is not infered
alias Placeholder(T) = Tuple!(string, T);

//example:
// replacePlaceholders(VT...)(
//	"SELECT * FROM account WHERE name='$NAME' and id=$ID", Placeholder!("NAME", "Crom"), Placeholder!("ID", 42))
string replacePlaceholders(VT...)(in string query, VT placeholders){
	import std.conv : to;
	import std.array : replace;

	string ret = query;

	foreach(ph ; placeholders){
		ret = ret.replace("$"~ph[0], ph[1].to!string.escapeString);
	}
	return ret;
}


string escapeString(in string str){
	// http://dev.mysql.com/doc/refman/5.7/en/mysql-real-escape-string.html
	// TODO: find better doc
	string ret;
	foreach(c ; str){
		switch(c){
			case '\\': ret ~= `\\`; break;
			case '\'': ret ~= `\'`; break;
			case '\"': ret ~= `\"`; break;
			default: ret ~= c;
		}
	}
	return ret;
}