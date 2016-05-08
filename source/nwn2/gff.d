module nwn2.gff;


import std.stdint;
import std.string;
import std.conv;
debug import std.stdio: writeln;
import nwn2.tlk;

class GffValueSetException : Exception{
	@safe pure nothrow this(string msg, string f=__FILE__, size_t l=__LINE__, Throwable t=null){
		super(msg, f, l, t);
	}
}
class GffTypeException : Exception{
	@safe pure nothrow this(string msg, string f=__FILE__, size_t l=__LINE__, Throwable t=null){
		super(msg, f, l, t);
	}
}

/// Type of data stored in the GffNode
enum GffType{
	Invalid      = -1,
	Byte         = 0,
	Char         = 1,
	Word         = 2,
	Short        = 3,
	DWord        = 4,
	Int          = 5,
	DWord64      = 6,
	Int64        = 7,
	Float        = 8,
	Double       = 9,
	ExoString    = 10,
	ResRef       = 11,
	ExoLocString = 12,
	Void         = 13,
	Struct       = 14,
	List         = 15
}

template gffTypeToNative(GffType t){
	import std.typecons: Tuple;
	static if(t==GffType.Byte)			alias gffTypeToNative = uint8_t;
	static if(t==GffType.Char)         alias gffTypeToNative = int8_t;
	static if(t==GffType.Word)         alias gffTypeToNative = uint16_t;
	static if(t==GffType.Short)        alias gffTypeToNative = int16_t;
	static if(t==GffType.DWord)        alias gffTypeToNative = uint32_t;
	static if(t==GffType.Int)          alias gffTypeToNative = int32_t;
	static if(t==GffType.DWord64)      alias gffTypeToNative = uint64_t;
	static if(t==GffType.Int64)        alias gffTypeToNative = int64_t;
	static if(t==GffType.Float)        alias gffTypeToNative = float;
	static if(t==GffType.Double)       alias gffTypeToNative = double;
	static if(t==GffType.ExoString)    alias gffTypeToNative = string;
	static if(t==GffType.ResRef)       alias gffTypeToNative = string;// length<=32
	static if(t==GffType.ExoLocString) alias gffTypeToNative = Tuple!(uint32_t,"strref", string[int32_t],"strings");
	static if(t==GffType.Void)         alias gffTypeToNative = void[];
	static if(t==GffType.Struct)       alias gffTypeToNative = GffNode[string];
	static if(t==GffType.List)         alias gffTypeToNative = GffNode[];
}

struct GffNode{
	this(GffType t, string lbl=null){
		m_type = t;
		label = lbl;
	}

	string label;

	@property const GffType type(){return m_type;}
	package GffType m_type = GffType.Invalid;

	/// Convert the node value to a certain type.
	/// If the type is string, any type of value gets converted into string. Structs and lists are not expanded.
	const ref auto to(T)(){
		import std.traits;
		static if(__traits(isArithmetic, T)){
			switch(type) with(GffType){
				case Byte, Char, Word, Short, DWord, Int, DWord64, Int64:
					return cast(T)simpleTypeContainer;
				default: break;
			}
		}
		else static if(__traits(isFloating, T)){
			switch(type) with(GffType){
				case Float, Double:
					return cast(T)simpleTypeContainer;
				default: break;
			}
		}
		else static if(isSomeString!T){
			import std.string: format;
			final switch(type) with(GffType){
				case Invalid: assert(0, "type has not been set");
				//unsigned int
				case Byte, Word, DWord, DWord64:
					return simpleTypeContainer.to!T;
				//signed int
				case Short, Int, Int64:
					return (*cast(int64_t*)(&simpleTypeContainer)).to!T;
				//special int
				case Char:
					return (*cast(char*)(&simpleTypeContainer)).to!T;
				//float
				case Float, Double:
					return (*cast(double*)(&simpleTypeContainer)).to!T;
				//string
				case ExoString, ResRef:
					return stringContainer.to!T;
				//special string
				case ExoLocString:
					if(exoLocStringID!=uint32_t.max)
						return ("{{STRREF:"~exoLocStringID.to!string~"}}").to!T;
					else{
						if(exoLocStringContainer.length>0)
							return exoLocStringContainer.values[0].to!T;
						return "{{INVALID_LOCSTRING}}".to!T;
					}
				//raw
				case Void:
					string ret = "0x";
					foreach(i, b ; cast(ubyte[])rawContainer){
						ret ~= format("%02x%s", b, i%2? " ":null);
					}
					return ret;
				//aggregated values
				case Struct:
					//TODO
					return "{{Struct}}";
				case List:
					//TODO
					return "{{List("~aggrContainer.length.to!string~")}}";
			}
		}
		else static if(is(T==void[]) || is(T==ubyte[]) || is(T==byte[])){
			if(type==GffType.Void)
				return cast(T)rawContainer;
		}
		//else static if(is(T==GffNode[string])){
		//	if(type==GffType.Struct)
		//		return structContainer;
		//}
		else static if(is(T==GffNode[])){
			if(type==GffType.List || type==GffType.Struct)
				return aggrContainer;
		}
		assert(0, "Incompatible type conversion from "~type.to!string~" to "~T.stringof);
	}

