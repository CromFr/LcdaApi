module nwn.lcdacompat;

string journalVarToTag(in string journalVar){
	switch(journalVar){
		case "j1": return "quete_auservicedunpeureux";
		case "j2": return "quete_mineraijorik";
		case "j3": return "quete_rats";
		case "j4": return "quete_enlevementmeribona";
		case "j5": return "quete_pierrederappelgalaetor";
		case "j6": return "quete_casque_herbert";
		case "j7": return "quete_nettoyerlavermine";
		case "j8": return "quete_poissonnier";
		case "j9": return "quete_preuvesanglante";
		case "j10": return "quete_romeofaitsonromeo";
		case "j11": return "quete_dentsdorc";
		case "j12": return "quete_tourdesmagespierre";
		case "j13": return "quete_nessie";
		case "j14": return "quete_tuergramshh";
		case "j15": return "quete_trappeur";
		case "j16": return "quete_queuelezard";
		case "j17": return "quete_tuershalva";
		case "j18": return "quete_elementaires";
		case "j19": return "quete_herisson";
		case "j20": return "quete_kahrk";
		case "j21": return "quete_wiverne";
		case "j22": return "quete_mineraiadamantium";
		case "j23": return "quete_eowildir";
		case "j24": return "quete_espritimaskari";
		case "j25": return "quete_residuspectral";
		case "j26": return "quete_convoidetresse";
		case "j27": return "quete_grabugeaubateauivre";
		case "j28": return "quete_gnolls";
		case "j29": return "quete_anneauxgnolls";
		case "j30": return "quete_recherche";
		case "j31": return "quete_spectres";
		case "j32": return "quete_tishiste";
		case "j33": return "quete_mephos";
		case "j34": return "quete_pirates";
		case "j35": return "quete_epervier";
		case "j36": return "quete_ossement";
		case "j37": return "quete_zherghul";
		case "j38": return "quete_ibee";
		case "j39": return "quete_crane";
		case "j40": return "quete_tentacule_boss";
		case "j41": return "quete_venin";
		case "j42": return "quete_boss_araignee";
		case "j43": return "quete_poudre_fee";
		case "j44": return "quete_ailedragon_boss";
		case "j45": return "quete_brochealenna";
		case "j46": return "quete_dinerdecon";
		case "j47": return "quete_epeejerk";
		case "j48": return "quete_chatperdu";
		case "j49": return "quete_cartestresor";
		case "j50": return "quete_fees";
		case "j51": return "quete_artefact";
		case "j52": return "serpent";
		case "j53": return "quete_geants";
		case "j54": return "quete_choseoutremonde";
		case "j55": return "quete_tetesgeants";
		case "j56": return "quete_poeme_elrendir";
		case "j57": return "quete_ames_torturees";
		case "j58": return "quete_enfant_citadelle";
		case "j59": return "quete_berenice_citadelle";
		case "j60": return "quete_secrets_citadelle";
		case "j61": return "quete_seigneur_damne";
		case "j62": return "quete_taskylos";
		//case "j63": return "quete_illithids";
		default: assert(0, "Unknown journal variable: '"~journalVar~"'");
	}
}



private struct Dungeon{
	string name;
	string areaResref;
	string bossKilledVar;//VARNAME for a journalNODROP var, or DBNAME.VARNAME for a campaign var
	string chestVar;
}

