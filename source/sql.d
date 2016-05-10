module sql;

public import mysql: MySQLRow;

auto ref SqlPlaceholder(T)(in string ph, T value){
	import std.typecons: tuple;
	import std.conv: to;
	static assert(__traits(compiles, value.to!string), T.stringof~" is not convertible to string");
	return tuple(ph, value);
}

/// example:
///   replacePlaceholders(VT...)(
///     "SELECT * FROM account WHERE name='$NAME' and id=$ID",
///     Placeholder("NAME", "Crom"),
///     Placeholder("ID", 42))
string replacePlaceholders(VT...)(in string query, VT placeholders){
	import std.conv: to;
	import std.array: replace;
	import std.typecons: isTuple;
	import std.traits: ReturnType;

	string ret = query;

	foreach(i, ph ; placeholders){
		static assert(
			   isTuple!(typeof(ph))
			&& ph.length==2
			&& is(typeof(ph) == ReturnType!(SqlPlaceholder!(typeof(ph[1])))),
			"Parameter "~i.to!string~" is not a SqlPlaceholder");

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

unittest{
	import std.typecons: tuple;

	enum queryQuote =       `SELECT * FROM Users WHERE Name ='$NAME' AND Pass ='$PASS'`;
	enum queryDoubleQuote = `SELECT * FROM Users WHERE Name ="$NAME" AND Pass ="$PASS"`;

	assert(
		queryQuote.replacePlaceholders(
			SqlPlaceholder("NAME", `'`),
			SqlPlaceholder("PASS", `''='`))
		== `SELECT * FROM Users WHERE Name ='\'' AND Pass ='\'\'=\''`);

	assert(
		queryDoubleQuote.replacePlaceholders(
			SqlPlaceholder("NAME", `"`),
			SqlPlaceholder("PASS", `""="`))
		== `SELECT * FROM Users WHERE Name ="\"" AND Pass ="\"\"=\""`);

	assert(
		queryDoubleQuote.replacePlaceholders(
			SqlPlaceholder("NAME", `\0x85`),
			SqlPlaceholder("PASS", `\`))
		== `SELECT * FROM Users WHERE Name ="\\0x85" AND Pass ="\\"`);


	assert(!__traits(compiles, queryQuote.replacePlaceholders(5)));
	assert(!__traits(compiles, queryQuote.replacePlaceholders(tuple(5, "test"))));
	assert(!__traits(compiles, queryQuote.replacePlaceholders(tuple("test"))));
	assert(__traits(compiles, queryQuote.replacePlaceholders(tuple("test", 5))));
}