	void opAssign(T)(T rhs) if(!is(T==GffNode)){
		import std.traits;

		void assignSimpleType(GffType TYPE, T)(T rhs){
			*cast(gffTypeToNative!TYPE*)&simpleTypeContainer = rhs.to!(gffTypeToNative!TYPE);
		}

		final switch(type) with(GffType){
			case Invalid: assert(0, "type has not been set");
			case Byte:
				static if(__traits(isArithmetic, T)) return assignSimpleType!Byte(rhs);
				else break;
			case Char:
				static if(__traits(isArithmetic, T) || isSomeChar!T) return assignSimpleType!Char(rhs);
				else break;
			case Word:
				static if(__traits(isArithmetic, T)) return assignSimpleType!Word(rhs);
				else break;
			case Short:
				static if(__traits(isArithmetic, T)) return assignSimpleType!Short(rhs);
				else break;
			case DWord:
				static if(__traits(isArithmetic, T)) return assignSimpleType!DWord(rhs);
				else break;
			case Int:
				static if(__traits(isArithmetic, T)) return assignSimpleType!Int(rhs);
				else break;
			case DWord64:
				static if(__traits(isArithmetic, T)) return assignSimpleType!DWord64(rhs);
				else break;
			case Int64:
				static if(__traits(isArithmetic, T)) return assignSimpleType!Int64(rhs);
				else break;
			case Float:
				static if(__traits(isFloating, T))   return assignSimpleType!Float(rhs);
				else break;
			case Double:
				static if(__traits(isFloating, T))   return assignSimpleType!Double(rhs);
				else break;
			case ExoString:
				static if(isSomeString!T){
					stringContainer = rhs.to!string;
					return;
				}
				else break;
			case ResRef:
				static if(isSomeString!T){
					if(rhs.length > 32) throw new GffValueSetException("string is too long for a ResRef (32 characters limit)");
					stringContainer = rhs.to!string;
					return;
				}
				else break;
			case ExoLocString:
				static if(__traits(isArithmetic, T)){
					//set strref
					exoLocStringID = rhs.to!uint32_t;
					return;
				}
				else static if(isAssociativeArray!T
					&& __traits(isArithmetic, KeyType!T) && isSomeString!(ValueType!T)){
					//set strings
					exoLocStringContainer.clear();
					exoLocStringContainerOrder.length = 0;
					foreach(key, value ; rhs){
						exoLocStringContainer[key] = value.to!string;
						exoLocStringContainerOrder ~= key.to!int;
					}
					return;
				}
				else break;
			case Void:
				static if(is(T==void[]) || is(T==ubyte[]) || is(T==byte[])){
					rawContainer = rhs.dup;
					return;
				}
				else break;
			case Struct:
				static if(is(T==GffNode[])){
					aggrContainer.clear();
					foreach(ref s ; rhs){
						structLabelMap[s.label] = aggrContainer.length;
						aggrContainer ~= s;
					}
					return;
				}
				else static if(isAssociativeArray!T && is(ValueType!T==GffNode)){
					assert(0, "To set a Struct GffNode, use a GffStruct[]. Keys will be automatically set using the node labels");
				}
				else break;
			case List:
				static if(is(T==GffNode[])){
					aggrContainer = rhs.dup;
					return;
				}
				else break;
		}

		assert(0, "Cannot set node of type "~type.to!string~" with value of type "~T.stringof);
	}
	unittest{
		import std.exception;

		auto node = GffNode(GffType.Byte);
		assertThrown!ConvOverflowException(node = -1);
		assertThrown!ConvOverflowException(node = 256);
		assertThrown!Error(node = "somestring");
		node = 42;
		assert(node.to!int == 42);

		node = GffNode(GffType.Char);
		assertThrown!ConvOverflowException(node = -129);
		assertThrown!ConvOverflowException(node = 128);
		assertThrown!Error(node = "somestring");
		node = 'a';
		node = 'z';
		assert(node.to!char == 'z');

		node = GffNode(GffType.ExoString);
		node = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";
		node = "Hello";
		assert(node.to!string == "Hello");

		node = GffNode(GffType.ResRef);
		assertThrown!GffValueSetException(node = "This text is longer than 32 characters");
		assertThrown!Error(node = 42);
		node = "HelloWorld";
		assert(node.to!string == "HelloWorld");

		node = GffNode(GffType.ExoLocString);
		node = 1337;//set strref
		node = [0: "English guy", 1: "English girl", 2: "French guy"];
		//TODO: test those values back

		node = GffNode(GffType.Void);
		ubyte[] data = [0,1,2,3,4,5,6];
		node = data;
		assert(node.to!(ubyte[])[3] == 3);

		//TODO: test structs & lists
	}

