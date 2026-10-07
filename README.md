# Mesa Arcana

Um jogo de descarte de cartas para 2 a 4 amigos, com ambientação fantástica, feito para aprender Godot. Nome sugerido para o repositório: **`mesa-arcana-godot`**.

O projeto explora animações de cartas em perspectiva, luzes, áudio, interface e multiplayer com salas em um servidor central. Há laboratórios para experimentar a composição visual e sonora. É um experimento pessoal em evolução, com ajustes e limitações, sem suporte ou estabilidade prometidos.

As mecânicas têm inspiração em jogos de descarte, incluindo UNO, da Mattel. Mesa Arcana é um projeto independente de estudo, sem vínculo, patrocínio ou aprovação da Mattel, e não é uma versão oficial de UNO.

## Jogar no navegador

Com Docker Desktop ou Docker Engine disponível, na raiz do projeto:

```sh
docker compose -f infra/compose.local.yml up --build -d
```

Abra [localhost:8080](http://localhost:8080/). O build baixa Godot 4.6.2, exporta o cliente web e inicia os dois serviços: web e servidor das salas. O primeiro download de templates tem cerca de 1,2 GB e fica em cache para os próximos builds.

O jogo roda no navegador e conecta ao servidor pelo proxy web. A porta do servidor não é publicada no host. As salas ficam em memória e são encerradas se o servidor reiniciar.

## Hospedar com Portainer e Traefik

Use uma stack por **Git repository**, com **Compose path** `infra/compose.traefik.yml` e a variável `JUNO_DOMAIN` preenchida com seu domínio, sem `https://`.

Os defaults seguem rede externa `traefik`, entrada `websecure` e resolver `leresolver`. O jogo abre sem login. Veja o [guia de hospedagem](docs/servidor-salas-web.md) para os detalhes.

As imagens Docker atuais usam Linux x86_64. O cliente web usa WebGL 2/Compatibility, sem threads. Áudio no navegador precisa de um clique inicial.

## Abrir no Godot

Importe `project.godot` no Godot **4.6.2**. A cena inicial é o menu; os laboratórios ficam em `scenes/desenvolvimento`.

O nome público é Mesa Arcana. Identificadores técnicos antigos `JUNO` nas variáveis de ambiente e nos serviços Docker foram conservados por compatibilidade. O diretório de dados dos laboratórios também permanece no caminho anterior para preservar os conjuntos locais.

## Origem dos assets

- Artes de ambientação e interface geradas com IA, conforme informado pelo autor. O logo foi adaptado para a identidade Mesa Arcana.
- Verso das cartas e desenho do monte substituídos por arte vetorial própria, sem a identidade visual anterior.
- Músicas obtidas de uma fonte CC0, conforme verificação informada pelo autor. O nome/URL do site ainda não foi recuperado; não há uma comprovação independente anexada aqui.
- O registro de preparação dos áudios está em [`audio/origem_arquivos.json`](audio/origem_arquivos.json). Esse registro contém caminhos de origem locais, não certificados de licença. A origem/licença dos efeitos sonoros não é identificada por ele.
- A fonte Barlow Condensed mantém sua [licença OFL](docs/OFL-BarlowCondensed.txt).

## Licença

O código deste projeto não tem uma licença de uso adicionada. Publicar o repositório não o coloca em domínio público nem concede uma licença geral de reutilização. Isso não altera os termos próprios dos componentes de terceiros, como a fonte OFL ou os áudios informados como CC0.
