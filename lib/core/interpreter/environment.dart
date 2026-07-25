class Environment {
  final Map<String, dynamic> values = {};
  final Map<String, String> types = {};
  final Map<String, dynamic> subroutines = {};
  final Environment? enclosing;
  Environment({this.enclosing});
  void define(String name, dynamic value, String type) { values[name] = value; types[name] = type; }
  void defineSubroutine(String name, dynamic subroutine) { subroutines[name] = subroutine; }
  void assign(String name, dynamic value) {
    if (values.containsKey(name)) { values[name] = value; return; }
    if (enclosing != null) { enclosing!.assign(name, value); return; }
    throw "Variable indéfinie '$name'.";
  }
  dynamic get(String name) {
    if (values.containsKey(name)) return values[name];
    if (enclosing != null) return enclosing!.get(name);
    throw "Variable indéfinie '$name'.";
  }
  String getType(String name) {
    if (types.containsKey(name)) return types[name]!;
    if (enclosing != null) return enclosing!.getType(name);
    return "inconnu";
  }

  dynamic getSubroutine(String name) {
    if (subroutines.containsKey(name)) return subroutines[name];
    if (enclosing != null) return enclosing!.getSubroutine(name);
    return null;
  }

  Map<String, dynamic> getAllValues() {
    final map = <String, dynamic>{};
    if (enclosing != null) {
      map.addAll(enclosing!.getAllValues());
    }
    map.addAll(values);
    return map;
  }
}
