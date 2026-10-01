import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
genera=json.loads((root/"App/Resources/genera.json").read_text(encoding="utf-8"))
render_by={} # Original rendering variability metadata is unavailable; explicitly unknown.
# --- Horticultural/game-design classification.
# It intentionally models a representative garden image for each genus,
# not every species in the genus. Ambiguous genera are marked accordingly. ---

trees = set("""Abies Acacia Acer Amygdalus Armeniaca Cerasus Chamaecyparis Citrus Cornus Cupressus Eucalyptus Ficus Fraxinus Magnolia Metasequoia Mimosa Olea Pachira Phoenix Pinus Prunus Salix""".split())
shrubs = set("""Abelia Abutilon Ardisia Aucuba Boronia Buddleja Calluna Camellia Chamelaucium Chaenomeles Codiaeum Cotinus Cytisus Daphne Deutzia Duranta Enkianthus Erica Forsythia Fuchsia Gardenia Gaultheria Gossypium Hibiscus Hydrangea Hypericum Ilex Ixora Kalmia Lantana Lavandula Leptospermum Luculia Nandina Philadelphus Physocarpus Pieris Pittosporum Pyracantha Rhododendron Rosa Rosmarinus Rubus Skimmia Spiraea Syringa Vaccinium Viburnum Weigela""".split())
vines = set("""Bougainvillea Clematis Gloriosa Hedera Ipomoea Jasminum Lathyrus Mandevilla Passiflora Smilax Stephanotis Trachelospermum Tropaeolum Vitis Wisteria""".split())
ferns = set("""Adiantum Asplenium Nephrolepis Rumohra""".split())
grasslike = set("""Acorus Carex Chlorophytum Hordeum Miscanthus Ophiopogon Oryza Phormium""".split())
geophytes = set("""Agapanthus Allium Alstroemeria Crocus Curcuma Cyclamen Freesia Gladiolus Gloriosa Hippeastrum Hyacinthus Iris Lilium Lycoris Muscari Narcissus Nerine Ornithogalum Polygonatum Rhodohypoxis Sandersonia Scilla Tulipa Zephyranthes Zantedeschia""".split())
succulents = set("""Aloe Crassula Kalanchoe Lampranthus Portulaca Sansevieria Schlumbergera Sedum""".split())
aquatics = set("""Nelumbo Nymphaea""".split())
epiphytes = set("""Cattleya Cymbidium Dendrobium Guzmania Phalaenopsis Tillandsia Vanda""".split())
palms_cycads = set("""Chamaedorea Cycas Phoenix""".split())
tropical_foliage = set("""Anthurium Caladium Codiaeum Cordyline Dieffenbachia Dracaena Epipremnum Monstera Pachira Peperomia Philodendron Saintpaulia Schefflera Spathiphyllum Strelitzia""".split())

wetland = set("""Acorus Equisetum Iris Lythrum Nelumbo Nymphaea Zantedeschia""".split())
dry = set("""Achillea Actinotus Aloe Armeria Calluna Crassula Eryngium Gazania Helichrysum Kalanchoe Lampranthus Lavandula Leptospermum Portulaca Rosmarinus Sansevieria Sedum Thymophylla Yucca""".split())
shade = set("""Adiantum Ajuga Asplenium Aucuba Caladium Convallaria Cyclamen Dieffenbachia Epipremnum Helleborus Heuchera Hosta Monstera Nephrolepis Ophiopogon Pachira Peperomia Philodendron Polygonatum Rumohra Saintpaulia Sarcandra Schefflera Spathiphyllum Tricyrtis""".split())
partshade = set("""Abelia Ardisia Astilbe Begonia Camellia Daphne Enkianthus Fuchsia Gardenia Gaultheria Hydrangea Impatiens Kalmia Pieris Primula Rhododendron Skimmia Viburnum""".split())
fullsun = set("""Acacia Achillea Agapanthus Ageratum Allium Alyssum Amaranthus Arctotis Argyranthemum Armeria Brassica Calendula Calibrachoa Callistephus Canna Capsicum Carthamus Celosia Centaurea Chrysanthemum Cosmos Craspedia Dahlia Dimorphotheca Echinops Eryngium Eucalyptus Euphorbia Euryops Felicia Gaillardia Gazania Gerbera Gladiolus Gomphrena Helianthus Helichrysum Heliopsis Hibiscus Lantana Lavandula Liatris Limonium Lobularia Lupinus Miscanthus Oenothera Olea Osteospermum Papaver Pelargonium Pentas Petunia Portulaca Rudbeckia Salvia Scabiosa Solidago Tagetes Thymophylla Verbena Veronica Zinnia""".split())
moist = set("""Acorus Adiantum Astilbe Begonia Caladium Canna Carex Equisetum Hosta Hydrangea Impatiens Iris Lythrum Monstera Nephrolepis Oryza Spathiphyllum Tricyrtis Zantedeschia""".split())

