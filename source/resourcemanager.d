module resourcemanager;

import std.stdio;
import std.typecons;
import std.traits;


class ResourceException : Exception{
	public @safe pure nothrow
	this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null){
		super(message, file, line, next);
	}
}

class ResourceManager{
__gshared static:

	///Saves a resource into the Resource manager registry.
	/// Warning: the resource is copied, unless it is a class
	void save(T)(in string name, auto ref T data) if(isMutable!T){
		//writeln("Mutable:   ",name," = ",T.stringof);
		saveResource!T(name, data, Flags.NONE);
	}

	///ditto
	void save(T)(in string name, auto ref immutable(T) data){
		//writeln("Immutable: ",name," = ",T.stringof);
		saveResource(name, cast(T)data, Flags.IMMUTABLE);
	}

	///Removes a resource from the registry
	void remove(T)(in string name){
		mixin SetupAlias!T;

		if(RA* ra = typeid(T) in container){
			if(name in *ra){
				container[typeid(T)].remove(name);
				return;
			}
			throw new ResourceException("Resource name '"~name~"' of type '"~T.stringof~"' not found in registry");
		}
		throw new ResourceException("Resource type '"~T.stringof~"' not found in registry");
	}

	///Check if a resource exists in the registry
	bool exists(T)(in string name){
		mixin SetupAlias!T;
		immutable ra = typeid(T) in container;
		return ra && name in ra;
	}


	auto ref immutable(T) get(T)(in string name){
		static if(is(T==class)){
			return cast(immutable(T))(getResource!T(name).data);
		}
		else{
			return *cast(immutable(T)*)(getResource!T(name).data.ptr);
		}
	}

	auto ref T getMut(T)(in string name){
		auto r = getResource!T(name);
		if(!(r.flags & Flags.IMMUTABLE)){
			static if(is(T==class)){
				return cast(T)(getResource!T(name).data);
			}
			else{
				return *cast(T*)(getResource!T(name).data.ptr);
			}
		}
		assert(0, "Resource name '"~name~"' of type '"~T.stringof~"' has been saved as immutable");

	}



private:
	alias Resource = Tuple!(void[],"data",Flags,"flags");
	alias ResourceArray = Resource[string];
	ResourceArray[TypeInfo] resources;

	alias ObjectResource = Tuple!(Object,"data",Flags,"flags");
	alias ObjectResourceArray = ObjectResource[string];
	ObjectResourceArray[TypeInfo] objectResources;

	enum Flags: ubyte {
		NONE = 0,
		IMMUTABLE = 1<<0,
	}

	auto ref getResource(T)(in string name){
		mixin SetupAlias!T;

		if(RA* ra = typeid(T) in container){
			if(R* r = name in *ra){
				return *r;
			}
			throw new ResourceException("Resource name '"~name~"' of type '"~T.stringof~"' not found in registry");
		}
		throw new ResourceException("Resource type '"~T.stringof~"' not found in registry");
	}

	void saveResource(T)(in string name, auto ref T res, Flags flags){
		if(typeid(T) in resources && name in resources[typeid(T)])
			throw new ResourceException("A resource '"~name~"' of type '"~T.stringof~"' already exists in registry");

		static if(is(T==class)){
			//Save object directly
			objectResources[typeid(T)][name] = ObjectResource(res, flags);
		}
		else{
			//copy value and save it to
			auto r = Resource(new void[T.sizeof], flags);
			*cast(T*)r.data.ptr = res;

			resources[typeid(T)][name] = r;
		}
	}

	mixin template SetupAlias(T){
		static if(is(T==class)){
			alias RA = ObjectResourceArray;
			alias R = ObjectResource;
			alias container = objectResources;
		}
		else{
			alias RA = ResourceArray;
			alias R = Resource;
			alias container = resources;
		}
	}