	const ref const(GffNode) opIndex(in string label){
		assert(type==GffType.Struct, "Not a struct");
		return aggrContainer[structLabelMap[label]];
	}
	const ref const(GffNode) opIndex(in size_t index){
		//TODO: get localized strings
		assert(type==GffType.List, "Not a list");
		return aggrContainer[index];
	}

	ref GffNode opIndex(in string label){
		assert(type==GffType.Struct, "Not a struct");
		return aggrContainer[structLabelMap[label]];
	}
	ref GffNode opIndex(in size_t index){
		assert(type==GffType.List, "Not a list");
		return aggrContainer[index];
	}

	ref GffNode opDispatch(string key)(){
		return this[key];
	}

	/// Produces a readable string of the node and its children
	const string toPrettyString(){

		string toPrettyStringInternal(const(GffNode)* node, string tabs){
			import std.string: leftJustify;

			if(node.type == GffType.Struct){
				string ret = tabs~"("~node.type.to!string~")\n";
				foreach(ref childNode ; node.aggrContainer){
					ret ~= toPrettyStringInternal(&childNode, tabs~"   | ");
				}
				return ret;
			}
			else if(node.type == GffType.List){
				string ret = tabs~node.label.leftJustify(16)~": ("~node.type.to!string~")\n";
				foreach(ref childNode ; node.aggrContainer){
					ret ~= toPrettyStringInternal(&childNode, tabs~"   | ");
				}
				return ret;
			}
			else{
				return tabs~node.label.leftJustify(16)~": "~node.to!string~" ("~node.type.to!string~")\n";
			}
		}


		return toPrettyStringInternal(&this, "");
	}


package:
	void[] rawContainer;
	uint64_t simpleTypeContainer;
	string stringContainer;
	GffNode[] aggrContainer;
	size_t[string] structLabelMap;
	uint32_t exoLocStringID;
	string[uint32_t] exoLocStringContainer;
	uint32_t[] exoLocStringContainerOrder;
	uint32_t structType = 0;
}

class Gff{

	this(){}

	this(in string path){
		import std.file : read;
		this(path.read());
	}
	this(in void[] data){
		auto parser = Parser(data.ptr);
		version(gff_verbose) parser.printData();

		import std.string: stripRight;
		m_fileType = parser.headerPtr.file_type.stripRight;
		m_fileVersion = parser.headerPtr.file_version.stripRight;
		firstNode = parser.buildNodeFromStruct(data, 0);
	}

	@property{
		const string fileType(){return m_fileType;}
		void fileType(in string type){
			if(type.length>4)
				throw new GffValueSetException("fileType length must be <= 4");
			m_fileType = type;
		}
		const string fileVersion(){return m_fileVersion;}
		void fileVersion(in string ver){
			if(ver.length>4)
				throw new GffValueSetException("fileVersion length must be <= 4");
			m_fileVersion = ver;
		}
	}


