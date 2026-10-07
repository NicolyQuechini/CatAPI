import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =====================================================================
// Cat App: arquivo único (lib/main.dart). Todas as telas e a API aqui.
// Execute com: flutter run --dart-define=CAT_API_KEY=SUA_CHAVE
// =====================================================================

// ------------------------------------------------ lib/api.dart
/// Passe a chave ao executar: flutter run --dart-define=CAT_API_KEY=SUA_CHAVE
const apiKey = 'live_LJBjxQXhBaW5kmgEgo1fnolyNf13BjmsrbzDUu2b9TimYldYo3dkitDFMMgfYtSQ';

const _base = 'https://api.thecatapi.com/v1';
const _cdn = 'https://cdn2.thecatapi.com/images';

int? _int(dynamic v) => (v as num?)?.toInt();

class ApiException implements Exception {
  ApiException(this.code, this.body);
  final int code;
  final String body;
  @override
  String toString() => 'ApiException($code): $body';
}

// ---------------------------------------------------------------- Modelos

class CatBreed {
  CatBreed({
    required this.id,
    required this.name,
    this.description,
    this.temperament,
    this.origin,
    this.lifeSpan,
    this.affection,
    this.energy,
    this.intelligence,
    this.social,
    this.imageUrl,
    this.refImageId,
  });

  final String id, name;
  final String? description, temperament, origin, lifeSpan, imageUrl, refImageId;
  final int? affection, energy, intelligence, social;

  factory CatBreed.fromJson(Map<String, dynamic> j) {
    // Atributos de gato podem vir na raiz ou dentro de expansions.cat
    final cat = (j['expansions']?['cat'] as Map?) ?? const {};
    dynamic pick(String k) => j[k] ?? cat[k];
    final ref = j['reference_image_id'] as String?;
    return CatBreed(
      id: j['id'].toString(),
      name: j['name'] as String,
      description: j['description'] as String?,
      temperament: j['temperament'] as String?,
      origin: j['origin'] as String?,
      lifeSpan: j['life_span'] as String?,
      affection: _int(pick('affection_level')),
      energy: _int(pick('energy_level')),
      intelligence: _int(pick('intelligence')),
      social: _int(pick('social_needs')),
      refImageId: ref,
      imageUrl: j['image']?['url'] as String? ??
          (ref == null ? null : '$_cdn/$ref.jpg'),
    );
  }

