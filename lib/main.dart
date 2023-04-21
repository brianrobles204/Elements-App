import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:translator/translator.dart';

const kRowCount = 10;

const kContentSize = 64.0;
const kGutterWidth = 2.0;

const kGutterInset = EdgeInsets.all(kGutterWidth);
List<String> languages = ['English', 'Türkçe', 'Deutsch', 'Español', 'Français','عربي', 'हिंदी'];
String selectedLanguage = 'English';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final gridList = rootBundle
      .loadString('assets/elementsGrid.json')
      .then((source) => jsonDecode(source)['elements'] as List)
      .then((list) => list
          .map((json) => json != null ? ElementData.fromJson(json) : null)
          .toList());

  runApp(ElementsApp(gridList));
}

class ElementData {
  final String name, category, symbol, extract, source, atomicWeight;
  final int number;
  final List<Color> colors;

  ElementData.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        category = json['category'],
        symbol = json['symbol'],
        extract = json['extract'],
        source = json['source'],
        atomicWeight = json['atomic_weight'],
        number = json['number'],
        colors = (json['colors'] as List).map((value) => Color(value)).toList();
}

class ElementsApp extends StatelessWidget {
  ElementsApp(this.gridList);

  final Future<List<ElementData?>> gridList;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      brightness: Brightness.dark,
      accentColor: Colors.grey,
      textTheme:
          Typography.whiteMountainView.apply(fontFamily: 'Roboto Condensed'),
      primaryTextTheme:
          Typography.whiteMountainView.apply(fontFamily: 'Share Tech Mono'),
    );

    return MaterialApp(
      title: 'Elements',
      theme: theme,
      home: TablePage(gridList),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TablePage extends StatefulWidget {
  TablePage(this.gridList);

  final Future<List<ElementData?>> gridList;

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  
  void selectLanguage(String language) {
    setState(() {
      selectedLanguage = language;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      appBar: AppBar(
        title: Text(
          'Elements',
          style: TextStyle(fontFamily: "Share Tech Mono"),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueGrey[800],
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.language),
            itemBuilder: (BuildContext context) {
              return languages.map((String language) {
                return PopupMenuItem<String>(
                  value: language,
                  child: Text(language),
                );
              }).toList();
            },
            onSelected: selectLanguage,
          ),
        ],
      ),
      body: FutureBuilder(
        future: widget.gridList,
        builder: (_, snapshot) => snapshot.hasData
            ? _buildTable(snapshot.data)
            : Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildTable(List<ElementData?>? elements) {
    final tiles = elements!
        .map((element) => element != null
            ? ElementTile(element)
            : Container(color: Colors.black38, margin: kGutterInset))
        .toList();

    return SingleChildScrollView(
      child: SizedBox(
        height: kRowCount * (kContentSize + (kGutterWidth * 2)),
        child: GridView.count(
          crossAxisCount: kRowCount,
          children: tiles,
          scrollDirection: Axis.horizontal,
        ),
      ),
    );
  }
}

class DetailPage extends StatefulWidget {
  DetailPage(this.element);

  final ElementData element;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  GoogleTranslator translator = GoogleTranslator();
  var atomic = 'Atomic Weight';

  @override
  Widget build(BuildContext context) {
    var theExtract = widget.element.extract;
    var theCategory = widget.element.category.toUpperCase();

    var listItems = <Widget>[
      ListTile(leading: Icon(Icons.category), title: Text(theCategory)),
      ListTile(
        leading: Icon(Icons.info),
        title: Text(theExtract),
        subtitle: Text(widget.element.source),
      ),
      ListTile(
        leading: Icon(Icons.fiber_smart_record),
        title: Text(widget.element.atomicWeight),
        subtitle: Text(atomic),
      ),
    ].expand((widget) => [widget, Divider()]).toList();

    Future<List<String>> translateAll(String language) async {
      var theExtract = widget.element.extract;
      var theCategory = widget.element.category.toUpperCase();
      var atomic = 'Atomic Weight';

      var results = await Future.wait([
        translator
            .translate(theExtract, to: language)
            .then((value) => value.toString()),
        translator
            .translate(theCategory, to: language)
            .then((value) => value.toString()),
        translator
            .translate(atomic, to: language)
            .then((value) => value.toString()),
      ]);

      return results;
    }

    return Scaffold(
      backgroundColor:
          Color.lerp(Colors.grey[850], widget.element.colors[0], 0.07),
      appBar: AppBar(
          backgroundColor:
              Color.lerp(Colors.grey[850], widget.element.colors[1], 0.2),
          bottom: ElementTile(widget.element, isLarge: true),),
      body: FutureBuilder<List<String>>(
        future: translateAll(selectedLanguage == "English" ? "en": selectedLanguage == "Türkçe" ? "tr": selectedLanguage == "Deutsch" ? "de": selectedLanguage == "عربي" ? "ar": selectedLanguage == "हिंदी" ? "hi": selectedLanguage == "Español" ? "es": selectedLanguage=="Français" ? "fr": "en"),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(
              color: Colors.orangeAccent,
            ));
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            var translatedExtract = snapshot.data![0];
            var translatedCategory = snapshot.data![1];
            var translatedAtomic = snapshot.data![2];

            var listItems = <Widget>[
              ListTile(
                  leading: Icon(Icons.category),
                  title: Text(translatedCategory)),
              ListTile(
                leading: Icon(Icons.info),
                title: Text(translatedExtract),
                subtitle: Text(widget.element.source),
              ),
              ListTile(
                leading: Icon(Icons.fiber_smart_record),
                title: Text(widget.element.atomicWeight),
                subtitle: Text(translatedAtomic),
              ),
            ].expand((widget) => [widget, Divider()]).toList();

            return ListView(
                padding: EdgeInsets.only(top: 24.0), children: listItems);
          }
        },
      ),
    );
  }
}

class ElementTile extends StatelessWidget implements PreferredSizeWidget {
  const ElementTile(this.element, {this.isLarge = false});

  final ElementData element;
  final bool isLarge;

  Size get preferredSize => Size.fromHeight(kContentSize * 1.5);

  @override
  Widget build(BuildContext context) {
    final tileText = <Widget>[
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text('${element.number}', style: TextStyle(fontSize: 10.0)),
      ),
      Text(element.symbol,
          style: Theme.of(context).primaryTextTheme.headlineSmall),
      Text(
        element.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textScaleFactor: isLarge ? 0.65 : 1,
      ),
    ];

    final tile = Container(
      margin: kGutterInset,
      width: kContentSize,
      height: kContentSize,
      foregroundDecoration: BoxDecoration(
        gradient: LinearGradient(colors: element.colors),
        backgroundBlendMode: BlendMode.multiply,
      ),
      child: RawMaterialButton(
        onPressed: !isLarge
            ? () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => DetailPage(element)))
            : null,
        fillColor: Colors.grey[800],
        disabledElevation: 10.0,
        padding: kGutterInset * 2.0,
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: tileText),
      ),
    );

    return Hero(
      tag: 'hero-${element.symbol}',
      flightShuttleBuilder: (_, anim, __, ___, ____) => ScaleTransition(
          scale: anim.drive(Tween(begin: 1, end: 1.75)), child: tile),
      child: Transform.scale(scale: isLarge ? 1.75 : 1, child: tile),
    );
  }
}