	alias firstNode this;
	GffNode firstNode;


	void[] serialize(){
		Serializer serializer;
		serializer.registerStruct(&firstNode);
		return serializer.serialize(m_fileType, m_fileVersion);
	}

private:
	string m_fileType, m_fileVersion;

	align(1) struct GffHeader{
		char[4]  file_type;
		char[4]  file_version;
		uint32_t struct_offset;
		uint32_t struct_count;
		uint32_t field_offset;
		uint32_t field_count;
		uint32_t label_offset;
		uint32_t label_count;
		uint32_t field_data_offset;
		uint32_t field_data_count;
		uint32_t field_indices_offset;
		uint32_t field_indices_count;
		uint32_t list_indices_offset;
		uint32_t list_indices_count;
	}
	align(1) struct GffStruct{
		uint32_t type;
		uint32_t data_or_data_offset;
		uint32_t field_count;
	}
	align(1) struct GffField{
		uint32_t type;
		uint32_t label_index;
		uint32_t data_or_data_offset;
	}
	align(1) struct GffLabel{
		char[16] value;
	}
	align(1) struct GffFieldData{
		uint8_t first_data;//First byte of data. Other follows
	}
	align(1) struct GffFieldIndices{
		uint32_t field_index;
	}
	align(1) struct GffListIndices{
		uint32_t length;
		uint32_t first_struct_index;
	}

	struct Parser{
		@disable this();
		this(const(void)* rawData){
			headerPtr       = cast(immutable GffHeader*)      (rawData);
			structsPtr      = cast(immutable GffStruct*)      (rawData + headerPtr.struct_offset);
			fieldsPtr       = cast(immutable GffField*)       (rawData + headerPtr.field_offset);
			labelsPtr       = cast(immutable GffLabel*)       (rawData + headerPtr.label_offset);
			fieldDatasPtr   = cast(immutable GffFieldData*)   (rawData + headerPtr.field_data_offset);
			fieldIndicesPtr = cast(immutable GffFieldIndices*)(rawData + headerPtr.field_indices_offset);
			listIndicesPtr  = cast(immutable GffListIndices*) (rawData + headerPtr.list_indices_offset);
		}

		immutable GffHeader*       headerPtr;
		immutable GffStruct*       structsPtr;
		immutable GffField*        fieldsPtr;
		immutable GffLabel*        labelsPtr;
		immutable GffFieldData*    fieldDatasPtr;
		immutable GffFieldIndices* fieldIndicesPtr;
		immutable GffListIndices*  listIndicesPtr;

		immutable(GffStruct*) getStruct(in void[] rawData, size_t index){
			assert(index < headerPtr.struct_count, "index "~index.to!string~" out of bounds");
			return &structsPtr[index];
		}
		immutable(GffField*) getField(in void[] rawData, size_t index){
			assert(index < headerPtr.field_count, "index "~index.to!string~" out of bounds");
			return &fieldsPtr[index];
		}
		immutable(GffLabel*) getLabel(in void[] rawData, size_t index){
			assert(index < headerPtr.label_count, "index "~index.to!string~" out of bounds");
			return &labelsPtr[index];
		}
		immutable(GffFieldData*) getFieldData(in void[] rawData, size_t offset){
			assert(offset < headerPtr.field_data_count, "offset "~offset.to!string~" out of bounds");
			return cast(immutable GffFieldData*)(cast(void*)fieldDatasPtr + offset);
		}
		immutable(GffFieldIndices*) getFieldIndices(in void[] rawData, size_t offset){
			assert(offset < headerPtr.field_indices_count, "offset "~offset.to!string~" out of bounds");
			return cast(immutable GffFieldIndices*)(cast(void*)fieldIndicesPtr + offset);
		}
		immutable(GffListIndices*) getListIndices(in void[] rawData, size_t offset){
			assert(offset < headerPtr.list_indices_count, "offset "~offset.to!string~" out of bounds");
			return cast(immutable GffListIndices*)(cast(void*)listIndicesPtr + offset);
		}

		version(gff_verbose) string gff_verbose_rtIndent;

		GffNode buildNodeFromStruct(in void[] rawData, in size_t structIndex){
			auto ret = GffNode(GffType.Struct);

			buildNodeFromStructInPlace(rawData, structIndex, &ret);

			return ret;
		}

