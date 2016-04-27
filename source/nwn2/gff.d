module nwn2.gff;


import std.stdint;
import std.string;
import std.conv;
debug import std.stdio: writeln;
import nwn2.tlk;


struct GffNode{
	string label;
	Type type;

	ref auto to(T)(){
		import std.traits;
		static if(__traits(isArithmetic, T)){
			switch(type) with(Type){
				case Byte, Char, Word, Short, DWord, Int, DWord64, Int64:
					return cast(T)simpleTypeContainer;
				default: break;
			}
		}
		else static if(__traits(isFloating, T)){
			switch(type) with(Type){
				case Float, Double:
					return cast(T)simpleTypeContainer;
				default: break;
			}
		}
		else static if(isSomeString!T){
			if(type==Type.ExoString || type==Type.ResRef)
				return stringContainer.to!T;
			else if(type==Type.ExoLocString){
				if(exoLocStringID!=uint32_t.max)
					return ("{{STRREF:"~exoLocStringID.to!string~"}}").to!T;
				else{
					return exoLocStringContainer.values[0].to!T;
				}
			}
		}
		else static if(is(T==void[])){
			if(type==Type.Void)
				return rawContainer;
		}
		else static if(is(T==GffNode[string])){
			if(type==Type.Struct)
				return structContainer;
		}
		else static if(is(T==GffNode[])){
			if(type==Type.List)
				return listContainer;
			else if(type==Type.Struct)
				return structContainer.values;
		}
		assert(0, "Incompatible type conversion from "~type.to!string~" to "~T.stringof);
	}

	GffNode opIndex(in string label){
		assert(type==Type.Struct, "Not a struct");
		return structContainer[label];
	}
	GffNode opIndex(in size_t index){
		assert(type==Type.List, "Not a list");
		return listContainer[index];
	}

	enum Type{
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


package:
	void[] rawContainer;
	uint64_t simpleTypeContainer;
	string stringContainer;
	GffNode[string] structContainer;
	GffNode[] listContainer;
	uint32_t exoLocStringID;
	string[int] exoLocStringContainer;
}

class Gff{

	this(in string path){
		import std.file : read;
		this(path.read());
	}
	this(in void[] data){
		firstNode = buildNodeFromStruct(data, 0);
	}

	alias firstNode this;
	GffNode firstNode;


	void[] serialize(){

		Serializer serializer;
		serializer.registerStruct(firstNode);
		return serializer.serialize(cast(char[4])"ANY ", cast(char[4])"V3.2 ");
	}

private:
	struct Serializer{
		GffHeader   header;
		GffStruct[] structs;
		GffField[]  fields;
		GffLabel[]  labels;
		void[]      fieldDatas;
		void[]      fieldIndices;
		void[]      listIndices;