  List<String> get tags => (temperament ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

class CatImage {
  CatImage({required this.id, required this.url, this.breeds = const []});
  final String id, url;
  final List<CatBreed> breeds;

  factory CatImage.fromJson(Map<String, dynamic> j) => CatImage(
        id: j['id'].toString(),
        url: (j['url'] ?? '') as String,
        breeds: (j['breeds'] as List? ?? [])
            .map((b) => CatBreed.fromJson(b as Map<String, dynamic>))
            .toList(),
      );

  String get label => breeds.isEmpty ? '' : breeds.first.name;
}

class Favourite {
  Favourite({required this.id, required this.image});
  final int id;
  final CatImage image;

  factory Favourite.fromJson(Map<String, dynamic> j) {
    final img = j['image'] as Map<String, dynamic>?;
    return Favourite(
      id: _int(j['id'])!,
      image: img != null
          ? CatImage.fromJson(img)
          : CatImage(id: j['image_id'].toString(), url: ''),
    );
  }
}

class Vote {
  Vote({required this.id, required this.imageId, required this.value, this.imageUrl});
  final int id;
  final String imageId;
  final int value; // 1 = gostei, -1 = não gostei
  final String? imageUrl;

  String get thumb => imageUrl ?? '$_cdn/$imageId.jpg';

  factory Vote.fromJson(Map<String, dynamic> j) => Vote(
        id: _int(j['id'])!,
        imageId: j['image_id'].toString(),
        value: _int(j['value']) ?? 0,
        imageUrl: (j['image'] as Map?)?['url'] as String?,
      );
}

class CatCategory {
  CatCategory(this.id, this.name);
  final String id, name;
}

// ---------------------------------------------------------------- Cliente

class CatApi {
  List<CatBreed>? _breeds; // cache em memória para poupar requisições

  Map<String, String> get _h => {'x-api-key': apiKey, 'Content-Type': 'application/json'};

  dynamic _ok(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw ApiException(r.statusCode, r.body);
    }
    return r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
  }

  Uri _u(String p, [Map<String, String>? q]) =>
      Uri.parse('$_base$p').replace(queryParameters: q);

  Future<dynamic> _get(String p, [Map<String, String>? q]) async =>
      _ok(await http.get(_u(p, q), headers: _h));

  // GET /images/search
  Future<List<CatImage>> images({int limit = 10, String? breedIds, String? categoryId}) async {
    final d = await _get('/images/search', {
      'limit': '$limit',
      'order': 'RANDOM',
      'include_breeds': 'true',
      if (breedIds == null && categoryId == null) 'has_breeds': 'true',
      if (breedIds != null) 'breed_ids': breedIds,
      if (categoryId != null) 'category_ids': categoryId, // confirmar na documentação
    });
    return (d as List).map((e) => CatImage.fromJson(e)).toList();
  }

  // GET /breeds
  Future<List<CatBreed>> breeds() async {
    if (_breeds != null) return _breeds!;
    final d = await _get('/breeds', {'limit': '100'});
    return _breeds = (d as List).map((e) => CatBreed.fromJson(e)).toList();
  }

  // GET /breeds/search?q=
  Future<List<CatBreed>> searchBreeds(String q) async {
    final d = await _get('/breeds/search', {'q': q});
    return (d as List).map((e) => CatBreed.fromJson(e)).toList();
  }

  // GET /facts/random (tenta em português, depois no idioma padrão)
  Future<String> randomFact() async {
    dynamic d;
    try {
      d = await _get('/facts/random', {'lang': 'pt'});
    } catch (_) {
      d = await _get('/facts/random');
    }
    final x = d is List ? d.first : d;
    return (x['fact'] ?? '').toString();
  }

  // GET /categories
  Future<List<CatCategory>> categories() async {
    final d = await _get('/categories');
    return (d as List).map((e) => CatCategory(e['id'].toString(), e['name'].toString())).toList();
  }

  // POST /votes
  Future<void> vote(String imageId, int value, String subId) async => _ok(await http.post(
        _u('/votes'),
        headers: _h,
        body: jsonEncode({'image_id': imageId, 'value': value, 'sub_id': subId}),
      ));

  // GET /votes
  Future<List<Vote>> votes(String subId, {int limit = 100}) async {
    final d = await _get('/votes', {'sub_id': subId, 'limit': '$limit', 'order': 'DESC'});
    return (d as List).map((e) => Vote.fromJson(e)).toList();
  }

  // POST /favourites
  Future<int> addFavourite(String imageId, String subId) async {
    final d = _ok(await http.post(
      _u('/favourites'),
      headers: _h,
      body: jsonEncode({'image_id': imageId, 'sub_id': subId}),
    ));
    return _int(d['id'])!;
  }

  // GET /favourites
  Future<List<Favourite>> favourites(String subId) async {
    final d = await _get('/favourites', {
      'sub_id': subId,
      'attach_image': 'true',
      'limit': '100',
      'order': 'DESC',
    });
    return (d as List).map((e) => Favourite.fromJson(e)).toList();
  }

  // DELETE /favourites/{id}
  Future<void> removeFavourite(int id) async =>
      _ok(await http.delete(_u('/favourites/$id'), headers: _h));

  // POST /images/upload
  Future<String> upload(String path, String subId) async {
    final req = http.MultipartRequest('POST', _u('/images/upload'))
      ..headers['x-api-key'] = apiKey
      ..fields['sub_id'] = subId
      ..files.add(await http.MultipartFile.fromPath('file', path));
    final r = await http.Response.fromStream(await req.send());
    return _ok(r)['id'].toString();
  }

  // GET /images/{id} + GET /images/{id}/status
  Future<({String url, String status})> uploadInfo(String id) async {
    final img = await _get('/images/$id');
    var status = '';
    try {
      final s = await _get('/images/$id/status');
      status = (s is Map ? (s['status'] ?? s['review'] ?? '') : s).toString();
    } catch (_) {}
    return (url: (img['url'] ?? '') as String, status: status);
  }
}

final api = CatApi();

// ------------------------------------------------ lib/state.dart
/// Estado global: usuário local, favoritos e fotos enviadas.
/// A Cat API não tem login; o e-mail gera o `sub_id` que separa os dados de cada pessoa.
class AppState extends ChangeNotifier {
  late SharedPreferences _p;
  bool ready = false, logged = false;
  String subId = '', name = '', email = '';
  List<String> uploads = [];
  List<Favourite> favourites = [];

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    subId = _p.getString('subId') ?? '';
    name = _p.getString('name') ?? '';
    email = _p.getString('email') ?? '';
    uploads = _p.getStringList('uploads_$subId') ?? [];
    logged = subId.isNotEmpty;
    ready = true;
    notifyListeners();
    if (logged) loadFavs();
  }