		void buildNodeFromStructInPlace(in void[] rawData, in size_t structIndex, GffNode* destNode){

			destNode.m_type = GffType.Struct;

			auto s = getStruct(rawData, structIndex);
			destNode.structType = s.type;

			version(gff_verbose){
				writeln(gff_verbose_rtIndent, "Parsing struct: id=",structIndex,
					" dodo=", s.data_or_data_offset,
					" field_count=", s.field_count,
					" type=",s.type);
				gff_verbose_rtIndent ~= "│ ";
			}

			if(s.field_count==1){
				auto n = buildNodeFromField(rawData, s.data_or_data_offset);

				destNode.structLabelMap[n.label] = destNode.aggrContainer.length;
				destNode.aggrContainer ~= n;
			}
			else if(s.field_count > 1){
				auto fi = getFieldIndices(rawData, s.data_or_data_offset);
				foreach(i ; 0 .. s.field_count){
					auto n = buildNodeFromField(rawData, fi[i].field_index);

					destNode.structLabelMap[n.label] = destNode.aggrContainer.length;
					destNode.aggrContainer ~= n;
				}
			}

			version(gff_verbose) gff_verbose_rtIndent = gff_verbose_rtIndent[0..$-4];

		}

		GffNode buildNodeFromField(in void[] rawData, in size_t fieldIndex){
			GffNode ret;
			try{
				import std.conv : to;
				immutable f = getField(rawData, fieldIndex);

				immutable lbl = getLabel(rawData, f.label_index).value;
				if(lbl[$-1]=='\0') ret.label = lbl.ptr.fromStringz.idup;
				else               ret.label = lbl.idup;

				ret.m_type = cast(GffType)f.type;

				version(gff_verbose){
					writeln(gff_verbose_rtIndent, "Parsing  field: '", ret.label,
						"' (",ret.type,
						", id=",fieldIndex,
						", dodo:",f.data_or_data_offset,")");
					gff_verbose_rtIndent ~= "│ ";
				}

				final switch(ret.type) with(GffType){
					case Invalid: assert(0, "type has not been set");
					case Byte, Char, Word, Short, DWord, Int, Float:
						ret.simpleTypeContainer = cast(uint64_t)f.data_or_data_offset;
						break;
					case DWord64:
						immutable d = getFieldData(rawData, f.data_or_data_offset);
						ret.simpleTypeContainer = *(cast(uint64_t*)d);
						break;
					case Int64:
						immutable d = getFieldData(rawData, f.data_or_data_offset);
						ret.simpleTypeContainer = *(cast(int64_t*)d);//TODO why int64_t ?
						break;
					case Double:
						immutable d = getFieldData(rawData, f.data_or_data_offset);
						ret.simpleTypeContainer = *(cast(uint64_t*)d);
						break;
					case ExoString:
						immutable data = getFieldData(rawData, f.data_or_data_offset);
						immutable size = cast(immutable uint32_t*)data;
						immutable chars = cast(immutable char*)(data+uint32_t.sizeof);

						ret.stringContainer = chars[0..*size].idup;
						break;
					case ResRef:
						immutable data = getFieldData(rawData, f.data_or_data_offset);
						immutable size = cast(immutable uint8_t*)data;
						immutable chars = cast(immutable char*)(data+uint8_t.sizeof);

						ret.stringContainer = chars[0..*size].idup;
						break;

					case ExoLocString:
						immutable data = getFieldData(rawData, f.data_or_data_offset);
						//immutable total_size = cast(uint32_t*)data;
						immutable str_ref = cast(immutable uint32_t*)(data+uint32_t.sizeof);
						immutable str_count = cast(immutable uint32_t*)(data+2*uint32_t.sizeof);
						auto sub_str = cast(void*)(data+3*uint32_t.sizeof);

						ret.exoLocStringID = *str_ref;

						foreach(i ; 0 .. *str_count){
							immutable id = cast(immutable int32_t*)sub_str;
							immutable length = cast(immutable int32_t*)(sub_str+uint32_t.sizeof);
							immutable str = cast(immutable char*)(sub_str+2*uint32_t.sizeof);

							ret.exoLocStringContainerOrder ~= *id;
							ret.exoLocStringContainer[*id] = str[0..*length].idup;
							sub_str += 2*uint32_t.sizeof + char.sizeof*(*length);
						}
						break;

					case Void:
						immutable data = getFieldData(rawData, f.data_or_data_offset);
						immutable size = cast(immutable uint32_t*)data;
						immutable dataVoid = cast(immutable void*)(data+uint32_t.sizeof);

						ret.rawContainer = dataVoid[0..*size].dup;
						break;

					case Struct:
						buildNodeFromStructInPlace(rawData, f.data_or_data_offset, &ret);
						break;

					case List:
						auto li = getListIndices(rawData, f.data_or_data_offset);
						if(li.length>0){
							immutable uint32_t* indices = &li.first_struct_index;

							ret.aggrContainer.reserve(li.length);
							foreach(i ; 0 .. li.length){
								ret.aggrContainer ~= buildNodeFromStruct(rawData, indices[i]);
							}
						}
						break;
				}
				version(gff_verbose) gff_verbose_rtIndent = gff_verbose_rtIndent[0..$-4];

				return ret;
			}
			catch(Throwable t){
				if(t.msg.length==0 || t.msg[0] != '@'){
					t.msg = "@"~ret.label~": "~t.msg;
				}
				throw t;
			}
		}

