module resourcemanager;

import std.stdio;
import std.typecons;
import std.traits;
import std.file;
import std.path;


class ResourceException : Exception{
	public @safe pure nothrow
	this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null){
		super(message, file, line, next);
	}
}

/// Garbage class, ugly as sh**, totally unsafe, barely working. Please look somewhere else
class ResourceManager{
__gshared static:

	///Stores a resource into the Resource manager registry.
	/// Warning: the resource is copied, unless it is a class
	/// TODO: not thread-safe
	void store(T)(in string name, auto ref T data) if(isMutable!T){
		//writeln("Mutable:   ",name," = ",T.stringof);
		storeResource!T(name, data, Flags.NONE);
	}

	///ditto
	/// TODO: not thread-safe
	void store(T)(in string name, auto ref const(T) data){
		//writeln("Immutable: ",name," = ",T.stringof);
		storeResource(name, data, Flags.CONST);
	}


	void replace(T)(in string name, auto ref T data){
		storeResource!(T, true)(name, data, isMutable!T? Flags.NONE : Flags.CONST);
	}

	///Construct a resource and store it in the registry as mutable.
	auto ref T construct(T, VT...)(in string name, lazy VT constructorArgs){
		static if(is(T == class)){
			store(name, new T(constructorArgs));
		}
		else{
			store(name, T(constructorArgs));
		}
		return getMut!T(name);
	}