  Future<void> login(String n, String e) async {
    name = n;
    email = e;
    subId = 'user_${e.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    await _p.setString('subId', subId);
    await _p.setString('name', n);
    await _p.setString('email', e);
    uploads = _p.getStringList('uploads_$subId') ?? [];
    logged = true;
    notifyListeners();
    loadFavs();
  }

  Future<void> logout() async {
    await _p.remove('subId');
    subId = name = email = '';
    uploads = [];
    favourites = [];
    logged = false;
    notifyListeners();
  }

  bool isFav(String imageId) => favourites.any((f) => f.image.id == imageId);

  Future<void> loadFavs() async {
    try {
      favourites = await api.favourites(subId);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleFav(CatImage img) async {
    final cur = favourites.where((f) => f.image.id == img.id).toList();
    if (cur.isNotEmpty) {
      await api.removeFavourite(cur.first.id);
      favourites.removeWhere((f) => f.image.id == img.id);
    } else {
      final id = await api.addFavourite(img.id, subId);
      favourites.insert(0, Favourite(id: id, image: img));
    }
    notifyListeners();
  }

  Future<void> addUpload(String id) async {
    uploads.insert(0, id);
    await _p.setStringList('uploads_$subId', uploads);
    notifyListeners();
  }
}

class Scope extends InheritedNotifier<AppState> {
  const Scope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<Scope>()!.notifier!;
}

// ------------------------------------------------ lib/widgets.dart
const appName = 'Cat App';
const kPrimary = Color(0xFF5B3CF5);
const kBg = Color(0xFFF5F3FF);
const kDark = Color(0xFF1B1735);
const kMuted = Color(0xFF7A7691);
const kPink = Color(0xFFFF5C7A);
const kGreen = Color(0xFF18C98B);
const kOrange = Color(0xFFFFAB1F);
const kSoft = Color(0xFFE6E3F4);
const kPastels = [Color(0xFFFFD9E0), Color(0xFFD9F5E8), Color(0xFFE0DBFF), Color(0xFFFFE9C7)];

String friendly(Object e) {
  if (e is ApiException) {
    if (e.code == 401 || e.code == 403) return 'Chave da API inválida ou ausente.';
    if (e.code == 429) return 'Limite de requisições atingido. Tente mais tarde.';
    if (e.code == 404) return 'Conteúdo não encontrado.';
    return 'Erro ${e.code}: ${e.body}';
  }
  return 'Sem conexão ou erro inesperado.';
}

Future<void> safe(BuildContext c, Future<void> Function() fn) async {
  try {
    await fn();
  } catch (e) {
    if (c.mounted) {
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(friendly(e))));
    }
  }
}

String ptCategory(String n) {
  const m = {
    'hats': 'Chapéus', 'space': 'Espaço', 'funny': 'Engraçados', 'sunglasses': 'Óculos',
    'boxes': 'Caixas', 'ties': 'Gravatas', 'sinks': 'Pias', 'clothes': 'Roupas',
  };
  return m[n.toLowerCase()] ?? (n.isEmpty ? n : n[0].toUpperCase() + n.substring(1));
}

/// Converte o status do upload na API para o selo do wireframe.
(String, Color) badgeFor(String s) {
  switch (s) {
    case 'clean':
    case 'labelled':
      return ('Aprovada', kGreen);
    case 'unsafe':
    case 'does_not_contain_species':
      return ('Recusada', kPink);
    default:
      return ('Em análise', kOrange);
  }
}

class Screen extends StatelessWidget {
  const Screen(this.child, {super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(bottom: false, child: child);
}

class Header extends StatelessWidget {
  const Header(this.sub, this.title, {super.key});
  final String sub, title;
  @override
  Widget build(BuildContext context) {
    final n = Scope.of(context).name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sub, style: const TextStyle(color: kMuted, fontSize: 15)),
            Text(title,
                style: const TextStyle(color: kDark, fontSize: 34, fontWeight: FontWeight.w800)),
          ]),
          CircleAvatar(
            radius: 26,
            backgroundColor: kPink,
            child: Text(n.isEmpty ? 'G' : n[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
          ),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.bg = Colors.white, this.fg = kDark});
  final String text;
  final Color bg, fg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
      );
}