		version(gff_verbose)
		void printData(){
			import std.string: center, rightJustify, toUpper;
			import std.algorithm: chunkBy;
			import std.stdio: write;

			void printTitle(in string title){
				writeln("============================================================");
				writeln(title.toUpper.center(60));
				writeln("============================================================");
			}
			void printByteArray(in void* byteArray, size_t length){
				foreach(i ; 0..20){
					if(i==0)write("    / ");
					write(i.to!string.rightJustify(4, '_'));
				}
				writeln();
				foreach(i ; 0..length){
					auto ptr = cast(void*)byteArray + i;
					if(i%20==0)write((i/10).to!string.rightJustify(3), " > ");
					write((*cast(ubyte*)ptr).to!string.rightJustify(4));
					if(i%20==19)writeln();
				}
				writeln();
			}

			printTitle("header");
			with(headerPtr){
				writeln("'",file_type, "'    '",file_version,"'");
				writeln("struct: ",struct_offset," ",struct_count);
				writeln("field: ",field_offset," ",field_count);
				writeln("label: ",label_offset," ",label_count);
				writeln("field_data: ",field_data_offset," ",field_data_count);
				writeln("field_indices: ",field_indices_offset," ",field_indices_count);
				writeln("list_indices: ",list_indices_offset," ",list_indices_count);
			}
			printTitle("structs");
			foreach(id, ref a ; structsPtr[0..headerPtr.struct_count])
				writeln(id.to!string.rightJustify(4), " > ",a);

			printTitle("fields");
			foreach(id, ref a ; fieldsPtr[0..headerPtr.field_count])
				writeln(id.to!string.rightJustify(4), " > ",a);

			printTitle("labels");
			foreach(id, ref a ; labelsPtr[0..headerPtr.label_count])
				writeln(id.to!string.rightJustify(4), " > ",a);

			printTitle("field data");
			printByteArray(fieldDatasPtr, headerPtr.field_data_count);

			printTitle("field indices");
			printByteArray(fieldIndicesPtr, headerPtr.field_indices_count);

			printTitle("list indices");
			printByteArray(listIndicesPtr, headerPtr.list_indices_count);
		}
	}

	struct Serializer{
		GffHeader   header;
		GffStruct[] structs;
		GffField[]  fields;
		GffLabel[]  labels;
		void[]      fieldDatas;
		void[]      fieldIndices;
		void[]      listIndices;

		version(gff_verbose) string gff_verbose_rtIndent;


