# Mesa Arcana

Um jogo de descarte de cartas para 2 a 4 amigos, com ambientação fantástica, feito para aprender Godot. Nome sugerido para o repositório: **`mesa-arcana-godot`**.

Esta branch, **`home-server`**, contém a versão de deploy: menu, partida, ambientação e multiplayer com salas em um servidor central. Laboratórios, prévias e recursos experimentais ficam na branch `codex/servidor-salas-web`. É um projeto pessoal em evolução.

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

Importe `project.godot` no Godot **4.6.2**. A cena inicial é o menu.

O cenário aprovado (Turno visual v3) está em `config/cenario.json`, e a mixagem de Áudio V2 em `config/audio.json`. Projeção, sombras, chamas e animações pertencem ao código da partida, sem dependência dos laboratórios ou de conjuntos salvos no computador do autor.

Identificadores técnicos `JUNO` nas variáveis de ambiente e nos serviços Docker foram conservados por compatibilidade. A exportação web é feita no build; caches e arquivos gerados não entram no repositório.

## Origem dos assets

- Artes de ambientação e interface geradas com IA, conforme informado pelo autor. O logo foi adaptado para a identidade Mesa Arcana.
- Verso das cartas e desenho do monte substituídos por arte vetorial própria, sem a identidade visual anterior.
- Músicas obtidas de uma fonte CC0, conforme verificação informada pelo autor. O nome/URL do site ainda não foi recuperado; não há uma comprovação independente anexada aqui.
- A origem/licença dos efeitos sonoros ainda precisa ser identificada pelo autor.
- A fonte Barlow Condensed mantém sua [licença OFL](docs/OFL-BarlowCondensed.txt).

## Licença

O código deste projeto não tem uma licença de uso adicionada. Publicar o repositório não o coloca em domínio público nem concede uma licença geral de reutilização. Isso não altera os termos próprios dos componentes de terceiros, como a fonte OFL ou os áudios informados como CC0.