class Chips extends StatelessWidget {
  const Chips(this.labels, this.selected, this.onSelect, {super.key});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 46,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: labels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: i == selected ? kPrimary : Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(labels[i],
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: i == selected ? Colors.white : kDark)),
            ),
          ),
        ),
      );
}

class SearchBox extends StatelessWidget {
  const SearchBox(this.hint, {super.key, this.onChanged, this.onSubmitted});
  final String hint;
  final ValueChanged<String>? onChanged, onSubmitted;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: TextField(
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search, color: kMuted),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
          ),
        ),
      );
}

class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.color = const Color(0xFFE0DBFF)});
  final String? url;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final ph = Container(
        color: color, child: const Center(child: Icon(Icons.pets, size: 44, color: Colors.black26)));
    if (url == null || url!.isEmpty) return ph;
    return Image.network(url!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (c, w, p) => p == null ? w : ph,
        errorBuilder: (c, e, s) => ph);
  }
}

class PhotoTile extends StatelessWidget {
  const PhotoTile(this.img, this.i, {super.key});
  final CatImage img;
  final int i;
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    final fav = st.isFav(img.id);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(fit: StackFit.expand, children: [
        NetImage(img.url, color: kPastels[i % 4]),
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            onTap: () => safe(context, () => st.toggleFav(img)),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: Icon(fav ? Icons.favorite : Icons.favorite_border, color: kPink, size: 22),
            ),
          ),
        ),
        if (img.label.isNotEmpty) Positioned(bottom: 10, left: 10, child: Pill(img.label)),
      ]),
    );
  }
}

class PhotoGrid extends StatelessWidget {
  const PhotoGrid(this.items, {super.key, this.scrollable = false});
  final List<CatImage> items;
  final bool scrollable;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Nenhum gato por aqui ainda.', style: TextStyle(color: kMuted))));
    }
    return GridView.builder(
      shrinkWrap: !scrollable,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: .85),
      itemCount: items.length,
      itemBuilder: (_, i) => PhotoTile(items[i], i),
    );
  }
}

class Async<T> extends StatelessWidget {
  const Async({super.key, required this.future, required this.builder});
  final Future<T> future;
  final Widget Function(T) builder;
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: future,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Padding(
                padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
          }
          if (s.hasError) {
            return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                    child: Text(friendly(s.error!),
                        textAlign: TextAlign.center, style: const TextStyle(color: kMuted))));
          }
          return builder(s.data as T);
        },
      );
}

// ------------------------------------------------ lib/screens/onboarding.dart
/// Tela 1: apresentação. A Cat API não tem login; o acesso é local (nome + e-mail).
class Onboarding extends StatelessWidget {
  const Onboarding({super.key});

  Future<void> _ask(BuildContext context) async {
    final st = Scope.of(context);
    final n = TextEditingController(), e = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Entrar'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: n, decoration: const InputDecoration(labelText: 'Seu nome')),
          TextField(
              controller: e,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Continuar')),
        ],
      ),
    );
    if (ok == true && e.text.trim().isNotEmpty) {
      await st.login(n.text.trim().isEmpty ? 'Gateiro(a)' : n.text.trim(), e.text.trim());
    }
  }

  Widget _card(Color c, double angle) => Transform.rotate(
        angle: angle,
        child: Container(
          width: 170,
          height: 200,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white, width: 5),
          ),
          child: const Icon(Icons.pets, size: 48, color: Colors.black26),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kPrimary,
        body: Column(children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Stack(children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Text('[$appName]',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                ),
                Positioned(left: 24, top: 80, child: _card(kPastels[0], -.1)),
                Positioned(right: 20, top: 120, child: _card(kPastels[1], .1)),
                Positioned(left: 110, top: 220, child: _card(kPastels[2], 0)),
              ]),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            decoration: const BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
            ),
            child: SafeArea(
              top: false,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Todos os gatos do mundo na palma da mão',
                    style: TextStyle(color: kDark, fontSize: 32, fontWeight: FontWeight.w800, height: 1.1)),
                const SizedBox(height: 14),
                const Text('Descubra raças, vote nos seus favoritos e envie as suas próprias fotos.',
                    style: TextStyle(color: kMuted, fontSize: 16)),
                const SizedBox(height: 20),
                Row(children: [
                  Container(
                      width: 26,
                      height: 8,
                      decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(4))),
                  for (var i = 0; i < 2; i++)
                    Container(
                        margin: const EdgeInsets.only(left: 6),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: kSoft, shape: BoxShape.circle)),
                ]),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kPrimary),
                    onPressed: () => _ask(context),
                    child: const Text('Começar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => _ask(context),
                    child: const Text('Já tenho uma conta',
                        style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      );
}