		uint32_t registerStruct(const(GffNode)* node){
			assert(node.type == GffType.Struct);

			immutable createdStructIndex = cast(uint32_t)structs.length;
			structs ~= GffStruct();

			immutable fieldCount = cast(uint32_t)node.aggrContainer.length;
			structs[createdStructIndex].type = node.structType;
			structs[createdStructIndex].field_count = fieldCount;


			version(gff_verbose){
				writeln(gff_verbose_rtIndent,
					"Registering struct id=",createdStructIndex,
					" from node '",node.label,"'",
					"(type=",structs[createdStructIndex].type,", fields_count=",structs[createdStructIndex].field_count,")");
				gff_verbose_rtIndent ~= "│ ";
			}

			if(fieldCount == 1){
				//index in field array
				immutable fieldId = registerField(&node.aggrContainer[0]);
				structs[createdStructIndex].data_or_data_offset = fieldId;
			}
			else if(fieldCount>1){
				//byte offset in field indices array
				immutable fieldIndicesIndex = cast(uint32_t)fieldIndices.length;
				structs[createdStructIndex].data_or_data_offset = fieldIndicesIndex;

				fieldIndices.length += uint32_t.sizeof*fieldCount;
				foreach(i, ref field ; node.aggrContainer){

					immutable fieldId = registerField(&field);

					immutable offset = fieldIndicesIndex + +i*uint32_t.sizeof;
					fieldIndices[offset..offset+uint32_t.sizeof] = (cast(uint32_t*)&fieldId)[0..1];
				}
			}
			else{
				structs[createdStructIndex].data_or_data_offset = -1;
			}

			version(gff_verbose) gff_verbose_rtIndent = gff_verbose_rtIndent[0..$-4];
			return createdStructIndex;
		}
		uint32_t registerField(const(GffNode)* node){
			immutable createdFieldIndex = cast(uint32_t)fields.length;
			fields ~= GffField(node.type);

			version(gff_verbose){
				writeln(gff_verbose_rtIndent, "Registering  field: '", node.label,
					"' (",node.type,
					", id=",createdFieldIndex,
					", value=",node.to!string,")");
				gff_verbose_rtIndent ~= "│ ";
			}

			assert(node.label.length <= 16, "Label too long");//TODO: Throw exception on GffNode.label set

			char[16] label = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
			label[0..node.label.length] = node.label.dup;
			//TODO: this may be totally stupid and complexity too high
			bool labelFound = false;
			foreach(i, ref s ; labels){
				if(s.value == label){
					labelFound = true;
					fields[createdFieldIndex].label_index = cast(uint32_t)i;
					break;
				}
			}
			if(!labelFound){
				fields[createdFieldIndex].label_index = cast(uint32_t)labels.length;
				labels ~= GffLabel(label);
			}

			final switch(node.type) with(GffType){
				case Invalid: assert(0, "type has not been set");
				case Byte, Char, Word, Short, DWord, Int, Float:
					//cast is ok because all those types are <= 32bit
					fields[createdFieldIndex].data_or_data_offset = *cast(uint32_t*)&node.simpleTypeContainer;
					break;
				case DWord64, Int64, Double:
					//stored in fieldDatas
					fields[createdFieldIndex].data_or_data_offset = cast(uint32_t)fieldDatas.length;
					fieldDatas ~= (&node.simpleTypeContainer)[0..1].dup;
					break;
				case ExoString:
					immutable stringLength = cast(uint32_t)node.stringContainer.length;

					fields[createdFieldIndex].data_or_data_offset = cast(uint32_t)fieldDatas.length;
					fieldDatas ~= (&stringLength)[0..1].dup;
					fieldDatas ~= (cast(void*)node.stringContainer.ptr)[0..stringLength].dup;
					break;
				case ResRef:
					assert(node.stringContainer.length<=32, "Resref too long (max length: 32 characters)");//TODO: Throw exception on GffNode value set

					immutable stringLength = cast(uint8_t)node.stringContainer.length;

					fields[createdFieldIndex].data_or_data_offset = cast(uint32_t)fieldDatas.length;
					fieldDatas ~= (&stringLength)[0..1].dup;
					fieldDatas ~= (cast(void*)node.stringContainer.ptr)[0..stringLength].dup;
					break;
				case ExoLocString:
					immutable fieldDataIndex = fieldDatas.length;
					fields[createdFieldIndex].data_or_data_offset = cast(uint32_t)fieldDataIndex;

					//total size
					fieldDatas ~= [cast(uint32_t)0];

					immutable strref = cast(uint32_t)node.exoLocStringID;
					fieldDatas ~= (&strref)[0..1].dup;

					immutable strcount = cast(uint32_t)node.exoLocStringContainer.length;
					fieldDatas ~= (&strcount)[0..1].dup;

					foreach(key ; node.exoLocStringContainerOrder){
						immutable str = node.exoLocStringContainer[key];

						fieldDatas ~= (cast(int32_t*)&key)[0..1].dup;//string id

						immutable length = cast(int32_t)str.length;
						fieldDatas ~= (&length)[0..1].dup;

						fieldDatas ~= str.ptr[0..length].dup;
					}

					//total size
					immutable totalSize = cast(uint32_t)(fieldDatas.length-fieldDataIndex) - 4;//totalSize does not count first 4 bytes
					fieldDatas[fieldDataIndex..fieldDataIndex+4] = (&totalSize)[0..1].dup;
					break;
				case Void:
					auto dataLength = cast(uint32_t)node.rawContainer.length;
					fields[createdFieldIndex].data_or_data_offset = cast(uint32_t)fieldDatas.length;
					fieldDatas ~= (&dataLength)[0..1];
					fieldDatas ~= node.rawContainer;
					break;
				case Struct:
					immutable structId = registerStruct(node);
					fields[createdFieldIndex].data_or_data_offset = structId;
					break;
				case List:
					immutable createdListOffset = cast(uint32_t)listIndices.length;
					fields[createdFieldIndex].data_or_data_offset = createdListOffset;

					uint32_t listLength = cast(uint32_t)node.aggrContainer.length;
					listIndices ~= (&listLength)[0..1];
					listIndices.length += listLength * uint32_t.sizeof;
					if(node.aggrContainer !is null){
						foreach(i, ref listField ; node.aggrContainer){
							immutable offset = createdListOffset+uint32_t.sizeof*(i+1);

							uint32_t structIndex = registerStruct(&listField);
							listIndices[offset..offset+uint32_t.sizeof] = (&structIndex)[0..1];
						}

					}
					break;
			}
			version(gff_verbose) gff_verbose_rtIndent = gff_verbose_rtIndent[0..$-4];
			return createdFieldIndex;
		}