tropical = set("""Anthurium Bougainvillea Caladium Canna Catharanthus Cattleya Chamaedorea Codiaeum Cordyline Crossandra Curcuma Dieffenbachia Dracaena Duranta Epipremnum Ficus Gardenia Guzmania Heliconia Hibiscus Ixora Mandevilla Monstera Pachira Pentas Peperomia Phalaenopsis Philodendron Phoenix Saintpaulia Schefflera Spathiphyllum Stephanotis Strelitzia Tillandsia Vanda Zantedeschia""".split())
warm = set("""Abutilon Aloe Alstroemeria Boronia Chamelaucium Chlorophytum Citrullus Citrus Crassula Crowea Cucumis Cucurbita Cuphea Eucalyptus Evolvulus Kalanchoe Lampranthus Lantana Leptospermum Nandina Nerine Passiflora Phormium Pittosporum Portulaca Sansevieria Schlumbergera Solanum Tropaeolum Yucca""".split())
cool = set("""Abies Adonis Calluna Crocus Cyclamen Erica Gentiana Helleborus Hyacinthus Kalmia Lycoris Muscari Narcissus Primula Rhodohypoxis Scilla Tulipa Vaccinium""".split())

waterside_named = set("""Acorus Canna Carex Equisetum Iris Lythrum Nelumbo Nymphaea Oryza Zantedeschia""".split())
woodland_named = set("""Adiantum Ajuga Asplenium Aucuba Convallaria Cyclamen Helleborus Hosta Nephrolepis Ophiopogon Polygonatum Rumohra Sarcandra Tricyrtis""".split())
woodland_edge_named = set("""Abelia Ardisia Astilbe Camellia Daphne Enkianthus Fuchsia Gaultheria Hydrangea Kalmia Pieris Primula Rhododendron Skimmia Viburnum""".split())

spring = set("""Adonis Alyssum Amygdalus Anemone Armeniaca Bellis Brassica Calendula Camellia Cerasus Chaenomeles Crocus Cyclamen Daphne Forsythia Freesia Helleborus Hyacinthus Iberis Magnolia Muscari Myosotis Narcissus Nemophila Ornithogalum Paeonia Papaver Primula Prunus Ranunculus Rhodanthe Rhododendron Scilla Tulipa Viola Wisteria""".split())
summer = set("""Agapanthus Alstroemeria Anthurium Canna Catharanthus Celosia Cosmos Dahlia Eustoma Gazania Gerbera Gladiolus Helianthus Hemerocallis Hibiscus Hydrangea Impatiens Iris Lantana Lavandula Liatris Lilium Lythrum Mandevilla Nelumbo Nymphaea Pentas Petunia Portulaca Rudbeckia Salvia Tagetes Torenia Zinnia""".split())
autumn = set("""Aster Chrysanthemum Cosmos Dahlia Helichrysum Miscanthus Nandina Salvia Solidago Zinnia""".split())
winter = set("""Camellia Cyclamen Helleborus Narcissus Skimmia""".split())

def growth_form(n):
    if n in palms_cycads: return "palm_cycad"
    if n in aquatics: return "aquatic"
    if n in epiphytes: return "epiphyte"
    if n in ferns: return "fern"
    if n in succulents: return "succulent"
    if n in vines: return "vine"
    if n in trees: return "tree"
    if n in shrubs: return "shrub"
    if n in grasslike: return "grasslike"
    if n in geophytes: return "geophyte"
    if n in tropical_foliage: return "tropical_foliage"
    return "herb"

def sunlight(n):
    if n in shade: return "shade"
    if n in partshade: return "part_shade"
    if n in fullsun or n in dry: return "sun"
    gf = growth_form(n)
    if gf in ("tropical_foliage","fern","epiphyte"): return "part_shade"
    return "sun_part"

def moisture(n):
    if n in aquatics: return "aquatic"
    if n in wetland or n in waterside_named: return "wet"
    if n in moist or n in shade or n in woodland_named: return "moist"
    if n in dry or growth_form(n) == "succulent": return "dry"
    return "average"

def climate(n):
    if n in tropical: return "tropical"
    if n in warm: return "warm"
    if n in cool: return "cool"
    return "temperate"

def season_affinity(n):
    vals=[]
    if n in spring: vals.append("spring")
    if n in summer: vals.append("summer")
    if n in autumn: vals.append("autumn")
    if n in winter: vals.append("winter")
    return vals or ["multi"]

def default_size(gf):
    return {
        "tree":"XL","palm_cycad":"XL","shrub":"L","vine":"M","tropical_foliage":"L",
        "aquatic":"L","epiphyte":"M","fern":"M","succulent":"M","grasslike":"M",
        "geophyte":"M","herb":"M"
    }[gf]

def placement_type(gf, n):
    if gf == "tree" or gf == "palm_cycad": return ["tree_ground"]
    if gf == "aquatic": return ["water_surface","water_bed"]
    if gf == "vine": return ["trellis","ground_edge"]
    if gf == "epiphyte": return ["pot","mounted","greenhouse_bench"]
    if n in wetland or n in waterside_named: return ["wet_edge","ground"]
    if gf == "succulent": return ["ground","rock_pocket","pot"]
    return ["ground","bed","pot"]

