# Lista de Pendências

Estado da entrega parcial do Cat App.

## Concluído

- [x] 7 telas do wireframe implementadas
- [x] Integração com a Cat API: imagens, raças, votos, favoritos e upload
- [x] Tratamento de erros da API (chave inválida, limite excedido, sem conexão)
- [x] Favoritar e desfavoritar em todas as telas, com estado compartilhado
- [x] Cache da lista de raças em memória

## Pendências e limitações conhecidas

| Nº | Item | Detalhe | Prioridade |
|---|---|---|---|
| 1 | Fato do dia | O endpoint `/facts/random` foi recusado pela API com o plano gratuito (erro 401/403). O app mostra um fato fixo como alternativa. | Média |
| 2 | Filtro por categoria | `/categories` foi recusado com o plano gratuito, e o parâmetro `category_ids` em `/images/search` não foi confirmado. | Média |
| 3 | Status das fotos enviadas | O formato da resposta de `/images/{id}/status` ainda não foi validado em testes reais; os selos podem aparecer sempre como "Em análise". | Alta |
| 4 | Lista de fotos enviadas | A API não tem endpoint para listar os uploads do usuário. O app guarda os IDs localmente, então eles se perdem se o app for reinstalado. | Média |
| 5 | Login | Entrada local (nome e e-mail), sem senha nem servidor. Falta autenticação real (ex.: Firebase Auth). | Média |
| 6 | Filtros de raças | Calmas, Ativas e Sociáveis são calculados no app por `energy_level` e `social_needs`, não pela API. | Baixa |
| 7 | Detalhe da raça | O ❤️ favorita a foto de referência da raça, porque a API só favorita imagens. | Baixa |
| 8 | Filtro "Por raça" nos favoritos | Depende de a API devolver as raças junto com a imagem favorita; pode ficar sem agrupamento. | Baixa |
| 9 | Contadores do perfil | Votos vêm de `GET /votes` (máx. 100), favoritos do estado local e fotos do armazenamento local. | Baixa |
| 10 | Testes automatizados | Nenhum teste unitário ou de widget foi escrito. | Média |
| 11 | Código em um único arquivo | Dividir em pastas (`models`, `services`, `screens`, `widgets`) para facilitar a manutenção. | Baixa |
| 12 | Paginação | As listas carregam 10 a 100 itens, sem rolagem infinita. | Baixa |
| 13 | Segurança da chave | A chave fica no app. Em produção, usar um servidor intermediário. | Alta |

## Próximos passos

1. Validar o status de upload com uma foto real e ajustar os selos.
2. Testar os endpoints recusados com outra chave ou plano.
3. Implementar autenticação real.
4. Separar o código em módulos e escrever testes.
5. Adicionar paginação e estados vazios mais completos.