		void[] serialize(in string fileType, in string fileVersion){
			assert(fileType.length <= 4);
			header.file_type = "    ";
			header.file_type[0..fileType.length] = fileType.dup;

			assert(fileVersion.length <= 4);
			header.file_version = "    ";
			header.file_version[0..fileVersion.length] = fileVersion.dup;

			uint32_t offset = cast(uint32_t)GffHeader.sizeof;

			header.struct_offset = offset;
			header.struct_count = cast(uint32_t)structs.length;
			offset += GffStruct.sizeof * structs.length;

			header.field_offset = offset;
			header.field_count = cast(uint32_t)fields.length;
			offset += GffField.sizeof * fields.length;

			header.label_offset = offset;
			header.label_count = cast(uint32_t)labels.length;
			offset += GffLabel.sizeof * labels.length;

			header.field_data_offset = offset;
			header.field_data_count = cast(uint32_t)fieldDatas.length;
			offset += fieldDatas.length;

			header.field_indices_offset = offset;
			header.field_indices_count = cast(uint32_t)fieldIndices.length;
			offset += fieldIndices.length;

			header.list_indices_offset = offset;
			header.list_indices_count = cast(uint32_t)listIndices.length;
			offset += listIndices.length;


			version(unittest) auto offsetCheck = 0;
			void[] data;
			data.reserve(offset);
			data ~= (&header)[0..1];
			version(unittest) offsetCheck += GffHeader.sizeof;
			version(unittest) assert(data.length == offsetCheck);
			data ~= structs;
			version(unittest) offsetCheck += structs.length * GffStruct.sizeof;
			version(unittest) assert(data.length == offsetCheck);
			data ~= fields;
			version(unittest) offsetCheck += fields.length * GffStruct.sizeof;
			version(unittest) assert(data.length == offsetCheck);
			data ~= labels;
			version(unittest) offsetCheck += labels.length * GffLabel.sizeof;
			version(unittest) assert(data.length == offsetCheck);
			data ~= fieldDatas;
			version(unittest) offsetCheck += fieldDatas.length;
			version(unittest) assert(data.length == offsetCheck);
			data ~= fieldIndices;
			version(unittest) offsetCheck += fieldIndices.length;
			version(unittest) assert(data.length == offsetCheck);
			data ~= listIndices;
			version(unittest) offsetCheck += listIndices.length;
			version(unittest) assert(data.length == offsetCheck);

			assert(data.length == offset);
			return data;
		}
	}
}