import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';


const kRowCount = 10;
const kColCount = 18;


/// Dart script to generate the elementsGrid.json file
///
/// Each element is created from the elementsList. Atomic weight, category,
/// and app-specific colors are assigned based on the respective mappings.
/// Atomic weights are based on published IUPAC figures, while a short element
/// extract is sourced from Wikipedia.
///
/// Elements are arranged in a List representing the usual 10 x 18 grid of the
/// periodic table, in column-major ordering. Empty spaces are represented with nulls.
main() async {

  var extractMap = await getExtractMap();

  var gridList = List<Element>.filled(kRowCount * kColCount, null);
  for (var element in kElementsList) {
    gridList[(element.x) * kRowCount + (element.y)] = element;
  }

  var outputFile = File('assets/elementsGrid.json');
  var elements = {
    'elements' : gridList
        .map((element) => element?.toJson(extract: extractMap[element.title]))
        .toList(),
  };

  var outputSink = outputFile.openWrite()
    ..write(JsonEncoder.withIndent('  ').convert(elements));
  await outputSink.flush();
  await outputSink.close();

  print('Wrote to output file ${outputFile.path}');
}


Future<Map<String, String>> getExtractMap() async {
  var extractsMap = <String, String>{};
  var count = 20;

  Iterable<Element> remainingElements = List.from(kElementsList);

  do {
    var extractElements = remainingElements.take(count);
    remainingElements = remainingElements.skip(count);

    print('Obtaining extracts for '
        '${extractElements.first.symbol} - ${extractElements.last.symbol}');

    var response = await http.get(getUrl(extractElements));
    var pages = (jsonDecode(response.body)['query']['pages'] as List)
        .map((json) => Page.fromJson(json));

    for (var page in pages) {
      extractsMap[page.title] = page.extract;
    }

    await Future.delayed(Duration(milliseconds: 500)); // ample rate limiting
  } while (remainingElements.isNotEmpty);

  return extractsMap;
}

Uri getUrl(Iterable<Element> elements) {
  return Uri.https('en.wikipedia.org', '/w/api.php', {
    'action' : 'query',
    'prop' : 'extracts',
    'exintro' : 'true',
    'exsentences' : '5',
    'explaintext' : 'true',
    'format' : 'json',
    'formatversion' : '2',
    'titles' : elements.map((element) => element.title).join('|'),
  });
}


/// Class representing the categories of the chemical elements.
///
/// Elements are categorized based on metallic classification.
/// This class is enum-like, but with a corresponding label per category.
class Category {

  const Category._(this.label);

  final String label;

  static List<Category> get values => [
    alkaliMetal, alkalineEarthMetal, lanthanide, actinide, transitionMetal,
    postTransitionMetal, metalloid, reactiveNonmetal, nobleGas, unknown,
  ];

  static const alkaliMetal         = Category._('Alkali Metal');
  static const alkalineEarthMetal  = Category._('Alkaline Earth Metal');
  static const lanthanide          = Category._('Lanthanide');
  static const actinide            = Category._('Actinide');
  static const transitionMetal     = Category._('Transition Metal');
  static const postTransitionMetal = Category._('Post-transition Metal');
  static const metalloid           = Category._('Metalloid');
  static const reactiveNonmetal    = Category._('Reactive Nonmetal');
  static const nobleGas            = Category._('Noble Gas');
  static const unknown             = Category._('Unknown chemical properties');
}

/// Class representing each chemical element within the periodic table.
///
/// Each element has an atomic number, symbol, name, and position within the
/// periodic table grid. The element can be serialized to JSON. Certain
/// properties are populated based on mappings, but the extract field must be
/// provided when serializing.
class Element {

  const Element(this.number, this.symbol, this.name,
      { @required this.x, @required this.y });

  final String name, symbol;
  final int number, x, y;

  String get source => 'https://en.wikipedia.org/wiki/$title';
  Category get category => Category.values
      .firstWhere((category) => kCategoryMap[category].contains(symbol));
  String get atomicWeight => kAtomicWeightMap[symbol];
  List<int> get colors => kColorMap[category];