// ------------------------------------------------ lib/screens/discover.dart
/// Tela 2: Descobrir (galeria, busca, categorias e fato do dia).
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  late final Future<String> _fact = api.randomFact();
  late final Future<List<CatCategory>> _cats = api.categories();
  late Future<List<CatImage>> _photos = _load();
  int _chip = 0;
  String? _cat;
  String _query = '';

  Future<List<CatImage>> _load() async {
    if (_query.isNotEmpty) {
      final bs = await api.searchBreeds(_query);
      if (bs.isEmpty) return [];
      return api.images(breedIds: bs.map((b) => b.id).join(','));
    }
    return api.images(categoryId: _cat);
  }

  @override
  Widget build(BuildContext context) => Screen(
        ListView(padding: const EdgeInsets.only(bottom: 20), children: [
          const Header('Olá, gateiro(a)', 'Descobrir'),
          SearchBox('Buscar gatos...', onSubmitted: (v) {
            setState(() {
              _query = v.trim();
              _chip = 0;
              _cat = null;
              _photos = _load();
            });
          }),
          Async<List<CatCategory>>(
            future: _cats,
            builder: (cs) => Chips(['Todos', ...cs.map((c) => ptCategory(c.name))], _chip, (i) {
              setState(() {
                _chip = i;
                _cat = i == 0 ? null : cs[i - 1].id;
                _query = '';
                _photos = _load();
              });
            }),
          ),
          const SizedBox(height: 14),
          Async<String>(
            future: _fact,
            builder: (f) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(26)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Pill('Fato do dia', bg: kGreen),
                const SizedBox(height: 12),
                Text(f,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Async<List<CatImage>>(future: _photos, builder: (l) => PhotoGrid(l)),
        ]),
      );
}

// ------------------------------------------------ lib/screens/breeds.dart
/// Tela 3: lista de raças.
class BreedsPage extends StatefulWidget {
  const BreedsPage({super.key});
  @override
  State<BreedsPage> createState() => _BreedsPageState();
}

class _BreedsPageState extends State<BreedsPage> {
  late final Future<List<CatBreed>> _f = api.breeds();
  String _q = '';
  int _chip = 0;

  bool _ok(CatBreed b) {
    if (_q.isNotEmpty && !b.name.toLowerCase().contains(_q.toLowerCase())) return false;
    return switch (_chip) {
      1 => (b.energy ?? 3) <= 2, // Calmas
      2 => (b.energy ?? 0) >= 4, // Ativas
      3 => (b.social ?? 0) >= 4, // Sociáveis
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) => Screen(
        Column(children: [
          const Header('Conheça cada uma', 'Raças'),
          SearchBox('Buscar raça...', onChanged: (v) => setState(() => _q = v.trim())),
          Chips(const ['Todas', 'Calmas', 'Ativas', 'Sociáveis'], _chip, (i) => setState(() => _chip = i)),
          const SizedBox(height: 12),
          Expanded(
            child: Async<List<CatBreed>>(
              future: _f,
              builder: (all) {
                final l = all.where(_ok).toList();
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                  itemCount: l.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => _BreedRow(l[i], i),
                );
              },
            ),
          ),
        ]),
      );
}

class _BreedRow extends StatelessWidget {
  const _BreedRow(this.b, this.i);
  final CatBreed b;
  final int i;
  @override
  Widget build(BuildContext context) {
    final tags = b.tags.take(2).toList();
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BreedDetail(b))),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(width: 76, height: 76, child: NetImage(b.imageUrl, color: kPastels[i % 4])),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.name,
                  style: const TextStyle(color: kDark, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (var k = 0; k < tags.length; k++)
                  Pill(tags[k], bg: k == 0 ? kPastels[i % 4] : kSoft),
              ]),
            ]),
          ),
          const CircleAvatar(
              backgroundColor: kBg, child: Icon(Icons.chevron_right, color: kPrimary)),
        ]),
      ),
    );
  }
}