sun_factors = {
    "sun": (1.0,0.35,0.05),
    "sun_part": (0.75,0.75,0.2),
    "part_shade": (0.35,1.0,0.55),
    "shade": (0.05,0.55,1.0),
}
moist_factors = {
    "dry": (1.0,0.35,0.05,0.0),
    "average": (0.35,1.0,0.4,0.05),
    "moist": (0.1,0.55,1.0,0.4),
    "wet": (0.0,0.2,0.85,1.0),
    "aquatic": (0.0,0.0,0.2,1.0),
}

zone_ids = ["sunny_border","meadow","woodland_edge","woodland_shade","waterside","dry_rock","grove","greenhouse"]

def habitat_scores(n):
    gf, su, mo, cl = growth_form(n), sunlight(n), moisture(n), climate(n)
    sunv, partv, shadev = sun_factors[su]
    dryv, avgv, moistv, wetv = moist_factors[mo]
    herb = 1 if gf in ("herb","geophyte") else 0
    ground = 1 if gf in ("herb","grasslike","geophyte") else 0
    woody = 1 if gf in ("tree","shrub","palm_cycad") else 0
    treeish = 1 if gf in ("tree","palm_cycad") else 0
    succ = 1 if gf=="succulent" else 0
    aquatic = 1 if gf=="aquatic" else 0
    tropicality = {"tropical":1.0,"warm":0.7,"temperate":0.2,"cool":0.0}[cl]

    raw = {}
    raw["sunny_border"] = 0.38*sunv + 0.27*avgv + 0.20*herb + 0.08*(gf=="shrub") + 0.07*(n in fullsun)
    raw["meadow"] = 0.34*sunv + 0.20*(dryv+avgv)/2 + 0.34*ground + 0.12*(gf=="grasslike")
    raw["woodland_edge"] = 0.38*partv + 0.22*(avgv+moistv)/2 + 0.20*(gf in ("shrub","herb","geophyte")) + 0.20*(n in woodland_edge_named)
    raw["woodland_shade"] = 0.42*shadev + 0.25*moistv + 0.18*(gf in ("fern","herb","geophyte","tropical_foliage")) + 0.15*(n in woodland_named)

    water_raw = 0.42*wetv + 0.25*aquatic + 0.16*moistv + 0.10*(gf in ("grasslike","geophyte","herb")) + 0.07*(n in waterside_named)
    wetland_raw = 0.34*wetv + 0.26*moistv + 0.20*(gf in ("grasslike","herb","geophyte")) + 0.20*(n in wetland)
    raw["waterside"] = max(water_raw, wetland_raw*0.96)

    raw["dry_rock"] = 0.44*dryv + 0.28*succ + 0.16*sunv + 0.12*(n in dry)
    raw["grove"] = 0.48*woody + 0.20*(partv+sunv)/2 + 0.15*avgv + 0.10*treeish + 0.07*(gf=="vine")
    raw["greenhouse"] = 0.42*tropicality + 0.22*(gf in ("tropical_foliage","epiphyte","palm_cycad")) + 0.16*partv + 0.10*moistv + 0.10*(n in tropical)
    if gf == "vine":
        raw["woodland_edge"] += 0.08
        raw["grove"] += 0.08
        if cl in ("tropical","warm"):
            raw["greenhouse"] += 0.08

    return {k: round(min(1.0, max(0.0, float(v))), 3) for k,v in raw.items()}

rows=[]
for g in genera:
    n=g["latin"]
    scores=habitat_scores(n)
    ranked=sorted(scores.items(), key=lambda kv:kv[1], reverse=True)
    rmeta=render_by.get(n,{}).get("render",{})
    variability=rmeta.get("intragenusVariability","unknown")
    confidence="medium"
    if variability in ("高","high"):
        confidence="low"
    elif n in (trees|shrubs|vines|ferns|grasslike|geophytes|succulents|aquatics|epiphytes|palms_cycads|tropical_foliage):
        confidence="medium_high"

    rows.append({
        "latin": n,
        "read": g["read"],
        "family": g["family"],
        "oldFamily": g["oldFamily"],
        "japaneseName": g["jpName"],
        "note": g["note"],
        "gardenAttributes": {
            "growthForm": growth_form(n),
            "sunlight": sunlight(n),
            "moisture": moisture(n),
            "climate": climate(n),
            "seasonAffinity": season_affinity(n),
            "defaultSizeClass": default_size(growth_form(n)),
            "placementTypes": placement_type(growth_form(n), n),
        },
        "habitatScores": scores,
        "recommendedZones": [ranked[0][0], ranked[1][0]],
        "classificationConfidence": confidence,
        "intragenusVariability": variability,
        "renderRef": rmeta,
    })


(root/"App/Resources/habitatAttributes.json").write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding="utf-8")