  String get title => kTitleMap[name] ?? name;

  Map<String, dynamic> toJson({ @required String extract }) {
    assert(extract != null);

    var sourceJson = source;
    assert(sourceJson != null);

    var categoryJson = category?.label;
    assert(categoryJson != null);

    var atomicWeightJson = atomicWeight;
    assert(atomicWeightJson != null);

    var colorsJson = colors;
    assert(colorsJson != null);

    return {
      'number'        : number,
      'name'          : name,
      'symbol'        : symbol,
      'extract'       : extract,
      'source'        : sourceJson,
      'category'      : categoryJson,
      'atomic_weight' : atomicWeightJson,
      'colors'        : colorsJson,
    };
  }
}


/// Page response object from Wikipedia queries.
class Page {

  Page.fromJson(Map<String, dynamic> json)
      : pageId = json['pageid'],
        title = json['title'],
        extract = json['extract'];

  final int pageId;
  final String title, extract;
}


/// Conventional categorization by metallic classification
const kCategoryMap = {
  Category.alkaliMetal         : [ 'Li', 'Na', 'K', 'Rb', 'Cs', 'Fr' ],
  Category.alkalineEarthMetal  : [ 'Be', 'Mg', 'Ca', 'Sr', 'Ba', 'Ra' ],
  Category.lanthanide          : [ 'La', 'Ce', 'Pr', 'Nd', 'Pm', 'Sm', 'Eu',
  'Gd', 'Tb', 'Dy', 'Ho', 'Er', 'Tm', 'Yb', 'Lu' ],
  Category.actinide            : [ 'Ac', 'Th', 'Pa', 'U', 'Np', 'Pu', 'Am', 'Cm',
  'Bk', 'Cf', 'Es', 'Fm', 'Md', 'No', 'Lr', ],
  Category.transitionMetal     : [ 'Sc', 'Ti', 'V', 'Cr', 'Mn', 'Fe', 'Co', 'Ni',
  'Cu', 'Y', 'Zr', 'Nb', 'Mo', 'Tc', 'Ru', 'Rh',
  'Pd', 'Ag', 'Hf', 'Ta', 'W', 'Re', 'Os', 'Ir',
  'Pt', 'Au', 'Rf', 'Db', 'Sg', 'Bh', 'Hs' ],
  Category.postTransitionMetal : [ 'Al', 'Zn', 'Ga', 'Cd', 'In', 'Sn', 'Hg', 'Tl',
  'Pb', 'Bi', 'Po', 'Cn' ],
  Category.metalloid           : [ 'B', 'Si', 'Ge', 'As', 'Sb', 'Te', 'At' ],
  Category.reactiveNonmetal    : [ 'H', 'C', 'N', 'O', 'F', 'P', 'S', 'Cl', 'Se', 'Br', 'I' ],
  Category.nobleGas            : [ 'He', 'Ne', 'Ar', 'Kr', 'Xe', 'Rn' ],
  Category.unknown             : [ 'Mt', 'Ds', 'Rg', 'Nh', 'Fl', 'Mc', 'Lv', 'Ts', 'Og' ],
};

/// App-specific map of colors per category
const kColorMap = {
  Category.alkaliMetal         : [ 0xFFD32F2F, 0xFFFF77A9 ],
  Category.alkalineEarthMetal  : [ 0xFFF46B45, 0xFFEEA849 ],
  Category.lanthanide          : [ 0xFF8BC34A, 0xFFD4E157 ],
  Category.actinide            : [ 0xFF0ED2F7, 0xFFB2FEFA ],
  Category.transitionMetal     : [ 0xFFFFCA28, 0xFFFFF263 ],
  Category.postTransitionMetal : [ 0xFF11998E, 0xFF38EF7D ],
  Category.metalloid           : [ 0xFF0072FF, 0xFF00C6FF ],
  Category.reactiveNonmetal    : [ 0xFF536DFE, 0xFF8E99F3 ],
  Category.nobleGas            : [ 0xFF9796F0, 0xFFFBC7D4 ],
  Category.unknown             : [ 0xFF757F9A, 0xFFD7DDE8 ],
};

