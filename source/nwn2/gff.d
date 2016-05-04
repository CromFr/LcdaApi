module nwn2.gff;


import std.stdint;
import std.string;
import std.conv;
debug import std.stdio: writeln;
import nwn2.tlk;


struct GffNode{
	string label;
	Type type;
	GffNode* parent = null;
	size_t parentListIndex;

	/// Convert the node value to a certain type.
	/// If the type is string, any type of value gets converted into string. Structs and lists are not expanded.
	const ref auto to(T)(){
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
			import std.string: format;
			final switch(type) with(Type){
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
		else static if(is(T==void[])){
			if(type==Type.Void)
				return rawContainer;
		}
		//else static if(is(T==GffNode[string])){
		//	if(type==Type.Struct)
		//		return structContainer;
		//}
		else static if(is(T==GffNode[])){
			if(type==Type.List || type==Type.Struct)
				return aggrContainer;
		}
		assert(0, "Incompatible type conversion from "~type.to!string~" to "~T.stringof);
	}

	ref GffNode opIndex(in string label){
		assert(type==Type.Struct, "Not a struct");
		return aggrContainer[structLabelMap[label]];
	}
	ref GffNode opIndex(in size_t index){
		assert(type==Type.List, "Not a list");
		return aggrContainer[index];
	}

	/// Type of data stored in the GffNode
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

	/// Get a list of all parents of the nodes, starting from the node itself to its furtherest parent.
	const const(GffNode)*[] getParents(){
		const(GffNode)*[] list;
		const(GffNode)* current = &this;
		while(current !is null){
			list ~= current;
			current = current.parent;
		}
		return list;
	}

	/// Produces a readable string of the node and its children
	const string toPrettyString(){

		string toPrettyStringInternal(const(GffNode)* node, string tabs){
			import std.string: leftJustify;

			if(node.type == Type.Struct){
				string ret = tabs~"("~node.type.to!string~")\n";
				foreach(ref childNode ; node.aggrContainer){
					ret ~= toPrettyStringInternal(&childNode, tabs~"   | ");
				}
				return ret;
			}
			else if(node.type == Type.List){
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

	const string path(){
		import std.algorithm: map, reduce, reverse;
		import std.array: array;
		return getParents
			.map!(n =>
				n.label!=null?
					  n.label// ~ "(\x1b[31m"~n.parentListIndex.to!string~"\x1b[m)"
					: (n.parent!is null && n.parent.type==Type.List? "["~n.parentListIndex.to!string~"]" : "{"~n.type.to!string~"}"))
			.array
			.reverse
			.reduce!((a,b)=> b[0]=='['? a~b : a~"."~b);
	}


package:
	void[] rawContainer;
	uint64_t simpleTypeContainer;
	string stringContainer;
	GffNode[] aggrContainer;
	size_t[string] structLabelMap;
	uint32_t exoLocStringID;
	string[int] exoLocStringContainer;
}

class Gff{

	this(in string path){
		import std.file : read;
		this(path.read());
	}
	this(in void[] data){
		auto parser = Parser(data.ptr);
		firstNode = parser.buildNodeFromStruct(data, 0, null);
	}

	alias firstNode this;
	GffNode firstNode;


	void[] serialize(){

		Serializer serializer;
		serializer.registerStruct(firstNode);
		return serializer.serialize(cast(char[4])"ANY ", cast(char[4])"V3.2 ");
	}

private:

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

		GffNode buildNodeFromStruct(in void[] rawData, in size_t structIndex, GffNode* parent, size_t parentListIndex=0){
			GffNode ret;
			ret.type = GffNode.Type.Struct;
			ret.parent = parent;
			ret.parentListIndex = parentListIndex;

			buildNodeFromStructInPlace(rawData, structIndex, &ret);

			return ret;
		}

		void buildNodeFromStructInPlace(in void[] rawData, in size_t structIndex, GffNode* destNode){

			destNode.type = GffNode.Type.Struct;

			auto s = getStruct(rawData, structIndex);
			if(s.field_count==1){
				auto n = buildNodeFromField(rawData, s.data_or_data_offset, destNode);

				destNode.structLabelMap[n.label] = destNode.aggrContainer.length;
				destNode.aggrContainer ~= n;
			}
			else if(s.field_count > 1){
				auto fi = getFieldIndices(rawData, s.data_or_data_offset);
				foreach(i ; 0 .. s.field_count){
					auto n = buildNodeFromField(rawData, fi[i].field_index, destNode);

					destNode.structLabelMap[n.label] = destNode.aggrContainer.length;
					destNode.aggrContainer ~= n;
				}
			}
		}

		GffNode buildNodeFromField(in void[] rawData, in size_t fieldIndex, GffNode* parent){
			GffNode ret;
			ret.parent = parent;
			try{
				import std.conv : to;
				immutable f = getField(rawData, fieldIndex);

				immutable lbl = getLabel(rawData, f.label_index).value;
				if(lbl[$-1]=='\0') ret.label = lbl.ptr.fromStringz.idup;
				else               ret.label = lbl.idup;
				ret.type = cast(GffNode.Type)f.type;

				final switch(ret.type) with(GffNode.Type){
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
								ret.aggrContainer ~= buildNodeFromStruct(rawData, indices[i], &ret, i);
							}
						}
						break;
				}
				return ret;
			}
			catch(Throwable t){
				if(t.msg.length==0 || t.msg[0] != '@'){
					t.msg = "@"~ret.path()~": "~t.msg;
				}
				throw t;
			}
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


		uint32_t registerStruct(in GffNode node){
			assert(node.type == GffNode.Type.Struct);

			immutable createdStructIndex = cast(uint32_t)structs.length;
			structs ~= GffStruct();
			GffStruct* gffstruct = &structs[createdStructIndex];

			gffstruct.type = structs.length==0? 0xFFFF_FFFF : 0;//TODO: what is the type for?
			gffstruct.field_count = cast(uint32_t)node.aggrContainer.length;

			if(gffstruct.field_count == 1){
				//index in field array
				gffstruct.data_or_data_offset = registerField(
					node.aggrContainer[0]
				);
			}
			else{
				//byte offset in field indices array
				gffstruct.data_or_data_offset = cast(uint32_t)fieldIndices.length;

				fieldIndices.reserve(fieldIndices.length + uint32_t.sizeof*gffstruct.field_count);
				foreach(field ; node.aggrContainer){
					auto index = registerField(field);
					fieldIndices ~= (&index)[0..1];
				}
			}
			return createdStructIndex;
		}
		uint32_t registerField(in GffNode node){
			immutable createdFieldIndex = cast(uint32_t)fields.length;
			fields ~= GffField(node.type);
			auto field = &fields[createdFieldIndex];

			assert(node.label.length <= 16, "Label too long");//TODO: Throw exception on GffNode.label set

			//TODO: this may be totally stupid and complexity too high
			import std.algorithm: equal;
			bool labelFound = false;
			foreach(i, ref s ; labels){
				if(s.value == node.label){
					labelFound = true;
					field.label_index = cast(uint32_t)i;
					break;
				}
			}
			if(!labelFound){
				field.label_index = cast(uint32_t)labels.length;
				char[16] label = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
				label[0..node.label.length] = node.label.dup;
				labels ~= GffLabel(label);
			}

			final switch(node.type) with(GffNode.Type){
				case Byte, Char, Word, Short, DWord, Int, Float:{
					//cast is ok because all those types are <= 32bit
					field.data_or_data_offset = *cast(uint32_t*)&node.simpleTypeContainer;
				}break;
				case DWord64, Int64, Double:{
					//stored in fieldDatas
					field.data_or_data_offset = cast(uint32_t)fieldDatas.length;
					fieldDatas ~= (&node.simpleTypeContainer)[0..1].dup;
				}break;
				case ExoString:{
					auto stringLength = node.stringContainer.length;

					field.data_or_data_offset = cast(uint32_t)fieldDatas.length;
					fieldDatas ~= (&stringLength)[0..1];
					fieldDatas ~= (cast(void*)node.stringContainer.ptr)[0..stringLength];
				}break;
				case ResRef:{
					auto stringLength = node.stringContainer.length;
					assert(stringLength<=32, "Resref too long (max length: 32 characters)");//TODO: Throw exception on GffNode value set

					field.data_or_data_offset = cast(uint32_t)fieldDatas.length;
					fieldDatas ~= (&stringLength)[0..1];
					fieldDatas ~= (cast(void*)node.stringContainer.ptr)[0..stringLength];
				}break;
				case ExoLocString:{
					immutable fieldDataIndex = fieldDatas.length;
					field.data_or_data_offset = cast(uint32_t)fieldDataIndex;

					//total size
					fieldDatas ~= [0,0,0,0];

					auto strref = cast(uint32_t)node.exoLocStringID;
					fieldDatas ~= (&strref)[0..1];

					auto strcount = cast(uint32_t)node.exoLocStringContainer.length;
					fieldDatas ~= (&strcount)[0..1];

					foreach(key, str ; node.exoLocStringContainer){
						//TODO: keep original ordering
						fieldDatas ~= (&cast(int32_t)key)[0..1];//string id

						auto length = cast(int32_t)str.length;
						fieldDatas ~= (&length)[0..1];//length

						fieldDatas ~= str.ptr[0..length].dup;
					}

					//total size
					auto totalSize = cast(uint32_t)(fieldDatas.length-fieldDataIndex);
					fieldDatas[fieldDataIndex..fieldDataIndex+4] = (&totalSize)[0..1];
				}break;
				case Void:{
					auto dataLength = node.rawContainer.length;
					field.data_or_data_offset = cast(uint32_t)fieldDatas.length;
					fieldDatas ~= (&dataLength)[0..uint8_t.sizeof];
					fieldDatas ~= node.rawContainer;
				}break;
				case Struct:{
					field.data_or_data_offset = registerStruct(node);
					assert(0, "TODO: not handled well "~node.path.to!string);
				}break;
				case List:{
					immutable createdListOffset = cast(uint32_t)listIndices.length;
					field.data_or_data_offset = createdListOffset;

					uint32_t listLength = cast(uint32_t)node.aggrContainer.length;
					listIndices ~= (&listLength)[0..1];
					listIndices.length += listLength * uint32_t.sizeof;
					if(node.aggrContainer !is null){
						foreach(i, ref listField ; node.aggrContainer){
							immutable offset = createdListOffset+uint32_t.sizeof*(i+1);

							uint32_t structIndex = registerStruct(listField);
							listIndices[offset..offset+uint32_t.sizeof] = (&structIndex)[0..1];
						}

					}
				}break;
			}

			return createdFieldIndex;
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
			data ~= structs[0..structs.length];
			version(unittest) offsetCheck += structs.length * GffStruct.sizeof;
			version(unittest) assert(data.length == offsetCheck);
			data ~= fields[0..fields.length];
			version(unittest) offsetCheck += fields.length * GffStruct.sizeof;
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
}