module nwn2.resman;


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
	void addRes(T)(in string sName, ref T res){
		TypeInfo ti = typeid(T);
		if(!(ti in m_loadedRes && sName in m_loadedRes[ti]))
			m_loadedRes[typeid(T)][sName] = res;
		else
			throw new ResourceException("Resource '"~sName~"' already exists");
	}


	///	Constructs a resource and add it to the manager
	///	Params:
	///		sName = Name of the resource to create
	///		ctorArgs = Arguments passed to the resource constructor
	///	Throws: ResourceException if the resource name already exists for this resource type
	///	Returns: the created resource
	ref T createRes(T, VT...)(in string sName, VT ctorArgs){
		T res = new T(ctorArgs);
		addRes!T(sName, res);
		return *(cast(T*)&(m_loadedRes[typeid(T)][sName]));
	}

	///	Removes a resource from the manager
	///	Will let the D garbage collector handle destruction if not used somewhere else
	///	Params:
	///		sName = registered name of the resource
	///		bForce = true to force destruction (can cause seg faults if the resource is used somewhere else)
	///	Throws: ResourceException if the resource name does not exist
	void removeRes(T)(in string sName, bool bForce=false){
		TypeInfo ti = typeid(T);
		if(!(ti in m_loadedRes && sName in m_loadedRes[ti])){
			if(bForce)
				destroy(m_loadedRes[typeid(T)][sName]);
			else
				m_loadedRes[typeid(T)][sName] = null;
		}
		else
			throw new ResourceException("Resource '"~sName~"' not found");
	}


	///	Gets the resource with its name
	///	Throws: ResourceException if the resource name does not exist
	ref T get(T)(in string sName){
		TypeInfo ti = typeid(T);
		if(ti in m_loadedRes && sName in m_loadedRes[ti])
			return *(cast(T*)&(m_loadedRes[ti][sName]));

		throw new ResourceException("Resource '"~sName~"' not found");
	}

	///	Loads the resources contained in directory matching filePatern
	///	The first argument of the resource constructor must be a DirEntry, followed by any arguments provided with ctorArgs
	///	Params:
	///		directory = Path of the folder to search into
	///		filePatern = file patern to load (ie: "*", "*.vtx", ...)
	///		recursive = true to search in subfolders
	///		ctorArgs = Arguments passed to the resource constructor
	void loadFromFiles(T, VT...)(in string directory, in string filePatern, in bool recursive, VT ctorArgs){
		import std.path : dirSeparator;

		foreach(ref file ; dirEntries(directory, filePatern, recursive?SpanMode.depth:SpanMode.shallow)){
			if(file.isFile){
				string sName = file.name.chompPrefix(directory~dirSeparator);
				createRes!T(sName, file, ctorArgs);
			}
		}
	}


	void cachePath(){
		foreach(p ; path){
			if(p.exists && p.isDir){
				foreach(ref file ; dirEntries(p, SpanMode.depth)){
					if(file.isFile){
						cachedFiles[file.baseName.toLower] = DirEntry(file.name);
					}
				}
			}
		}
	}



	T findFileRes(T)(in string fileName){
		try return get!T(fileName);
		catch(ResourceException e){
			if(fileName.toLower in cachedFiles){
				return createRes!T(fileName, cachedFiles[fileName.toLower]);
			}
			foreach(p ; path){
				if(p.exists && p.isDir){
					foreach(ref file ; dirEntries(p, SpanMode.depth)){
						if(file.isFile && filenameCmp!(CaseSensitive.no)(file.name.baseName, fileName)==0){
							//info("Loaded ",fileName," from ",file.name);
							return createRes!T(fileName, file);
						}
					}
				}
			}

			throw new ResourceException("Resource '"~fileName~"' not found in path");
		}
	}
	string findFilePath(in string fileName){
		foreach(p ; path){
			if(fileName.toLower in cachedFiles){
				return cachedFiles[fileName.toLower];
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
	__gshared string[] path;



private:
	this(){}
	__gshared Object[string][TypeInfo] m_loadedRes;
	__gshared DirEntry[string] cachedFiles;
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
	rm.AddRes("yolo", foo);

	assert(rm.Get!Foo("yolo") == foo);
	assert(rm.Get!Foo("yolo") is foo);

	rm.LoadFromFiles!Foo(".", "dub.json", false, 5);
	assert(rm.Get!Foo("dub.json") !is null);

	auto fe = new FileException("ahahaha");
	rm.AddRes("Boom headshot", fe);
}