	unittest{
		import etc.linux.memoryerror;
		static if (is(typeof(registerMemoryErrorHandler)))
			registerMemoryErrorHandler();
		import core.memory;
		import std.exception;


		//Class
		class TestClass{
			this(){}
			this(string t){text = t;}
			string text = "TestClassDefaultText";
			const string formatText(){return "Parent:"~text;}//for polymorphism tests
		}
		{
			auto testClass = new TestClass;
			save("lvalue", testClass);
			testClass.text = "HelloLValue";

			save("rvalue", new TestClass);
			getMut!TestClass("rvalue").text = "HelloRValue";

			immutable testClassI = cast(immutable)(new TestClass("HelloLValueImmut"));
			save("lvaluei", testClassI);

			save("rvaluei", cast(immutable)(new TestClass("HelloRValueImmut")));

			//mutable but stored as immutable
			auto testClass2 = new TestClass;
			save("test2", cast(immutable)(testClass2));
			testClass2.text = "HelloTest2";
		}
		GC.collect(); GC.minimize();

		assert((getResource!TestClass("lvalue").flags & Flags.IMMUTABLE)==0);
		assert((getResource!TestClass("rvalue").flags & Flags.IMMUTABLE)==0);
		assert(get!TestClass("lvalue").text=="HelloLValue");
		assert(getMut!TestClass("lvalue").text==get!TestClass("lvalue").text);
		assert(get!TestClass("rvalue").text=="HelloRValue");
		assert(getMut!TestClass("rvalue").text==get!TestClass("rvalue").text);
		getMut!TestClass("lvalue").text = "WorldLValue";
		assert(get!TestClass("lvalue").text=="WorldLValue");

		assert((getResource!TestClass("lvaluei").flags & Flags.IMMUTABLE)>0);
		assert((getResource!TestClass("rvaluei").flags & Flags.IMMUTABLE)>0);
		assert(get!TestClass("lvaluei").text=="HelloLValueImmut");
		assert(get!TestClass("rvaluei").text=="HelloRValueImmut");
		assertThrown!Error(getMut!TestClass("lvaluei"));
		assertThrown!Error(getMut!TestClass("rvaluei"));

		assert(get!TestClass("test2").text=="HelloTest2");


		//Struct
		struct TestStruct{
			string text = "TestStructDefaultText";
		}
		{
			TestStruct testStruct;
			testStruct.text = "HelloLValue";
			save("lvalue", testStruct);

			save("rvalue", TestStruct());
			getMut!TestStruct("rvalue").text = "HelloRValue";

			immutable testStructI = cast(immutable)(TestStruct("HelloLValueImmut"));
			save("lvaluei", testStructI);

			save("rvaluei", cast(immutable)(TestStruct("HelloRValueImmut")));
		}
		GC.collect(); GC.minimize();

		assert((getResource!TestStruct("lvalue").flags & Flags.IMMUTABLE)==0);
		assert((getResource!TestStruct("rvalue").flags & Flags.IMMUTABLE)==0);
		assert(get!TestStruct("lvalue").text=="HelloLValue");
		assert(getMut!TestStruct("lvalue").text==get!TestStruct("lvalue").text);
		assert(get!TestStruct("rvalue").text=="HelloRValue");
		assert(getMut!TestStruct("rvalue").text==get!TestStruct("rvalue").text);
		getMut!TestStruct("lvalue").text = "WorldLValue";
		assert(get!TestStruct("lvalue").text=="WorldLValue");

		assert((getResource!TestStruct("lvaluei").flags & Flags.IMMUTABLE)>0);
		assert((getResource!TestStruct("rvaluei").flags & Flags.IMMUTABLE)>0);
		assert(get!TestStruct("lvaluei").text=="HelloLValueImmut");
		assert(get!TestStruct("rvaluei").text=="HelloRValueImmut");
		assertThrown!Error(getMut!TestStruct("lvaluei"));
		assertThrown!Error(getMut!TestStruct("rvaluei"));


		//Base type
		{
			string str;
			str = "HelloLValue";
			save("lvalue", str);

			save("rvalue", cast(string)"default");//explicit cast for mutable rvalue
			getMut!string("rvalue") = "HelloRValue";

			immutable strI = cast(immutable)("HelloLValueImmut");
			save("lvaluei", strI);

			save("rvaluei", cast(immutable)("HelloRValueImmut"));
		}
		GC.collect(); GC.minimize();

		assert((getResource!string("lvalue").flags & Flags.IMMUTABLE)==0);
		assert((getResource!string("rvalue").flags & Flags.IMMUTABLE)==0);
		assert(get!string("lvalue")=="HelloLValue");
		assert(getMut!string("lvalue")==get!string("lvalue"));
		assert(get!string("rvalue")=="HelloRValue");
		assert(getMut!string("rvalue")==get!string("rvalue"));
		getMut!string("lvalue") = "WorldLValue";
		assert(get!string("lvalue")=="WorldLValue");

		assert((getResource!string("lvaluei").flags & Flags.IMMUTABLE)>0);
		assert((getResource!string("rvaluei").flags & Flags.IMMUTABLE)>0);
		assert(get!string("lvaluei")=="HelloLValueImmut");
		assert(get!string("rvaluei")=="HelloRValueImmut");
		assertThrown!Error(getMut!string("lvaluei"));
		assertThrown!Error(getMut!string("rvaluei"));

		//TODO: Polymorphism
		class TestClassChild : TestClass{
			this(){super();}
			this(string t){super(t);}
			override const string formatText(){return "Child:"~text;}
		}
		{
			auto child = new TestClassChild("HelloChild");
			save("poly", cast(TestClass)child);
		}
		GC.collect(); GC.minimize();
		assertThrown!ResourceException(get!TestClassChild("poly"));
		assert(get!TestClass("poly").formatText() == "Child:HelloChild");


		//Not found exceptions & remove
		assertThrown!ResourceException(get!TestClass("poly123"));

		assertNotThrown(get!TestClass("poly"));
		remove!TestClass("poly");
		assertThrown!ResourceException(get!TestClass("poly"));
	}

}