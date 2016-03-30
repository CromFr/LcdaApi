module resman;


import std.file;
import std.path;
import std.string : chompPrefix, toLower;

class ResourceException : Exception{
	public @safe pure nothrow
	this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null){
		super(message, file, line, next);
	}
}

///	Resource Manager
///	Centralize the objects in the program, preventing from having many instances of the same object
///	Note: You can have multiple resources with the same name if the resource type is different
class ResMan{
static:
	///	Add a resource to the manager
	///	Throws: ResourceException if the resource name already exists for this resource type
	void register(T)(in string name, ref T res){
		TypeInfo ti = typeid(T);
		if(!(ti in m_loadedRes && name in m_loadedRes[ti]))
			m_loadedRes[typeid(T)][name] = res;
		else
			throw new ResourceException("Resource '"~name~"' already exists");
	}


	///	Constructs a resource and add it to the manager
	///	Params:
	///		name = Name of the resource to create
	///		ctorArgs = Arguments passed to the resource constructor
	///	Throws: ResourceException if the resource name already exists for this resource type
	///	Returns: the created resource
	auto ref constructResource(T, VT...)(in string name, VT ctorArgs){
		T res = new T(ctorArgs);
		register!T(name, res);
		return *(cast(T*)&(m_loadedRes[typeid(T)][name]));
	}

	///	Removes a resource from the manager
	///	Will let the D garbage collector handle destruction if not used somewhere else
	///	Params:
	///		name = registered name of the resource
	///		destroy = true to force destruction (can cause seg faults if the resource is used somewhere else)
	///	Throws: ResourceException if the resource name does not exist
	void discard(T)(in string name, bool destroy=false){
		TypeInfo ti = typeid(T);
		if(!(ti in m_loadedRes && name in m_loadedRes[ti])){
			if(destroy)
				destroy(m_loadedRes[typeid(T)][name]);
			else
				m_loadedRes[typeid(T)][name] = null;
		}
		else
			throw new ResourceException("Resource '"~name~"' not found");
	}


	///	Gets the resource with its name
	///	Throws: ResourceException if the resource name does not exist
	auto ref get(T)(in string name){
		TypeInfo ti = typeid(T);
		if(ti in m_loadedRes && name in m_loadedRes[ti])
			return *(cast(T*)&(m_loadedRes[ti][name]));

		throw new ResourceException("Resource '"~name~"' not found");
	}

	///	Loads the resources contained in directory matching filePatern
	///	The first argument of the resource constructor must be a DirEntry, followed by any arguments provided with ctorArgs
	///	Params:
	///		directory = Path of the folder to search into
	///		filePatern = file patern to load (ie: "*", "*.vtx", ...)
	///		recursive = true to search in subfolders
	///		ctorArgs = Arguments passed to the resource constructor
	void constructFromFiles(T, VT...)(in string directory, in string filePatern, in bool recursive, VT ctorArgs){
		import std.path : dirSeparator;

		foreach(ref file ; dirEntries(directory, filePatern, recursive?SpanMode.depth:SpanMode.shallow)){
			if(file.isFile){
				immutable name = file.name.chompPrefix(directory~dirSeparator);
				constructResource!T(name, file, ctorArgs);
			}
		}
	}



	///Paths where the resource manager will search for resource files
	__gshared string[] path;


	///Builds a lookup table containing all resource file names with their paths.
	/// This is usefull when there are a lot of resources and you can't afford doing
	/// disk operations each time you need a resource
	void cacheResourcePaths(){
		foreach(p ; path){
			if(p.exists && p.isDir){
				foreach(ref file ; dirEntries(p, SpanMode.depth)){
					if(file.isFile){
						cachedPaths[file.baseName.toLower] = DirEntry(file.name);
					}
				}
			}
		}
	}

	T getOrConstruct(T)(in string fileName){
		try return get!T(fileName);
		catch(ResourceException e){
			if(fileName.toLower in cachedPaths){
				return constructResource!T(fileName, cachedPaths[fileName.toLower]);
			}
			foreach(p ; path){
				if(p.exists && p.isDir){
					foreach(ref file ; dirEntries(p, SpanMode.depth)){
						if(file.isFile && filenameCmp!(CaseSensitive.no)(file.name.baseName, fileName)==0){
							//info("Loaded ",fileName," from ",file.name);
							return constructResource!T(fileName, file);
						}
					}
				}
			}

			throw new ResourceException("Resource '"~fileName~"' not found in path");
		}
	}
	deprecated string findFile(in string fileName){
		foreach(p ; path){
			if(fileName.toLower in cachedPaths){
				return cachedPaths[fileName.toLower];
			}
			if(p.exists && p.isDir){
				foreach(ref file ; dirEntries(p, SpanMode.depth)){
					if(file.isFile && filenameCmp!(CaseSensitive.no)(file.name.baseName, fileName)==0){
						return file;
					}
				}
			}
		}
		return null;
	}



private:
	this(){}
	__gshared Object[string][TypeInfo] m_loadedRes;
	__gshared DirEntry[string] cachedPaths;
}


unittest {
	import std.stdio;
	import std.file;
	static class Foo{
		this(){}
		this(DirEntry file, int i){s = file.name;}
		string s = "goto bar";
	}

	auto rm = new Resource;

	auto foo = new Foo;
	rm.register("yolo", foo);

	assert(rm.Get!Foo("yolo") == foo);
	assert(rm.Get!Foo("yolo") is foo);

	rm.constructFromFiles!Foo(".", "dub.json", false, 5);
	assert(rm.Get!Foo("dub.json") !is null);

	auto fe = new FileException("ahahaha");
	rm.register("Boom headshot", fe);
}