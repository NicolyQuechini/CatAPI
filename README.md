# Cat App

Aplicativo Flutter que consome a [The Cat API](https://thecatapi.com) para explorar fotos e raças de gatos, votar, favoritar e enviar fotos próprias.

> Entrega parcial da disciplina. As limitações conhecidas estão em [PENDENCIAS.md](PENDENCIAS.md).

## Funcionalidades

- **Onboarding:** tela de apresentação e entrada simples com nome e e-mail (local, sem senha).
- **Descobrir:** galeria de fotos, busca, filtro por categoria e "Fato do dia".
- **Raças:** lista de raças com busca e filtros (Calmas, Ativas, Sociáveis).
- **Detalhe da raça:** origem, expectativa de vida, descrição e notas de afeto, energia, inteligência e sociabilidade.
- **Votar:** voto positivo, negativo ou favorito em fotos aleatórias, com os últimos votos.
- **Favoritos:** fotos salvas, com filtros Todos, Por raça e Recentes.
- **Perfil:** contadores de votos, favoritos e fotos; envio de fotos com status (Aprovada, Em análise, Recusada); lista de votos.

## Tecnologias

- Flutter (Dart 3) e Material 3
- Pacotes: `http`, `shared_preferences`, `image_picker`
- API: The Cat API v1 (`https://api.thecatapi.com/v1`)

## Estrutura

```
lib/
└── main.dart   # API (modelos e cliente), estado, componentes e as 7 telas
```

O código está em um único arquivo, organizado em blocos: modelos e `CatApi`, `AppState` (usuário, favoritos e uploads), widgets reutilizáveis e as telas.

## Como executar

1. Instale o [Flutter](https://docs.flutter.dev/get-started/install).
2. Crie uma conta e pegue a chave em [thecatapi.com](https://thecatapi.com).
3. Clone o repositório e instale as dependências:
   ```
   git clone <URL_DO_REPOSITORIO>
   cd cat_app
   flutter pub get
   ```
4. Informe a chave. No `lib/main.dart`, troque o valor de `apiKey`, **ou** passe-a ao executar:
   ```
   flutter run --dart-define=CAT_API_KEY=SUA_CHAVE
   ```
5. **Android:** garanta a permissão de internet em `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```
   **iOS:** adicione `NSPhotoLibraryUsageDescription` ao `Info.plist` (necessário para enviar fotos).

> Nunca publique a sua chave da API no repositório.

## Endpoints utilizados

Base: `https://api.thecatapi.com/v1`. Todas as chamadas enviam o cabeçalho `x-api-key`.

| Tela | Método | Endpoint |
|---|---|---|
| Descobrir, Votar, Detalhe da raça | GET | `/images/search` |
| Raças | GET | `/breeds` |
| Descobrir (busca) | GET | `/breeds/search?q=` |
| Descobrir | GET | `/facts/random` |
| Descobrir | GET | `/categories` |
| Votar | POST | `/votes` |
| Votar, Perfil | GET | `/votes` |
| Descobrir, Votar, Detalhe | POST | `/favourites` |
| Favoritos | GET | `/favourites` |
| Favoritos, demais telas | DELETE | `/favourites/{id}` |
| Perfil | POST | `/images/upload` |
| Perfil | GET | `/images/{id}` e `/images/{id}/status` |

## Identificação do usuário

A Cat API não tem login. O app gera um `sub_id` a partir do e-mail informado e o envia em votos e favoritos, para separar os dados de cada pessoa. Não há senha: é uma solução provisória.

## Documentação da API

A documentação completa da The Cat API (funcionalidades, endpoints, significado dos campos e estruturas de dados para o Flutter) está na pasta [`docs/`](docs/).

## Cuidados com a cota

O plano gratuito permite 10.000 requisições por mês. O app guarda a lista de raças em memória e usa `include_breeds` para evitar chamadas extras.

## Autor

<seu nome> — <curso / disciplina>
