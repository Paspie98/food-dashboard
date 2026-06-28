// commodity_glossary.js — STATIC DESCRIPTIVE DICTIONARY for the info bubbles (M13).
// DESCRIPTIVE FACT ONLY: definitions, uses, abbreviation expansions, pricing-basis explanations.
// This is NOT analysis and NOT market commentary. No prices, no direction, no judgement here —
// the per-card analysis slots stay empty for the Claude layer. No external resources.
//
// Note on distinct identities (encoded by design): ammonia, if ever wired, is its OWN line in the
// Nitrogen family and is NEVER merged into urea ("urea = nitrogen") — urea is made FROM ammonia but
// is a distinct traded product. Likewise raw vs white sugar and oilseed vs refined oil stay separate.
window.COMMODITY_GLOSSARY = {
  // one-line plain-language gloss per commodity (keyed by the registry's `commodity` field)
  byCommodity: {
    'wheat': 'Staple milling grain for flour — bread, biscuits, pasta. Traded by class (hard/soft, winter/spring).',
    'maize': 'Corn — a feed grain and the source of starch, glucose syrup and corn oil across processed foods.',
    'soybean oil': 'Refined oil pressed from soybeans; a major frying and formulation oil and a biodiesel feedstock.',
    'palm oil': 'The highest-volume vegetable oil; semi-solid, used in bakery, spreads, confectionery and frying.',
    'sunflower oil': 'Light frying and bottling oil; the Black Sea region is the dominant supplier.',
    'rapeseed oil': 'Canola-type oil; the main EU-grown vegetable oil, used for frying, margarine and biodiesel.',
    'butter': 'Dairy fat (about 80% milkfat) for bakery, confectionery and spreads.',
    'SMP': 'Skimmed milk powder — dried fat-free milk solids; a milk-protein ingredient for recombined dairy, bakery and confectionery.',
    'raw sugar': 'Unrefined cane sugar traded internationally; the feedstock refined into white sugar.',
    'white sugar': 'Refined sugar as food producers buy it (cane or beet); the EU market is largely beet-based.',
    'cocoa': 'Cocoa beans — ground into liquor, butter and powder for chocolate and confectionery.',
    'coffee arabica': 'The milder, higher-grade coffee species, grown at altitude; the larger share of world output.',
    'coffee robusta': 'The more bitter, higher-caffeine coffee species; used in instant coffee and espresso blends.',
    'eggs': 'Shell eggs and egg products for bakery, sauces and prepared foods; priced by farming method and grade.',
    'urea': 'The most-traded nitrogen fertiliser (46% N), made from ammonia and CO2. Ammonia is its upstream feedstock and a distinct product.',
    'DAP': 'Diammonium phosphate — the leading traded phosphate fertiliser, supplying phosphorus plus some nitrogen.',
    'TSP': 'Triple superphosphate — a high-analysis phosphate fertiliser.',
    'phosphate rock': 'The mined raw material upstream of DAP, TSP and other phosphate fertilisers.',
    'potash': 'Muriate of potash (potassium chloride) — the main potassium (K) fertiliser.',
    'agricultural lime': 'Ground limestone used to raise soil pH; a soil conditioner rather than a nutrient fertiliser.',
    'crude oil WTI': 'West Texas Intermediate — the US benchmark grade of crude oil.',
    'crude oil Brent': 'The global benchmark grade of crude oil, priced from North Sea fields.',
    'natural gas': 'Process fuel and the feedstock for nitrogen fertiliser; priced regionally (the European reference here).',
    'natural gas Henry Hub': 'The US natural-gas benchmark, priced at Henry Hub in Louisiana.',
    'coal': 'Thermal coal for power and high-heat processing such as glass.',
    'diesel': 'Road-freight and machinery fuel; the main haulage cost in food distribution.',
    'gasoline': 'Petrol — light-vehicle fuel; a distribution-cost reference.',
    'trucking volume': 'An index of road-freight activity (a demand-side gauge), not a price.',
    'trucking rates': 'The producer price of long-distance truckload road freight.',
    'rail freight': 'The producer price of line-haul rail freight.',
    'ocean freight': 'The producer price of deep-sea shipping; an open proxy for the licensed container indices.',
    'land freight': 'The EU producer price of land transport services (road-dominated).',
    'pulp': 'Wood pulp — the fibre input to paper and paperboard packaging.',
    'containerboard': 'Mill board (linerboard and medium) converted into corrugated boxes.',
    'paper & containerboard': 'Converted paper and board packaging — boxes and cartons — as producers buy it.',
    'aluminium': 'Light metal for cans, foil and lidding; energy-intensive to smelt.',
    'glass': 'Container glass for jars and bottles.',
    'PET/plastics': 'Plastic resins (PET, polypropylene) upstream of bottles, films, trays and wraps.'
  },
  // row-level overrides where the registry `commodity` is generic (FAO composites; EU fertiliser composites)
  byRow: {
    'IX-001': { card: 'FAO Food Index', name: 'FAO Food Price Index', gloss: 'The UN FAO monthly index of world food commodity prices (2014-2016 = 100); the headline read across all groups.' },
    'IX-002': { card: 'FAO Cereals Index', name: 'FAO Cereals Price Index', gloss: 'FAO monthly index for the grains complex — an aggregate of cereal prices, not a single commodity.' },
    'IX-003': { card: 'FAO Veg-Oils Index', name: 'FAO Vegetable Oils Price Index', gloss: 'FAO monthly index across the vegetable-oils complex — an aggregate, not a single oil.' },
    'IX-004': { card: 'FAO Dairy Index', name: 'FAO Dairy Price Index', gloss: 'FAO monthly index across dairy products — an aggregate, not a single product.' },
    'IX-005': { card: 'FAO Sugar Index', name: 'FAO Sugar Price Index', gloss: 'FAO monthly index for world sugar — an aggregate read.' },
    'FE-006': { card: 'EU fertiliser index', name: 'EU producer prices — fertilisers & nitrogen compounds (index)', gloss: 'Eurostat factory-gate price index for the EU fertiliser and nitrogen-compound industry.' },
    'FE-007': { card: 'EU ag-input index', name: 'EU agricultural input price index — fertilisers', gloss: 'Eurostat index of fertiliser prices as farmers pay them (a purchased-input measure).' },
    'FE-008': { card: 'EU nitrogen (N)', name: 'EU nitrogen (N) fertiliser composite', gloss: 'DG AGRI EU-level nitrogen-fertiliser price (EUR/t); a distinct EU read alongside the global urea benchmark.' },
    'FE-010': { card: 'EU phosphate (P)', name: 'EU phosphate (P) fertiliser composite', gloss: 'DG AGRI EU-level phosphate-fertiliser price (EUR/t).' },
    'FE-011': { card: 'EU potash (K)', name: 'EU potash (K) fertiliser composite', gloss: 'DG AGRI EU-level potassium-fertiliser price (EUR/t).' }
  },
  // abbreviation expansions (shown in the bubble's full-name line)
  abbrev: {
    'DAP': 'Diammonium phosphate', 'TSP': 'Triple superphosphate', 'MOP': 'Muriate of potash (potassium chloride)',
    'SMP': 'Skimmed milk powder', 'WMP': 'Whole milk powder', 'PET': 'Polyethylene terephthalate', 'PP': 'Polypropylene',
    'HRW': 'Hard Red Winter wheat', 'SRW': 'Soft Red Winter wheat', 'WTI': 'West Texas Intermediate crude',
    'LME': 'London Metal Exchange', 'PPI': 'Producer Price Index', 'FAO': 'UN Food and Agriculture Organization',
    'CMO': 'World Bank Commodity Markets Outlook (Pink Sheet)', 'ICCO': 'International Cocoa Organization',
    'ICO': 'International Coffee Organization', 'EIA': 'US Energy Information Administration', 'BLS': 'US Bureau of Labor Statistics',
    'ATA': 'American Trucking Associations', 'MOP ': 'Muriate of potash'
  },
  // pricing-basis explanations (longest phrase wins; matched case-insensitively against the series name)
  basis: {
    'fob us gulf': 'FOB US Gulf — free-on-board at a US Gulf port: a global benchmark loading point, not a US-only price.',
    'fob black sea': 'FOB Black Sea — loaded free-on-board at a Black Sea export port (a key fertiliser/grain export region).',
    'fob morocco': 'FOB Morocco — loaded free-on-board at a Moroccan port (a leading phosphate exporter).',
    'fob vancouver': 'FOB Vancouver — loaded free-on-board at Vancouver (a leading potash export point).',
    'cif nw europe': 'CIF NW Europe — delivered to North-West European ports, with freight and insurance included in the price.',
    'fob ex-mill': 'FOB ex-mill — priced loaded at the crushing mill.',
    'export price gulf': 'Export price, Gulf — the export quote loaded at a US Gulf port (a world reference location).',
    'ex-works': 'Ex-works — priced at the seller’s gate, before any transport.',
    'national average': 'National average — the average physical market price reported across a country.',
    'packing station': 'Packing-station price — the price at the egg packing and grading station.',
    'lme-basis': 'LME-basis — referenced to London Metal Exchange cash settlement.',
    'fob': 'FOB (free-on-board) — priced loaded onto the vessel at the named port; the buyer pays onward freight.',
    'cif': 'CIF (cost, insurance & freight) — priced delivered to the destination port, freight and insurance included.'
  }
};