/// Tela 4: detalhe da raça (usa os dados já carregados da lista).
class BreedDetail extends StatelessWidget {
  const BreedDetail(this.b, {super.key});
  final CatBreed b;

  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    final ref = b.refImageId;
    final img = ref == null ? null : CatImage(id: ref, url: b.imageUrl ?? '');
    final fav = ref != null && st.isFav(ref);
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        SizedBox(
          height: 300,
          child: Stack(fit: StackFit.expand, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
              child: NetImage(b.imageUrl),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: kDark),
                        onPressed: () => Navigator.pop(context)),
                  ),
                  if (img != null)
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: kPink),
                        onPressed: () => safe(context, () => st.toggleFav(img)),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.name, style: const TextStyle(color: kDark, fontSize: 34, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, children: [
              Pill(b.origin ?? 'Origem desconhecida', bg: kSoft, fg: kPrimary),
              Pill(b.lifeSpan == null ? 'Vida: –' : '${b.lifeSpan} anos',
                  bg: const Color(0xFFD9F5E8), fg: const Color(0xFF0E8F63)),
            ]),
            const SizedBox(height: 16),
            Text(b.description ?? 'Sem descrição disponível.',
                style: const TextStyle(color: kMuted, fontSize: 16, height: 1.4)),
            const SizedBox(height: 20),
            _Bar('Afeto', b.affection, kPink),
            _Bar('Energia', b.energy, kGreen),
            _Bar('Inteligência', b.intelligence, kPrimary),
            _Bar('Sociabilidade', b.social, kOrange),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kPrimary),
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => BreedPhotos(b))),
                child: const Text('Ver fotos desta raça',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.label, this.value, this.color);
  final String label;
  final int? value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: const TextStyle(color: kDark, fontWeight: FontWeight.w800, fontSize: 16)),
            Text('${value ?? '–'} de 5', style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (value ?? 0) / 5,
            minHeight: 10,
            borderRadius: BorderRadius.circular(6),
            backgroundColor: kSoft,
            color: color,
          ),
        ]),
      );
}

class BreedPhotos extends StatelessWidget {
  const BreedPhotos(this.b, {super.key});
  final CatBreed b;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(b.name), backgroundColor: kBg),
        body: Async<List<CatImage>>(
          future: api.images(breedIds: b.id, limit: 20),
          builder: (l) => PhotoGrid(l, scrollable: true),
        ),
      );
}

// ------------------------------------------------ lib/screens/vote.dart
/// Tela 5: votar. ✖ = voto negativo, ⭐ = voto positivo, ❤ = favoritar.
class VotePage extends StatefulWidget {
  const VotePage({super.key});
  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  final _queue = <CatImage>[];
  List<Vote> _recent = [];
  bool _loading = true, _filling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fill();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecent());
  }

  Future<void> _fill() async {
    if (_filling) return;
    _filling = true;
    try {
      _queue.addAll(await api.images(limit: 10));
      _error = null;
    } catch (e) {
      _error = friendly(e);
    }
    _filling = false;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadRecent() async {
    try {
      final v = await api.votes(Scope.of(context).subId, limit: 4);
      if (mounted) setState(() => _recent = v);
    } catch (_) {}
  }

  void _next() {
    setState(() => _queue.removeAt(0));
    if (_queue.length < 3) _fill();
  }

  Future<void> _vote(int value) async {
    final img = _queue.first;
    final st = Scope.of(context);
    await safe(context, () async {
      await api.vote(img.id, value, st.subId);
      setState(() => _recent = [Vote(id: 0, imageId: img.id, value: value, imageUrl: img.url), ..._recent].take(4).toList());
    });
    if (_queue.isNotEmpty) _next();
  }

  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    final cur = _queue.isEmpty ? null : _queue.first;
    final b = cur != null && cur.breeds.isNotEmpty ? cur.breeds.first : null;
    return Screen(
      Column(children: [
        const Header('Quem leva o seu voto?', 'Votar'),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : cur == null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error ?? 'Sem fotos no momento.', style: const TextStyle(color: kMuted)),
                        TextButton(
                            onPressed: () {
                              setState(() => _loading = true);
                              _fill();
                            },
                            child: const Text('Tentar de novo')),
                      ]),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(34),
                        child: Stack(fit: StackFit.expand, children: [
                          NetImage(cur.url, color: kPastels[0]),
                          Positioned(
                              bottom: 16,
                              left: 16,
                              child: Pill(b == null ? 'Gato sem raça' : '${b.name} · ${b.origin ?? '–'}')),
                        ]),
                      ),
                    ),
        ),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Round(Icons.close, kPink, 60, Colors.white, cur == null ? null : () => _vote(-1)),
          const SizedBox(width: 22),
          _Round(
              cur != null && st.isFav(cur.id) ? Icons.favorite : Icons.favorite_border,
              Colors.white,
              76,
              kPink,
              cur == null ? null : () => safe(context, () => st.toggleFav(cur))),
          const SizedBox(width: 22),
          _Round(Icons.star_border, kPrimary, 60, Colors.white, cur == null ? null : () => _vote(1)),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
          child: Row(children: [
            const Expanded(
                child: Text('Últimos votos',
                    style: TextStyle(color: kDark, fontWeight: FontWeight.w800, fontSize: 16))),
            for (final v in _recent)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: Stack(clipBehavior: Clip.none, children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(width: 54, height: 54, child: NetImage(v.thumb))),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: v.value > 0 ? kGreen : kPink,
                        child: Icon(v.value > 0 ? Icons.star_border : Icons.close, size: 13, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round(this.icon, this.fg, this.size, this.bg, this.onTap);
  final IconData icon;
  final Color fg, bg;
  final double size;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(0, 6))],
          ),
          child: Icon(icon, color: fg, size: size * .45),
        ),
      );
}