enum Dungeons: Dungeon {
	Rats           = Dungeon("Rats",                  "eauprofonde-souterrains",          "ROIRATS",                      "COFFRE_ROI_RATS"),
	Gobelins       = Dungeon("Gobelins",              "eauprofonde-portes-gobelins",      "QUETE.ROIGOB",                 "QUETE.COFFREROIGOB"),
	Contrebandiers = Dungeon("Contrebandiers",        "eauprofonde-anciennes_mines",      "annexe.MORGANE",               "QUETE.COFFREMORGANE"),
	Gnolls         = Dungeon("Gnolls",                "ravinyard",                        "annexe.SYKHO",                 "QUETE.COFFREGNOLLS"),
	Orcs           = Dungeon("Orcs",                  "lurkwood-fortin_orc",              "QUETE.GRAMSHH",                "QUETE.COFFREGRAMSHH"),
	DesoCrypte     = Dungeon("Cimetière",             "desolation-crypte",                "annexe.FARGOL",                "QUETE.COFFRECIMETIERE"),
	Elementaires   = Dungeon("Élémentaires d'eau",    "front_de_mer-caverne_innondee",    "QUETE.GOLGOTH",                "QUETE.COFFREGOLGOTH"),
	Spectres       = Dungeon("Spectres",              "lurkwood-grotte_hantee",           "QUETE.ESPRITANTIQUE",          "QUETE.COFFREESPRITANTIQUE"),
	Araignees      = Dungeon("Araignées",             "desolation-foret",                 "annexe.ARAIGNEEBOSS",          "QUETE.COFFREARAIGNEE"),
	Lezards        = Dungeon("Lézards",               "marais_du_lezard",                 "QUETE.SHALVA",                 "QUETE.COFFRESHALVA"),
	DesoCollines   = Dungeon("Désolation - Collines", "desolation-collines",              "annexe.LEVIATHAN",             "QUETE.COFFRECOLLINE"),
	Ogres          = Dungeon("Ogres",                 "epinedorsale-galeries",            "QUETE.KAHRKMORT",              "QUETE.COFFREKAHRK"),
	Wyvernes       = Dungeon("Wyvernes",              "epinedorsale-wivernes",            "QUETE.WIVERNECHEFMORT",        "QUETE.COFFREWIVERNE"),
	Drows          = Dungeon("Drows",                 "ombreterre-forteresse_drow",       "QUETE.BOSSDROWMORT",           "QUETE.COFFREBOSSDROW"),
	Fees           = Dungeon("Fées",                  "lurkwood-racines-niveau1",         "annexe.FAFNER",                "QUETE.COFFREFEES"),
	IleMaudite     = Dungeon("Ile maudite",           "ile_maudite",                      "annexe.ZHERGHUL",              "QUETE.COFFREZHERGHUL"),
	DesertRuines   = Dungeon("Désert - Ruines",       "desert_anauroch-ruines",           "QUETE.MEPHOS",                 "QUETE.COFFREMEPHOS"),
	Pirates        = Dungeon("Pirates",               "front_de_mer-antre_pirates",       "annexe.BARBAROSSA",            "QUETE.COFFREPIRATES"),
	Dorn           = Dungeon("Dorn",                  "ombreterre-dorn-hall",             "QUETE.DornChest_BossKilled",   "QUETE.DornChest_Looted"),
	Dregs          = Dungeon("Dregs",                 "desert_anauroch_repaire_dreg",     "QUETE.BOSSDREGMORT",           "QUETE.COFFREBOSSDREG"),
	Imaskari       = Dungeon("Imaskaris",             "lurkwood-atelier_imaskari",        "QUETE.CHOSEOUTREMONDEMORTE",   "QUETE.COFFRECHOSEOUTREMONDE"),
	Illithids      = Dungeon("Illithids",             "marais-enclave_illithid",          "QUETE.GLANCEPHALEMORT",        "QUETE.COFFREGLANCEPHALE"),
	SeigneurDamne  = Dungeon("Seigneur damné",        "ile_des_g-caverne_maudite",        "QUETE.SEIGNEURDAMNEMORT",      "QUETE.COFFRESEIGNEURDAMNE"),
	Labyrinthe     = Dungeon("Labyrinthe",            "ile_des_g-etrange_grotte",         "QUETE.LABYRINTHEMORT",         "QUETE.COFFRELABYRINTHE"),
	Driders        = Dungeon("Driders",               "ombreterre-taniere_driders",       "QUETE.BOSSDRIDERMORT",         "QUETE.COFFREBOSSDRIDER"),
	Saisons        = Dungeon("Saisons",               "ile_saisons-temple_printemps-rdc", "QUETE.AVATARISHTARMORT",       "QUETE.COFFREAVATARISHTAR"),
	Faconneur      = Dungeon("Façonneur",             "lurkwood-secret",                  "QUETE.BOSSSECRETLURKWOODMORT", "QUETE.COFFRELURKWOODSECRET"),
	Geants         = Dungeon("Géants des glaces",     "epinedorsale-grotte_geant",        "HIRKA",                        "COFFRE_HIRKA"),
	DragonBlanc    = Dungeon("Dragon blanc",          "ile_des_g-caverne_elhandir",       "QUETE.ELHANDIRMORT",           null),
	Dedale         = Dungeon("Dédale",                "desert_anauroch-dedale_rdc",       "QUETE.BOSSDEDALEMORT",         "QUETE.COFFREBOSSDEDALE"),
	Tyrannoeils    = Dungeon("Tyrannoeils",           "ombreterre-antre_tyrannoeils",     "QUETE.BOSSTYRANNOEILSMORT",    "QUETE.COFFREBOSSTYRANNOEILS"),
	Mintarn        = Dungeon("Mintarn",               "citadelle-rez_de_chausse",         "QUETE.SEIGNEURKRANTARMORT",    "QUETE.COFFRESEIGNEURKRANTAR"),
}

string diffPrefix(uint i){
	import std.conv: to;
	return i==0? null : "d"~i.to!string~"_";
}