	///Removes a resource from the registry
	/// TODO: not thread-safe
	void remove(T)(in string name){
		mixin SetupAlias!T;

		if(RA* ra = typeid(Unqual!T) in container){
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
		auto ra = typeid(Unqual!T) in container;
		return ra && name in *ra;
	}

	///Gets a reference to the resource matching the name and type T
	auto ref const(T) get(T)(in string name){
		static if(is(T == class)){
			return cast(const(T))(getResource!T(name).data);
		}
		else{
			return *cast(const(T)*)(getResource!T(name).data.ptr);
		}
	}

	///ditto
	///The resource is mutable and can be changed. Will assert an Error if the resource has been stored as const
	///Mutability breaks thread safety
	auto ref T getMut(T)(in string name){
		auto r = getResource!T(name);
		if(!(r.flags & Flags.CONST)){
			static if(is(T == class)){
				return cast(T)(getResource!T(name).data);
			}
			else{
				return *cast(T*)(getResource!T(name).data.ptr);
			}
		}
		assert(0, "Resource name '"~name~"' of type '"~T.stringof~"' has been stored as const");
	}



	// FILE RELATED


	///Retrieve a resource or construct it if it doesn't exists using a file matching fileName and found in ResourceManager.path
	/// If needed, the resource will be constructed with the file path as parameter, folowed by additionalCtorArgs
	/// TODO: not thread-safe
	auto ref const(T) fetchFile(T, VT...)(in string fileName, lazy VT additionalCtorArgs){
		try return get!T(fileName);
		catch(ResourceException){}

		auto filePath = path.searchFile(fileName);
		//may throw ResourceException if file not found

		return cast(const)construct!T(fileName, filePath.name, additionalCtorArgs);
	}



	///Path where resources will be searched
	Path path = new Path;

	class Path{

		void add(in string path, bool cached=true){
			immutable normPath = buildNormalizedPath(path);

			DirEntry[string] cache;

			if(cached){
				if(normPath.exists && normPath.isDir){
					populateCache(DirEntry(normPath), cache);
				}
				else
					writeln(__MODULE__~" - Warning: Path ",normPath," does not exists / is not a directory. Path ignored");
			}

			paths[normPath] = PathCache(cached, cache);
		}

		void remove(in string path){
			immutable normPath = buildNormalizedPath(path);
			paths.remove(normPath);
		}

		void updateCache(in string[] baseDirsToUpdate=[]){
			//TODO
			assert(0, "Not implemented");
		}

		DirEntry searchFile(in string name){
			foreach(path, ref pcache ; paths){
				if(pcache.cached){
					if(auto file = name in pcache.cache)
						return *file;
				}
			}
			foreach(path, ref pcache ; paths){
				if(!pcache.cached){
					if(auto file = name in pcache.cache)
						return *file;
				}
			}
			throw new ResourceException("Resource file '"~name~"' not found in path");
		}

	private:
		alias PathCache = Tuple!(bool,"cached",DirEntry[string],"cache");
		PathCache[string] paths;

		void populateCache(DirEntry baseDir, ref DirEntry[string] cache){
			foreach(file ; dirEntries(baseDir, SpanMode.depth)){
				//TODO: check duplicate file names? (may be expensive)
				if(file.isFile){
					cache[file.baseName] = file;
				}
			}
		}
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
		CONST = 1<<0,
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

	void storeResource(T, bool replace = false)(in string name, auto ref T res, Flags flags){
		static if(replace == false){
			if(typeid(Unqual!T) in resources && name in resources[typeid(Unqual!T)])
				throw new ResourceException("A resource '"~name~"' of type '"~T.stringof~"' already exists in registry");
		}

		static if(is(T == class)){
			//Store object directly
			objectResources[typeid(Unqual!T)][name] = ObjectResource(cast(Unqual!T)res, flags);
		}
		else{
			//copy value then store
			auto r = Resource(new void[T.sizeof], flags);
			*cast(T*)r.data.ptr = res;

			resources[typeid(Unqual!T)][name] = r;
		}
	}

	mixin template SetupAlias(T){
		static if(is(T == class)){
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



	//===========================================================
	version(unittest){
		class TestClass{
			this(){}
			this(string t){text = t;}
			string text = "TestClassDefaultText";
			const string formatText(){return "Parent:"~text;}//for polymorphism tests
		}
		struct TestStruct{
			string text = "TestStructDefaultText";
		}
		class Text{
			this(in string file){
				text = file.readText();
			}
			string text;
		}
	}
	unittest{
		import std.stdio : writeln;
		import core.memory;
		import std.exception;
		writeln(__MODULE__);


		//Class
		{
			auto testClass = new TestClass;
			store("lvalue", testClass);
			testClass.text = "HelloLValue";

			store("rvalue", new TestClass);
			getMut!TestClass("rvalue").text = "HelloRValue";

			const testClassI = cast(const)(new TestClass("HelloLValueImmut"));
			store("lvaluei", testClassI);

			store("rvaluei", cast(const)(new TestClass("HelloRValueImmut")));

			//mutable but stored as const
			auto testClass2 = new TestClass;
			store("test2", cast(const)(testClass2));
			testClass2.text = "HelloTest2";
		}
		GC.collect(); GC.minimize();

		assert((getResource!TestClass("lvalue").flags & Flags.CONST)==0);
		assert((getResource!TestClass("rvalue").flags & Flags.CONST)==0);
		assert(get!TestClass("lvalue").text=="HelloLValue");
		assert(getMut!TestClass("lvalue").text==get!TestClass("lvalue").text);
		assert(get!TestClass("rvalue").text=="HelloRValue");
		assert(getMut!TestClass("rvalue").text==get!TestClass("rvalue").text);
		getMut!TestClass("lvalue").text = "WorldLValue";
		assert(get!TestClass("lvalue").text=="WorldLValue");

		assert((getResource!TestClass("lvaluei").flags & Flags.CONST)>0);
		assert((getResource!TestClass("rvaluei").flags & Flags.CONST)>0);
		assert(get!TestClass("lvaluei").text=="HelloLValueImmut");
		assert(get!TestClass("rvaluei").text=="HelloRValueImmut");
		assertThrown!Error(getMut!TestClass("lvaluei"));
		assertThrown!Error(getMut!TestClass("rvaluei"));

		assert(get!TestClass("test2").text=="HelloTest2");


		//Struct
		{
			TestStruct testStruct;
			testStruct.text = "HelloLValue";
			store("lvalue", testStruct);

			store("rvalue", TestStruct());
			getMut!TestStruct("rvalue").text = "HelloRValue";

			const testStructI = cast(const)(TestStruct("HelloLValueImmut"));
			store("lvaluei", testStructI);

			store("rvaluei", cast(const)(TestStruct("HelloRValueImmut")));
		}
		GC.collect(); GC.minimize();

		assert((getResource!TestStruct("lvalue").flags & Flags.CONST)==0);
		assert((getResource!TestStruct("rvalue").flags & Flags.CONST)==0);
		assert(get!TestStruct("lvalue").text=="HelloLValue");
		assert(getMut!TestStruct("lvalue").text==get!TestStruct("lvalue").text);
		assert(get!TestStruct("rvalue").text=="HelloRValue");
		assert(getMut!TestStruct("rvalue").text==get!TestStruct("rvalue").text);
		getMut!TestStruct("lvalue").text = "WorldLValue";
		assert(get!TestStruct("lvalue").text=="WorldLValue");

		assert((getResource!TestStruct("lvaluei").flags & Flags.CONST)>0);
		assert((getResource!TestStruct("rvaluei").flags & Flags.CONST)>0);
		assert(get!TestStruct("lvaluei").text=="HelloLValueImmut");
		assert(get!TestStruct("rvaluei").text=="HelloRValueImmut");
		assertThrown!Error(getMut!TestStruct("lvaluei"));
		assertThrown!Error(getMut!TestStruct("rvaluei"));


		//Base type
		{
			string str;
			str = "HelloLValue";
			store("lvalue", str);

			store("rvalue", cast(string)"default");//explicit cast for mutable rvalue
			getMut!string("rvalue") = "HelloRValue";

			const strI = cast(const)("HelloLValueImmut");
			store("lvaluei", strI);

			store("rvaluei", cast(const)("HelloRValueImmut"));
		}
		GC.collect(); GC.minimize();

		assert((getResource!string("lvalue").flags & Flags.CONST)==0);
		assert((getResource!string("rvalue").flags & Flags.CONST)==0);
		assert(get!string("lvalue")=="HelloLValue");
		assert(getMut!string("lvalue")==get!string("lvalue"));
		assert(get!string("rvalue")=="HelloRValue");
		assert(getMut!string("rvalue")==get!string("rvalue"));
		getMut!string("lvalue") = "WorldLValue";
		assert(get!string("lvalue")=="WorldLValue");

		assert((getResource!string("lvaluei").flags & Flags.CONST)>0);
		assert((getResource!string("rvaluei").flags & Flags.CONST)>0);
		assert(get!string("lvaluei")=="HelloLValueImmut");
		assert(get!string("rvaluei")=="HelloRValueImmut");
		assertThrown!Error(getMut!string("lvaluei"));
		assertThrown!Error(getMut!string("rvaluei"));

		//Polymorphism
		class TestClassChild : TestClass{
			this(){super();}
			this(string t){super(t);}
			override const string formatText(){return "Child:"~text;}
		}
		{
			auto child = new TestClassChild("HelloChild");
			store("poly", cast(TestClass)child);
		}
		GC.collect(); GC.minimize();
		assertThrown!ResourceException(get!TestClassChild("poly"));
		assert(get!TestClass("poly").formatText() == "Child:HelloChild");


		//Not found exceptions & remove
		assertThrown!ResourceException(get!TestClass("poly123"));

		assertNotThrown(get!TestClass("poly"));
		remove!TestClass("poly");
		assertThrown!ResourceException(get!TestClass("poly"));


		//File handling
		alias writefile = std.file.write;
		auto tmp = buildPath(tempDir(), __MODULE__~"_unittest");
		if(tmp.exists)
			rmdirRecurse(tmp);
		mkdir(tmp);
		writefile(buildPath(tmp, "lorem.txt"), "Lorem ipsum");
		writefile(buildPath(tmp, "hello.txt"), "Hello World !");

		path.add(tmp);

		assert(fetchFile!Text("lorem.txt").text == "Lorem ipsum");
		assert(fetchFile!Text("hello.txt").text == "Hello World !");
		rmdirRecurse(tmp);
	}

}