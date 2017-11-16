module cache;

import std.traits;
import std.datetime: SysTime, Clock;

class Cache {
static:

	auto ref T get(T)(in string name, bool function(in T cachedObject, SysTime lastAccess) isExpired, T delegate() ctor)
	if(is(T: CopyConstness!(T, Object))){

		static if(is(T == const) || is(T == immutable))
			alias cache = sharedCache;
		else
			alias cache = tlsCache;

		auto cacheTable = typeid(T) in cache;
		if(!cacheTable){
			cache[typeid(T)] = null;
			cacheTable = typeid(T) in cache;
		}

		auto cacheEntry = name in *cacheTable;
		if(cacheEntry && !isExpired(cast(T)cacheEntry.data, cacheEntry.lastAccess)){
			// return existing
			cacheEntry.lastAccess = Clock.currTime();
			return cast(T)cacheEntry.data;
		}
		// Insert new one
		return cast(T)
			((*cacheTable)[name] = CacheEntry(
				cast(Object)ctor(),
				cast(bool function(in Object, SysTime))isExpired,
				Clock.currTime())
			).data;
	}

	auto ref T get(T)(in string name, bool function(in T cachedObject, SysTime lastAccess) isExpired, T delegate() ctor)
	if(!is(T: CopyConstness!(T, Object))){

		alias Type = CopyConstness!(T, Wrapper!T);
		return get!Type(
			name,
			function(in Type wrap, SysTime lastAccess){ return wrap.isExpired(wrap.inner, lastAccess); },
			() => new Type(ctor(), isExpired)
		).inner;
	}

	/// Warning: the retrieved object must exist
	auto ref T get(T)(in string name) inout{
		static if(is(T == const) || is(T == immutable))
			alias cache = sharedCache;
		else
			alias cache = tlsCache;
		return cache[typeid(T)][name];
	}

	/// Reduce cache size by removing expired cache objects
	void reduce(){
		foreach(ref cache ; [tlsCache, sharedCache]){
			foreach(ref table ; cache){
				foreach(entryKV ; table.byKeyValue){
					if(entryKV.value.isExpired(entryKV.value.data, entryKV.value.lastAccess)){
						table.remove(entryKV.key);
					}
				}
			}
		}

	}

private:

	CacheEntryTable[TypeInfo] tlsCache;
	__gshared CacheEntryTable[TypeInfo] sharedCache;

	alias CacheEntryTable = CacheEntry[string];
	static struct CacheEntry{
		Object data;
		bool function(in Object, SysTime) isExpired;
		SysTime lastAccess;
	}

	static class Wrapper(T){
		this(T inner, bool function(in T, SysTime) isExpired){
			this.inner = inner;
			this.isExpired = isExpired;
		}

		T inner;
		bool function(in T, SysTime) isExpired;
	}

}
