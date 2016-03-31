module resourcemanager;

class ResourceException : Exception{
	public @safe pure nothrow
	this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null){
		super(message, file, line, next);
	}
}

class ResourceManager{
__gshared static:

	void save(T)(in string name, ref T data) if(isMutable!T){
		writeln("Mutable   Lvalue: ",name,": ",T.stringof);
		saveResource!T(name, cast(void*)(&data), Flags.NONE);
	}
	void save(T)(in string name, ref immutable(T) data){
		writeln("Immutable Lvalue: ",name,": ",T.stringof);
		saveResource!T(name, cast(void*)(&data), Flags.IMMUTABLE);
	}
	//TODO: Use auto ref parameters to handle rvalues
	void save(T)(in string name, immutable(T) data){
		writeln("Immutable Rvalue: ",name,": ",T.stringof);
		writeln(data.text);
		saveResource!T(name, cast(void*)(&data), Flags.IMMUTABLE);
	}


	ref immutable(T) get(T)(in string name){
		return *cast(immutable(T)*)(getResource!T(name).data);
	}

	ref T getMut(T)(in string name){
		auto r = getResource!T(name);
		if(!(r.flags & Flags.IMMUTABLE))
			return *cast(T*)(r.data);
		assert(0, "Resource name '"~name~"' of type '"~T.stringof~"' has been saved as immutable");

	}



private:
	alias Resource = Tuple!(void*,"data",Flags,"flags");
	alias ResourceArray = Resource[string];
	ResourceArray[TypeInfo] resources;

	enum Flags: ubyte {
		NONE = 0,
		IMMUTABLE = 1<<0,
	}

	Resource getResource(T)(in string name){
		if(ResourceArray* ra = typeid(T) in resources){
			if(Resource* r = name in *ra){
				return *r;
			}
			throw new ResourceException("Resource name '"~name~"' of type '"~T.stringof~"' not found in registry");
		}
		writeln("Searched resource: ",typeid(T));
		writeln("           Not in: ", resources);
		throw new ResourceException("Resource type '"~T.stringof~"' not found in registry");
	}

	void saveResource(T)(in string name, void* ptr, Flags flags){
		if(typeid(T) in resources && name in resources[typeid(T)])
			throw new ResourceException("A resource '"~name~"' of type '"~T.stringof~"' already exists in registry");

		resources[typeid(T)][name] = Resource(ptr, flags);
	}



	unittest{
		import etc.linux.memoryerror;
		static if (is(typeof(registerMemoryErrorHandler)))
			registerMemoryErrorHandler();
		import core.memory;
		import std.exception;


		class TestClass{
			string text = "TestClassDefaultText";
		}
		struct TestStruct{
			string text = "TestStructDefaultText";
		}

		//Class
		{
			auto data = new TestClass;
			save("tc", data);
			data.text = "Hello";
		}
		GC.collect(); GC.minimize();
		assert((getResource!TestClass("tc").flags & Flags.IMMUTABLE)==0);
		assert(get!TestClass("tc").text=="Hello");
		assert(getMut!TestClass("tc").text=="Hello");
		assert(!__traits(compiles, get!TestClass("tc").text="a"));
		getMut!TestClass("tc").text = "World";
		assert(get!TestClass("tc").text=="World");
		//Struct
		{
			TestStruct data;
			save("ts", data);
			data.text = "Hello";
		}
		GC.collect(); GC.minimize();
		assert((getResource!TestStruct("ts").flags & Flags.IMMUTABLE)==0);
		assert(get!TestStruct("ts").text=="Hello");
		assert(getMut!TestStruct("ts").text=="Hello");
		assert(!__traits(compiles, get!TestStruct("ts").text="a"));
		getMut!TestStruct("ts").text = "World";
		assert(get!TestStruct("ts").text=="World");
		//Basic type
		{
			string data;
			save("str", data);
			data = "Hello";
		}
		GC.collect(); GC.minimize();
		assert((getResource!string("str").flags & Flags.IMMUTABLE)==0);
		assert(get!string("str")=="Hello");
		assert(getMut!string("str")=="Hello");
		assert(!__traits(compiles, get!string("str")="a"));
		getMut!string("str") = "World";
		assert(get!string("str")=="World");
		//Immutability
		{
			auto data = new TestClass;
			auto dataImmut = cast(immutable)data;
			save("tci", dataImmut);
			data.text = "Hello";
		}
		GC.collect(); GC.minimize();
		assert((getResource!TestClass("tci").flags & Flags.IMMUTABLE)>0);
		assert(get!TestClass("tci").text=="Hello");
		assertThrown!Error(getMut!TestClass("tci").text=="Hello");
		assert(!__traits(compiles, get!TestClass("tci").text="a"));


		//{
			auto data = new TestClass;
			save("tci2", cast(immutable)data);
			data.text = "Hello";
		//}
		//GC.collect(); GC.minimize();
		writeln(get!TestClass("tci2").text);
		assert((getResource!TestClass("tci2").flags & Flags.IMMUTABLE)>0);
		assert(get!TestClass("tci2").text=="Hello");
		assertThrown!Error(getMut!TestClass("tci2").text=="Hello");
		assert(!__traits(compiles, get!TestClass("tci2").text="a"));


		//size_t addr;
		////{
		//	TestStruct test;
		//	addr = cast(size_t)&test - 5000;
		//	writeln(addr, "=====>", GC.query(&test));
		////}
		//GC.collect(); GC.minimize();
		//writeln(GC.query(cast(void*)(addr+5000)));
	}

}