		uint32_t registerStruct(ref GffNode node){
			assert(node.type == GffNode.Type.Struct);

			immutable createdStructIndex = cast(uint32_t)structs.length;
			uint32_t type = structs.length==0? 0xFFFF_FFFF : 0;//TODO: what is the type for?
			uint32_t field_count = cast(uint32_t)node.structContainer.length;

			structs ~= GffStruct(type, 0, field_count);

			if(field_count == 1){
				//index in field array
				structs[createdStructIndex].data_or_data_offset = registerField(
					node.structContainer.values[0]
				);
			}
			else{
				//byte offset in field indices array
				structs[createdStructIndex].data_or_data_offset = registerList(
					node.structContainer.values[0]
				);
			}
			return createdStructIndex;
		}
		uint32_t registerList(ref GffNode node){
			assert(node.type == GffNode.Type.List);

			immutable createdListOffset = cast(uint32_t)listIndices.length;

			uint32_t listLength = cast(uint32_t)node.listContainer.length;
			listIndices ~= (&listLength)[0..uint32_t.sizeof];
			listIndices.length += listLength * uint32_t.sizeof;

			foreach(i, ref fieldNode ; node.listContainer){
				immutable offset = createdListOffset+uint32_t.sizeof;

				uint32_t fieldIndex = registerField(fieldNode);
				listIndices[offset..offset+uint32_t.sizeof] = (&fieldIndex)[0..uint32_t.sizeof];
			}

			return createdListOffset;
		}
		uint32_t registerField(ref GffNode node){
			immutable createdFieldIndex = cast(uint32_t)fields.length;
			fields ~= GffField(node.type);

			assert(node.label.length <= 16, "Label too long");//TODO: Throw exception on GffNode.label set

			//TODO: this may be totally stupid and complexity too high
			import std.algorithm: equal;
			bool labelFound = false;
			foreach(i, ref s ; labels){
				if(s.value == node.label){
					labelFound = true;
					fields[createdFieldIndex].label_index = cast(uint32_t)i;
					break;
				}
			}
			if(!labelFound){
				fields[createdFieldIndex].label_index = cast(uint32_t)labels.length;
				char[16] label;
				label[0..node.label.length] = node.label.dup;
				labels ~= GffLabel(label);
			}

			final switch(node.type) with(GffNode.Type){
				case Byte, Char, Word, Short, DWord, Int, Float:{
					//cast is ok because all those types are <= 32bit
					fields[createdFieldIndex].data_or_data_offset = *cast(uint32_t*)&node.simpleTypeContainer;
				}break;
				case DWord64, Int64, Double:{
					//stored in fieldDatas
					fields[createdFieldIndex].data_or_data_offset = cast(uint32_t)fieldDatas.length;
					fieldDatas ~= (&node.simpleTypeContainer)[0..uint64_t.sizeof];
				}break;
				case ExoString:{
					auto stringLength = node.stringContainer.length;

					fields[createdFieldIndex].data_or_data_offset = cast(uint32_t)fieldDatas.length;
					fieldDatas ~= (&stringLength)[0..uint32_t.sizeof];
					fieldDatas ~= (cast(void*)node.stringContainer.ptr)[0..stringLength];
				}break;
				case ResRef:{
					auto stringLength = node.stringContainer.length;
					assert(stringLength<=uint8_t.max, "ExoString too long");//TODO: Throw exception on GffNode value set
					fieldDatas ~= (&stringLength)[0..uint8_t.sizeof];
					fieldDatas ~= (cast(void*)node.stringContainer.ptr)[0..stringLength];
				}break;
				case ExoLocString:{
					//TODO
				}break;
				case Void:{
					auto dataLength = node.rawContainer.length;
					fieldDatas ~= (&dataLength)[0..uint8_t.sizeof];
					fieldDatas ~= node.rawContainer;
					//TODO
				}break;
				case Struct:{
					//TODO
				}break;
				case List:{
					//TODO
				}break;
			}

			return 0;
		}