/// Conventional atomic weights as published by the IUPAC
/// Values lifted from https://en.wikipedia.org/wiki/List_of_chemical_elements
const kAtomicWeightMap = {
  'H'  : '1.008 u(±)',
  'He' : '4.002602(2) u(±)',
  'Li' : '6.94 u(±)',
  'Be' : '9.0121831(5) u(±)',
  'B'  : '10.81 u(±)',
  'C'  : '12.011 u(±)',
  'N'  : '14.007 u(±)',
  'O'  : '15.999 u(±)',
  'F'  : '18.998403163(6) u(±)',
  'Ne' : '20.1797(6) u(±)',
  'Na' : '22.98976928(2) u(±)',
  'Mg' : '24.305 u(±)',
  'Al' : '26.9815384(3) u(±)',
  'Si' : '28.085 u(±)',
  'P'  : '30.973761998(5) u(±)',
  'S'  : '32.06 u(±)',
  'Cl' : '35.45 u(±)',
  'Ar' : '39.948 u(±)',
  'K'  : '39.0983(1) u(±)',
  'Ca' : '40.078(4) u(±)',
  'Sc' : '44.955908(5) u(±)',
  'Ti' : '47.867(1) u(±)',
  'V'  : '50.9415(1) u(±)',
  'Cr' : '51.9961(6) u(±)',
  'Mn' : '54.938043(2) u(±)',
  'Fe' : '55.845(2) u(±)',
  'Co' : '58.933194(3) u(±)',
  'Ni' : '58.6934(4) u(±)',
  'Cu' : '63.546(3) u(±)',
  'Zn' : '65.38(2) u(±)',
  'Ga' : '69.723(1) u(±)',
  'Ge' : '72.630(8) u(±)',
  'As' : '74.921595(6) u(±)',
  'Se' : '78.971(8) u(±)',
  'Br' : '79.904 u(±)',
  'Kr' : '83.798(2) u(±)',
  'Rb' : '85.4678(3) u(±)',
  'Sr' : '87.62(1) u(±)',
  'Y'  : '88.90584(1) u(±)',
  'Zr' : '91.224(2) u(±)',
  'Nb' : '92.90637(1) u(±)',
  'Mo' : '95.95(1) u(±)',
  'Ru' : '101.07(2) u(±)',
  'Rh' : '102.90549(2) u(±)',
  'Pd' : '106.42(1) u(±)',
  'Ag' : '107.8682(2) u(±)',
  'Cd' : '112.414(4) u(±)',
  'In' : '114.818(1) u(±)',
  'Sn' : '118.710(7) u(±)',
  'Sb' : '121.760(1) u(±)',
  'Te' : '127.60(3) u(±)',
  'I'  : '126.90447(3) u(±)',
  'Xe' : '131.293(6) u(±)',
  'Cs' : '132.90545196(6) u(±)',
  'Ba' : '137.327(7) u(±)',
  'La' : '138.90547(7) u(±)',
  'Ce' : '140.116(1) u(±)',
  'Pr' : '140.90766(1) u(±)',
  'Nd' : '144.242(3) u(±)',
  'Sm' : '150.36(2) u(±)',
  'Eu' : '151.964(1) u(±)',
  'Gd' : '157.25(3) u(±)',
  'Tb' : '158.925354(8) u(±)',
  'Dy' : '162.500(1) u(±)',
  'Ho' : '164.930328(7) u(±)',
  'Er' : '167.259(3) u(±)',
  'Tm' : '168.934218(6) u(±)',
  'Yb' : '173.045(10) u(±)',
  'Lu' : '174.9668(1) u(±)',
  'Hf' : '178.49(2) u(±)',
  'Ta' : '180.94788(2) u(±)',
  'W'  : '183.84(1) u(±)',
  'Re' : '186.207(1) u(±)',
  'Os' : '190.23(3) u(±)',
  'Ir' : '192.217(2) u(±)',
  'Pt' : '195.084(9) u(±)',
  'Au' : '196.966570(4) u(±)',
  'Hg' : '200.592(3) u(±)',
  'Tl' : '204.38 u(±)',
  'Pb' : '207.2(1) u(±)',
  'Bi' : '208.98040(1) u(±)',
  'Th' : '232.0377(4) u(±)',
  'Pa' : '231.03588(1) u(±)',
  'U'  : '238.02891(3) u(±)',

// No atomic weight available due to instability.
// Mass number of the most stable isotope is provided instead.
  'Tc' : '[98] (mass number)',
  'Pm' : '[145] (mass number)',
  'Po' : '[209] (mass number)',
  'At' : '[210] (mass number)',
  'Rn' : '[222] (mass number)',
  'Fr' : '[223] (mass number)',
  'Ra' : '[226] (mass number)',
  'Ac' : '[227] (mass number)',
  'Np' : '[237] (mass number)',
  'Pu' : '[244] (mass number)',
  'Am' : '[243] (mass number)',
  'Cm' : '[247] (mass number)',
  'Bk' : '[247] (mass number)',
  'Cf' : '[251] (mass number)',
  'Es' : '[252] (mass number)',
  'Fm' : '[257] (mass number)',
  'Md' : '[258] (mass number)',
  'No' : '[259] (mass number)',
  'Lr' : '[266] (mass number)',
  'Rf' : '[267] (mass number)',
  'Db' : '[268] (mass number)',
  'Sg' : '[269] (mass number)',
  'Bh' : '[270] (mass number)',
  'Hs' : '[270] (mass number)',
  'Mt' : '[278] (mass number)',
  'Ds' : '[281] (mass number)',
  'Rg' : '[282] (mass number)',
  'Cn' : '[285] (mass number)',
  'Nh' : '[286] (mass number)',
  'Fl' : '[289] (mass number)',
  'Mc' : '[290] (mass number)',
  'Lv' : '[293] (mass number)',
  'Ts' : '[294] (mass number)',
  'Og' : '[294] (mass number)',
};

