module lcda.item;

import std.string;
import std.conv;

import nwn.fastgff;
import nwn.tlk;
import nwn.twoda;

import api.apidef;
import resourcemanager;

public import api.apidef: Item;



/// Converts a NWItemproperty into string identical to the property in-game description
Item toItem(in GffStruct gff){
	import nwn.nwscript.extensions;
	import nwn.types: NWItemproperty;
	const resolv = ResourceManager.get!StrRefResolver("resolver");
	const icons2DA = ResourceManager.fetchFile!TwoDA("nwn2_icons.2da");
	const props2DA = ResourceManager.fetchFile!TwoDA("itempropdef.2da");
	const costTable2DA = ResourceManager.fetchFile!TwoDA("iprp_costtable.2da");
	const paramTable2DA = ResourceManager.fetchFile!TwoDA("iprp_paramtable.2da");

	string toDescription(in NWItemproperty ip){

		string propName;
		string subType;
		string costValue;
		string paramValue;

		propName = resolv[props2DA.get("GameStrRef", ip.type, 0)];

		string subTypeTable = props2DA.get("SubTypeResRef", ip.type, "").toLower;
		if(subTypeTable != ""){
			int strref = ResourceManager.fetchFile!TwoDA(subTypeTable ~ ".2da").get("Name", ip.subType, 0);
			if(strref > 0)
				subType = resolv[strref];
		}
		string costValueTableId = props2DA.get("CostTableResRef", ip.type, "");
		if(costValueTableId != ""){
			string costValueTable = costTable2DA.get("Name", costValueTableId.to!int).toLower;
			int strref = ResourceManager.fetchFile!TwoDA(costValueTable ~ ".2da").get("Name", ip.costValue, 0);
			if(strref > 0)
				costValue = resolv[strref];
		}

		string paramTableId = props2DA.get("Param1ResRef", ip.type);
		if(paramTableId != ""){
			string paramTable = paramTable2DA.get("TableResRef", paramTableId.to!int).toLower;
			int strref = ResourceManager.fetchFile!TwoDA(paramTable ~ ".2da").get("Name", ip.p1, 0);
			if(strref > 0)
				paramValue = resolv[strref];
		}
		return propName
			~ (subType !is null ? " " ~ subType : null)
			~ (costValue !is null ? " " ~ costValue : null)
			~ (paramValue !is null ? " " ~ paramValue : null);
	}

	Item item;
	item.name = removeBracedText(gff["LocalizedName"].get!GffLocString.resolve(resolv));
	item.type = gff["BaseItem"].get!GffInt;
	item.stack = gff["StackSize"].get!GffWord;
	item.icon = icons2DA.get("icon", gff["Icon"].get!GffDWord);
	foreach(_, ipGff ; gff["PropertiesList"].get!GffList){
		item.properties ~= toDescription(ipGff.toNWItemproperty);
	}
	return item;
}


string removeBracedText(in string text){
	int i = 0;
	char[] ret;
	ret.length = text.length;

	uint brackDepth = 0;
	foreach(c ; text){
		switch(c){
			case '{':
				brackDepth++;
				break;
			case '}':
				if(brackDepth > 0){
					brackDepth--;
					break;
				}
				goto default;
			default:
				if(brackDepth == 0)
					ret[i++] = c;
		}
	}
	ret.length = i;
	return cast(immutable)ret;
}
unittest{
	assert(removeBracedText("hello{}world") == "helloworld");
	assert(removeBracedText("h{ellowo}rld") == "hrld");
	assert(removeBracedText("h{ello{d}wo}rld") == "hrld");
}