		void[] serialize(immutable char[4] fileType, immutable char[4] fileVersion){
			header.file_type = fileType;
			header.file_version = fileVersion;

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
			offset += fieldDatas.length;

			header.list_indices_offset = offset;
			header.list_indices_count = cast(uint32_t)listIndices.length;
			offset += fieldDatas.length;

			version(unittest) auto offsetCheck = 0;
			void[] data;
			data.reserve(offset);
			data ~= (&header)[0..1];
			version(unittest) offsetCheck += GffHeader.sizeof;
			version(unittest) assert(data.length == offsetCheck);
			data ~= structs[0..structs.length];
			version(unittest) offsetCheck += structs.length * GffStruct.sizeof;
			version(unittest) assert(data.length == offsetCheck);
			data ~= fields[0..fields.length];
			version(unittest) offsetCheck += structs.length * GffStruct.sizeof;
			version(unittest) assert(data.length == offsetCheck);
			data ~= labels[0..labels.length];
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

	GffHeader* getHeader(in void[] rawData){
		return cast(GffHeader*)(rawData.ptr);
	}
	GffStruct* getStruct(in void[] rawData, size_t index){
		assert(index < getHeader(rawData).struct_count);
		return cast(GffStruct*)(rawData.ptr + getHeader(rawData).struct_offset + GffStruct.sizeof*index);
	}
	GffField* getField(in void[] rawData, size_t index){
		assert(index < getHeader(rawData).field_count);
		return cast(GffField*)(rawData.ptr + getHeader(rawData).field_offset + GffField.sizeof*index);
	}
	GffLabel* getLabel(in void[] rawData, size_t index){
		assert(index < getHeader(rawData).label_count);
		return cast(GffLabel*)(rawData.ptr + getHeader(rawData).label_offset + GffLabel.sizeof*index);
	}
	GffFieldData* getFieldData(in void[] rawData, size_t offset){
		assert(offset < getHeader(rawData).field_data_count);
		return cast(GffFieldData*)(rawData.ptr + getHeader(rawData).field_data_offset + offset);
	}
	GffFieldIndices* getFieldIndices(in void[] rawData, size_t offset){
		assert(offset < getHeader(rawData).field_indices_count);
		return cast(GffFieldIndices*)(rawData.ptr + getHeader(rawData).field_indices_offset + offset);
	}
	GffListIndices* getListIndices(in void[] rawData, size_t offset){
		assert(offset < getHeader(rawData).list_indices_count);
		return cast(GffListIndices*)(rawData.ptr + getHeader(rawData).list_indices_offset + offset);
	}

	GffNode buildNodeFromStruct(in void[] rawData, in size_t structIndex){
		auto s = getStruct(rawData, structIndex);

		GffNode ret;
		ret.type = GffNode.Type.Struct;

		if(s.field_count==1){
			auto n = buildNodeFromField(rawData, s.data_or_data_offset);
			ret.structContainer[n.label] = n;
		}
		else{
			auto fi = getFieldIndices(rawData, s.data_or_data_offset);
			foreach(i ; 0 .. s.field_count){
				auto n = buildNodeFromField(rawData, fi[i].field_index);
				ret.structContainer[n.label] = n;
			}
		}
		return ret;
	}

	GffNode buildNodeFromField(in void[] rawData, in size_t fieldIndex){
		import std.conv : to;
		auto f = getField(rawData, fieldIndex);

		GffNode ret;
		immutable lbl = getLabel(rawData, f.label_index).value;
		if(lbl[$-1]=='\0') ret.label = lbl.ptr.fromStringz.idup;
		else               ret.label = lbl.idup;
		ret.type = cast(GffNode.Type)f.type;

		switch(f.type) with(GffNode.Type){
			case Byte, Char, Word, Short, DWord, Int, Float:
				ret.simpleTypeContainer = cast(uint64_t)f.data_or_data_offset;
				break;
			case DWord64:
				const d = getFieldData(rawData, f.data_or_data_offset);
				ret.simpleTypeContainer = *(cast(uint64_t*)d);
				break;
			case Int64:
				const d = getFieldData(rawData, f.data_or_data_offset);
				ret.simpleTypeContainer = *(cast(int64_t*)d);
				break;
			case Double:
				const d = getFieldData(rawData, f.data_or_data_offset);
				ret.simpleTypeContainer = *(cast(uint64_t*)d);
				break;
			case ExoString:
				const data = getFieldData(rawData, f.data_or_data_offset);
				auto size = cast(uint32_t*)data;
				auto chars = cast(char*)(data+uint32_t.sizeof);

				ret.stringContainer = cast(immutable)(chars[0..*size]);
				break;
			case ResRef:
				const data = getFieldData(rawData, f.data_or_data_offset);
				auto size = cast(uint8_t*)data;
				auto chars = cast(char*)(data+uint8_t.sizeof);

				ret.stringContainer = cast(immutable)(chars[0..*size]);
				break;

			case ExoLocString:
				const data = getFieldData(rawData, f.data_or_data_offset);
				//auto total_size = cast(uint32_t*)data;
				auto str_ref = cast(uint32_t*)(data+uint32_t.sizeof);
				auto str_count = cast(uint32_t*)(data+2*uint32_t.sizeof);
				auto sub_str = cast(void*)(data+3*uint32_t.sizeof);

				ret.exoLocStringID = *str_ref;

				foreach(i ; 0 .. *str_count){
					auto id = cast(int32_t*)sub_str;
					auto length = cast(int32_t*)(sub_str+uint32_t.sizeof);
					auto str = cast(char*)(sub_str+2*uint32_t.sizeof);

					ret.exoLocStringContainer[*id] = cast(immutable)(str[0..*length]);
					sub_str += 2*uint32_t.sizeof + char.sizeof*(*length);
				}
				break;

			case Void:
				const data = getFieldData(rawData, f.data_or_data_offset);
				auto size = cast(uint32_t*)data;
				auto dataVoid = cast(void*)(data+uint32_t.sizeof);

				ret.rawContainer = dataVoid[0..*size];
				break;

			case Struct:
				auto s = buildNodeFromStruct(rawData, f.data_or_data_offset);
				ret.structContainer[s.label] = s;
				break;

			case List:
				auto li = getListIndices(rawData, f.data_or_data_offset);
				if(li.length>0){
					uint32_t* indices = &li.first_struct_index;

					ret.listContainer.reserve(li.length);
					foreach(i ; 0 .. li.length){
						ret.listContainer ~= buildNodeFromStruct(rawData, indices[i]);
					}
				}
				break;

			default: assert(0);
		}
		return ret;
	}

}