/// Mapping for element names to Wikipedia titles.
/// If no mapping is provided, the element name itself is a suitable Wikipedia title.
const kTitleMap = {
  'Mercury' : 'Mercury (element)',
};


/// Actual list of elements and their corresponding mapping in the periodic table grid.
const kElementsList = [
  Element(1,   'H',  'Hydrogen',      x : 0,  y: 0,),
  Element(2,   'He', 'Helium',        x : 17, y: 0,),
  Element(3,   'Li', 'Lithium',       x : 0,  y: 1,),
  Element(4,   'Be', 'Beryllium',     x : 1,  y: 1,),
  Element(5,   'B',  'Boron',         x : 12, y: 1,),
  Element(6,   'C',  'Carbon',        x : 13, y: 1,),
  Element(7,   'N',  'Nitrogen',      x : 14, y: 1,),
  Element(8,   'O',  'Oxygen',        x : 15, y: 1,),
  Element(9,   'F',  'Fluorine',      x : 16, y: 1,),
  Element(10,  'Ne', 'Neon',          x : 17, y: 1,),
  Element(11,  'Na', 'Sodium',        x : 0,  y: 2,),
  Element(12,  'Mg', 'Magnesium',     x : 1,  y: 2,),
  Element(13,  'Al', 'Aluminium',     x : 12, y: 2,),
  Element(14,  'Si', 'Silicon',       x : 13, y: 2,),
  Element(15,  'P',  'Phosphorus',    x : 14, y: 2,),
  Element(16,  'S',  'Sulfur',        x : 15, y: 2,),
  Element(17,  'Cl', 'Chlorine',      x : 16, y: 2,),
  Element(18,  'Ar', 'Argon',         x : 17, y: 2,),
  Element(19,  'K',  'Potassium',     x : 0,  y: 3,),
  Element(20,  'Ca', 'Calcium',       x : 1,  y: 3,),
  Element(21,  'Sc', 'Scandium',      x : 2,  y: 3,),
  Element(22,  'Ti', 'Titanium',      x : 3,  y: 3,),
  Element(23,  'V',  'Vanadium',      x : 4,  y: 3,),
  Element(24,  'Cr', 'Chromium',      x : 5,  y: 3,),
  Element(25,  'Mn', 'Manganese',     x : 6,  y: 3,),
  Element(26,  'Fe', 'Iron',          x : 7,  y: 3,),
  Element(27,  'Co', 'Cobalt',        x : 8,  y: 3,),
  Element(28,  'Ni', 'Nickel',        x : 9,  y: 3,),
  Element(29,  'Cu', 'Copper',        x : 10, y: 3,),
  Element(30,  'Zn', 'Zinc',          x : 11, y: 3,),
  Element(31,  'Ga', 'Gallium',       x : 12, y: 3,),
  Element(32,  'Ge', 'Germanium',     x : 13, y: 3,),
  Element(33,  'As', 'Arsenic',       x : 14, y: 3,),
  Element(34,  'Se', 'Selenium',      x : 15, y: 3,),
  Element(35,  'Br', 'Bromine',       x : 16, y: 3,),
  Element(36,  'Kr', 'Krypton',       x : 17, y: 3,),
  Element(37,  'Rb', 'Rubidium',      x : 0,  y: 4,),
  Element(38,  'Sr', 'Strontium',     x : 1,  y: 4,),
  Element(39,  'Y',  'Yttrium',       x : 2,  y: 4,),
  Element(40,  'Zr', 'Zirconium',     x : 3,  y: 4,),
  Element(41,  'Nb', 'Niobium',       x : 4,  y: 4,),
  Element(42,  'Mo', 'Molybdenum',    x : 5,  y: 4,),
  Element(43,  'Tc', 'Technetium',    x : 6,  y: 4,),
  Element(44,  'Ru', 'Ruthenium',     x : 7,  y: 4,),
  Element(45,  'Rh', 'Rhodium',       x : 8,  y: 4,),
  Element(46,  'Pd', 'Palladium',     x : 9,  y: 4,),
  Element(47,  'Ag', 'Silver',        x : 10, y: 4,),
  Element(48,  'Cd', 'Cadmium',       x : 11, y: 4,),
  Element(49,  'In', 'Indium',        x : 12, y: 4,),
  Element(50,  'Sn', 'Tin',           x : 13, y: 4,),
  Element(51,  'Sb', 'Antimony',      x : 14, y: 4,),
  Element(52,  'Te', 'Tellurium',     x : 15, y: 4,),
  Element(53,  'I',  'Iodine',        x : 16, y: 4,),
  Element(54,  'Xe', 'Xenon',         x : 17, y: 4,),
  Element(55,  'Cs', 'Caesium',       x : 0,  y: 5,),
  Element(56,  'Ba', 'Barium',        x : 1,  y: 5,),
  Element(57,  'La', 'Lanthanum',     x : 2,  y: 8,),
  Element(58,  'Ce', 'Cerium',        x : 3,  y: 8,),
  Element(59,  'Pr', 'Praseodymium',  x : 4,  y: 8,),
  Element(60,  'Nd', 'Neodymium',     x : 5,  y: 8,),
  Element(61,  'Pm', 'Promethium',    x : 6,  y: 8,),
  Element(62,  'Sm', 'Samarium',      x : 7,  y: 8,),
  Element(63,  'Eu', 'Europium',      x : 8,  y: 8,),
  Element(64,  'Gd', 'Gadolinium',    x : 9,  y: 8,),
  Element(65,  'Tb', 'Terbium',       x : 10, y: 8,),
  Element(66,  'Dy', 'Dysprosium',    x : 11, y: 8,),
  Element(67,  'Ho', 'Holmium',       x : 12, y: 8,),
  Element(68,  'Er', 'Erbium',        x : 13, y: 8,),
  Element(69,  'Tm', 'Thulium',       x : 14, y: 8,),
  Element(70,  'Yb', 'Ytterbium',     x : 15, y: 8,),
  Element(71,  'Lu', 'Lutetium',      x : 16, y: 8,),
  Element(72,  'Hf', 'Hafnium',       x : 3,  y: 5,),
  Element(73,  'Ta', 'Tantalum',      x : 4,  y: 5,),
  Element(74,  'W',  'Tungsten',      x : 5,  y: 5,),
  Element(75,  'Re', 'Rhenium',       x : 6,  y: 5,),
  Element(76,  'Os', 'Osmium',        x : 7,  y: 5,),
  Element(77,  'Ir', 'Iridium',       x : 8,  y: 5,),
  Element(78,  'Pt', 'Platinum',      x : 9,  y: 5,),
  Element(79,  'Au', 'Gold',          x : 10, y: 5,),
  Element(80,  'Hg', 'Mercury',       x : 11, y: 5,),
  Element(81,  'Tl', 'Thallium',      x : 12, y: 5,),
  Element(82,  'Pb', 'Lead',          x : 13, y: 5,),
  Element(83,  'Bi', 'Bismuth',       x : 14, y: 5,),
  Element(84,  'Po', 'Polonium',      x : 15, y: 5,),
  Element(85,  'At', 'Astatine',      x : 16, y: 5,),
  Element(86,  'Rn', 'Radon',         x : 17, y: 5,),
  Element(87,  'Fr', 'Francium',      x : 0,  y: 6,),
  Element(88,  'Ra', 'Radium',        x : 1,  y: 6,),
  Element(89,  'Ac', 'Actinium',      x : 2,  y: 9,),
  Element(90,  'Th', 'Thorium',       x : 3,  y: 9,),
  Element(91,  'Pa', 'Protactinium',  x : 4,  y: 9,),
  Element(92,  'U',  'Uranium',       x : 5,  y: 9,),
  Element(93,  'Np', 'Neptunium',     x : 6,  y: 9,),
  Element(94,  'Pu', 'Plutonium',     x : 7,  y: 9,),
  Element(95,  'Am', 'Americium',     x : 8,  y: 9,),
  Element(96,  'Cm', 'Curium',        x : 9, y: 9,),
  Element(97,  'Bk', 'Berkelium',     x : 10, y: 9,),
  Element(98,  'Cf', 'Californium',   x : 11, y: 9,),
  Element(99,  'Es', 'Einsteinium',   x : 12, y: 9,),
  Element(100, 'Fm', 'Fermium',       x : 13, y: 9,),
  Element(101, 'Md', 'Mendelevium',   x : 14, y: 9,),
  Element(102, 'No', 'Nobelium',      x : 15, y: 9,),
  Element(103, 'Lr', 'Lawrencium',    x : 16, y: 9,),
  Element(104, 'Rf', 'Rutherfordium', x : 3,  y: 6,),
  Element(105, 'Db', 'Dubnium',       x : 4,  y: 6,),
  Element(106, 'Sg', 'Seaborgium',    x : 5,  y: 6,),
  Element(107, 'Bh', 'Bohrium',       x : 6,  y: 6,),
  Element(108, 'Hs', 'Hassium',       x : 7,  y: 6,),
  Element(109, 'Mt', 'Meitnerium',    x : 8,  y: 6,),
  Element(110, 'Ds', 'Darmstadtium',  x : 9,  y: 6,),
  Element(111, 'Rg', 'Roentgenium',   x : 10, y: 6,),
  Element(112, 'Cn', 'Copernicium',   x : 11, y: 6,),
  Element(113, 'Nh', 'Nihonium',      x : 12, y: 6,),
  Element(114, 'Fl', 'Flerovium',     x : 13, y: 6,),
  Element(115, 'Mc', 'Moscovium',     x : 14, y: 6,),
  Element(116, 'Lv', 'Livermorium',   x : 15, y: 6,),
  Element(117, 'Ts', 'Tennessine',    x : 16, y: 6,),
  Element(118, 'Og', 'Oganesson',     x : 17, y: 6,),
];