// ------------------------------------------------ lib/screens/favourites.dart
/// Tela 6: favoritos do usuário (carregados no AppState).
class FavouritesPage extends StatefulWidget {
  const FavouritesPage({super.key});
  @override
  State<FavouritesPage> createState() => _FavouritesPageState();
}

class _FavouritesPageState extends State<FavouritesPage> {
  int _chip = 0;

  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    var l = st.favourites.map((f) => f.image).toList(); // já vem do mais recente ao mais antigo
    if (_chip == 0) l = l.reversed.toList(); // Todos
    if (_chip == 1) l.sort((a, b) => a.label.compareTo(b.label)); // Por raça
    // _chip == 2: Recentes (ordem original)
    return Screen(
      Column(children: [
        Header('${st.favourites.length} gatos salvos', 'Favoritos'),
        Chips(const ['Todos', 'Por raça', 'Recentes'], _chip, (i) => setState(() => _chip = i)),
        const SizedBox(height: 12),
        Expanded(child: PhotoGrid(l, scrollable: true)),
      ]),
    );
  }
}

// ------------------------------------------------ lib/screens/profile.dart
/// Tela 7: perfil, contadores, upload de fotos e votos.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<List<Vote>>? _votes;
  bool _sending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _votes ??= api.votes(Scope.of(context).subId);
  }

  Future<void> _pick() async {
    final st = Scope.of(context);
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    setState(() => _sending = true);
    await safe(context, () async {
      final id = await api.upload(x.path, st.subId);
      await st.addUpload(id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Foto enviada. Ela está em análise.')));
      }
    });
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Screen(
      ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 120), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(28)),
          child: Row(children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: kPink,
              child: Text(st.name.isEmpty ? 'G' : st.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(st.name,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                Text(st.email, style: const TextStyle(color: Color(0xFFD9D2FF))),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<Vote>>(
          future: _votes,
          builder: (c, s) => Row(children: [
            _Stat(Icons.star_border, kPrimary, kPastels[2], s.hasData ? '${s.data!.length}' : '–', 'Votos'),
            const SizedBox(width: 12),
            _Stat(Icons.favorite_border, kPink, kPastels[0], '${st.favourites.length}', 'Favoritos'),
            const SizedBox(width: 12),
            _Stat(Icons.upload, kGreen, kPastels[1], '${st.uploads.length}', 'Fotos'),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Minhas fotos',
                  style: TextStyle(color: kDark, fontWeight: FontWeight.w800, fontSize: 17)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _UploadsPage())),
                child: const Text('Ver todas', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final id in st.uploads.take(3))
                  Padding(padding: const EdgeInsets.only(right: 10), child: UploadTile(id, size: 96)),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: kPrimary, minimumSize: const Size(140, 64)),
                  onPressed: _sending ? null : _pick,
                  icon: _sending
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload),
                  label: const Text('Enviar nova foto', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            _Row('Meus votos', kDark, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _MyVotesPage()))),
            const SizedBox(height: 10),
            _Row('Sair da conta', kPink, () => st.logout()),
          ]),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.fg, this.bg, this.value, this.label);
  final IconData icon;
  final Color fg, bg;
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            CircleAvatar(backgroundColor: bg, child: Icon(icon, color: fg)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: kDark, fontSize: 24, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: kMuted)),
          ]),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.text, this.color, this.onTap);
  final String text;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 17)),
            Icon(Icons.chevron_right, color: color),
          ]),
        ),
      );
}

