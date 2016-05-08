module nwn2.tlk;

import std.stdint;
import std.string;
import std.conv;

import nwn2.gff : GffNode, GffType;

class StrRefException : Exception{
	public @safe pure nothrow
	this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null){
		super(message, file, line, next);
	}
}
class StrRefNotFoundException : Exception{
	public @safe pure nothrow
	this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null){
		super(message, file, line, next);
	}
}

class StrRefResolver{
	this(Tlk baseTable, Tlk userTable){
		this.baseTable = baseTable;
		this.userTable = userTable;
	}

	const string get(in uint32_t strref){
		if(strref<Tlk.UserTlkIndexOffset){
			if(baseTable !is null)
				return baseTable.get(strref);
			throw new StrRefException("Asking a standard strref and baseTable is null");
		}
		else{
			if(userTable !is null)
				return userTable.get(strref-Tlk.UserTlkIndexOffset);
			throw new StrRefException("Asking a user strref and userTable is null");
		}
	}

	const string get(in GffNode node){
		if(node.type!=GffType.ExoLocString)
			throw new StrRefException("Node '"~node.label~"' is not an ExoLocString");

		auto langID = baseTable.language;
		if(node.exoLocStringID!=uint32_t.max)
			return get(node.exoLocStringID);

		if(node.exoLocStringContainer.length == 0)
			return "";

		if(langID in node.exoLocStringContainer)
			return node.exoLocStringContainer[langID].to!string;

		return node.exoLocStringContainer.values[0].to!string;
	}

	Tlk baseTable;
	Tlk userTable;
}


class Tlk{
	this(in string path){
		import std.file;
		data = path.read();
		header = cast(TlkHeader*)data.ptr;
		strData = cast(TlkStringData*)(data.ptr + TlkHeader.sizeof);
		strEntries = cast(char*)(data.ptr + header.string_entries_offset);
	}

	const string get(uint32_t strref){
		if(strref>=UserTlkIndexOffset-1)
			throw new Exception("Tlk indexex must be lower than "~UserTlkIndexOffset.to!string);

		if(strref>=header.string_count)
			throw new Exception("strref "~strref.to!string~" out of bounds");

		char* str = cast(char*)(cast(size_t)strEntries + strData[strref].offset_to_string);
		uint32_t length = strData[strref].string_size;

		return str[0..length].to!string;
	}

	enum Language{
		English=0,
		French=1,
		German=2,
		Italian=3,
		Spanish=4,
		Polish=5,
		Korean=128,
		ChineseTrad=129,
		ChineseSimp=130,
		Japanese=131,
	}

	@property{
		const Language language(){
			return cast(Language)(header.language_id);
		}
	}

	enum UserTlkIndexOffset = 16777216;

private:
	void[] data;
	TlkHeader* header;
	TlkStringData* strData;
	char* strEntries;


	align(1) struct TlkHeader{
		char[4] file_type;
		char[4] file_version;
		uint32_t language_id;
		uint32_t string_count;
		uint32_t string_entries_offset;
	}
	align(1) struct TlkStringData{
		uint32_t flags;
		char[16] sound_resref;
		uint32_t _volume_variance;
		uint32_t _pitch_variance;
		uint32_t offset_to_string;
		uint32_t string_size;
		float sound_length;
	}

	enum StringFlag{
		TEXT_PRESENT=0x1,
		SND_PRESENT=0x2,
		SNDLENGTH_PRESENT=0x4,
	}


}