/// Foto enviada com selo Aprovada / Em análise / Recusada.
class UploadTile extends StatelessWidget {
  const UploadTile(this.id, {super.key, this.size = 110});
  final String id;
  final double size;
  @override
  Widget build(BuildContext context) => FutureBuilder<({String url, String status})>(
        future: api.uploadInfo(id),
        builder: (c, s) {
          final badge = s.hasData ? badgeFor(s.data!.status) : ('Carregando', kMuted);
          return SizedBox(
            width: size,
            height: size,
            child: Stack(alignment: Alignment.bottomCenter, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(width: size, height: size, child: NetImage(s.data?.url)),
              ),
              Positioned(bottom: 4, child: Pill(badge.$1, bg: badge.$2, fg: Colors.white)),
            ]),
          );
        },
      );
}

class _UploadsPage extends StatelessWidget {
  const _UploadsPage();
  @override
  Widget build(BuildContext context) {
    final ids = Scope.of(context).uploads;
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas fotos'), backgroundColor: kBg),
      body: ids.isEmpty
          ? const Center(child: Text('Você ainda não enviou fotos.', style: TextStyle(color: kMuted)))
          : GridView.count(
              padding: const EdgeInsets.all(20),
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              children: [for (final id in ids) UploadTile(id, size: 160)],
            ),
    );
  }
}

class _MyVotesPage extends StatelessWidget {
  const _MyVotesPage();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Meus votos'), backgroundColor: kBg),
        body: Async<List<Vote>>(
          future: api.votes(Scope.of(context).subId),
          builder: (l) => l.isEmpty
              ? const Center(child: Text('Você ainda não votou.', style: TextStyle(color: kMuted)))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: l.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(width: 64, height: 64, child: NetImage(l[i].thumb))),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Text(l[i].value > 0 ? 'Voto positivo' : 'Voto negativo',
                              style: const TextStyle(color: kDark, fontWeight: FontWeight.w700))),
                      Icon(l[i].value > 0 ? Icons.star : Icons.close,
                          color: l[i].value > 0 ? kGreen : kPink),
                    ]),
                  ),
                ),
        ),
      );
}

// ------------------------------------------------ lib/main.dart
void main() => runApp(const CatApp());

class CatApp extends StatefulWidget {
  const CatApp({super.key});
  @override
  State<CatApp> createState() => _CatAppState();
}

class _CatAppState extends State<CatApp> {
  final _state = AppState();

  @override
  void initState() {
    super.initState();
    _state.init();
  }

  @override
  Widget build(BuildContext context) => Scope(
        state: _state,
        child: MaterialApp(
          title: appName,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: kPrimary,
            scaffoldBackgroundColor: kBg,
          ),
          home: const Root(),
        ),
      );
}

class Root extends StatelessWidget {
  const Root({super.key});
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    if (!st.ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return st.logged ? const Shell() : const Onboarding();
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;
  static const _items = [
    (Icons.explore_outlined, 'Descobrir'),
    (Icons.menu, 'Raças'),
    (Icons.star_border, 'Votar'),
    (Icons.favorite_border, 'Favoritos'),
    (Icons.person_outline, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        body: IndexedStack(index: _i, children: const [
          DiscoverPage(),
          BreedsPage(),
          VotePage(),
          FavouritesPage(),
          ProfilePage(),
        ]),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, 8))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var k = 0; k < _items.length; k++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _i = k),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(horizontal: k == _i ? 18 : 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: k == _i ? kPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(children: [
                        Icon(_items[k].$1, color: k == _i ? Colors.white : kMuted),
                        if (k == _i) ...[
                          const SizedBox(width: 8),
                          Text(_items[k].$2,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}