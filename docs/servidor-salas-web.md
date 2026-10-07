# Mesa Arcana: servidor de salas e jogo web em Docker

Branch: `codex/servidor-salas-web`, a partir do checkpoint `0cba34d`.

Nome público atual: **Mesa Arcana**, um projeto independente de estudo. Nomes técnicos `juno-*`/`JUNO_*` foram preservados para manter as configurações de infraestrutura existentes. O README da raiz apresenta o projeto para o futuro repositório `mesa-arcana-godot`.

## Subir localmente

Na raiz do projeto:

```powershell
docker compose -f infra/compose.local.yml up --build -d
```

Abra **http://localhost:8080**. Não precisa exportar manualmente nem abrir o executável: o build baixa Godot 4.6.2 e seu template web, importa o projeto, exporta o jogo e coloca os arquivos dentro da imagem do serviço web. O primeiro download de templates tem cerca de 1,2 GB; Docker reutiliza a camada nos builds seguintes.

Os dois serviços são iniciados por padrão:

- `juno-web`: nginx entrega o jogo exportado e encaminha `/multiplayer` por WebSocket ao servidor interno. Só ele publica a porta 8080, ligada a localhost no teste.
- `juno-servidor`: Godot sem janela executa as regras e mantém salas, mãos e conexões. Não publica porta no host. Está apenas na rede `juno-interna`, marcada como interna.

O jogo roda no navegador do jogador. Ele conecta em `ws://localhost:8080/multiplayer`; nginx encaminha para `juno-servidor:9080` na rede do Compose. Cada aba é um cliente independente. O primeiro clique libera a música; depois Jogar abre a lista de mesas e a entrada por código. Uma sala aceita de dois a quatro jogadores.

A infraestrutura esconde a porta do servidor, mas **não prova que o cliente é um navegador**. Um programa compatível pode usar o mesmo WebSocket público. Restringir participantes exige autenticação/autorização; checar Origin ou esconder a porta não elimina essa possibilidade. Não há promessa de bloqueio de executáveis nesta versão.

Para acompanhar o funcionamento:

```powershell
docker compose -f infra/compose.local.yml ps
docker compose -f infra/compose.local.yml logs -f
```

Para parar este Compose:

```powershell
docker compose -f infra/compose.local.yml down
```

## Home server com Traefik

O Compose `infra/compose.traefik.yml` segue o Traefik fornecido pelo usuário: rede externa `traefik`, entrypoint `websecure` e resolver `leresolver`. Só o domínio é obrigatório. Não há login, middleware de autenticação, banco, secrets, volumes do host ou modo privilegiado. O acesso abre diretamente o jogo.

### Portainer pelo repositório Git

Depois de colocar este projeto no GitHub:

1. No ambiente **Docker Standalone** do home server, abra **Stacks > Add stack** e dê o nome `juno`.
2. Escolha **Git repository** e informe a URL do repositório. Ele pode ser público ou privado; para privado, configure a credencial do repositório no Portainer. Isso não adiciona login ao jogo.
3. Escolha a branch que contém estes arquivos (atualmente `codex/servidor-salas-web`; use `main` se levar as alterações para ela).
4. Em **Compose path**, informe `infra/compose.traefik.yml`.
5. Em **Environment variables**, adicione `JUNO_DOMAIN` com o domínio real escolhido, sem `https://` nem barra final. Por exemplo, `juno.zvcore.com`, se esse for o subdomínio que você configurar. O DNS precisa apontar para o home server e o Traefik existente precisa receber esse domínio.
6. Clique **Deploy the stack**. O build constrói servidor e web e exporta o jogo automaticamente; o primeiro download dos templates é grande. Depois abra `https://SEU-DOMINIO`.

Use a opção de repositório porque o `build` precisa do Dockerfile e dos demais arquivos do projeto. Colar somente este YAML no Web editor não fornece o código para construir as imagens. Não são usados bind mounts relativos nem é necessário configurar volumes de caminhos relativos.

Os defaults de `TRAEFIK_NETWORK`, `TRAEFIK_ENTRYPOINT` e `TRAEFIK_CERTRESOLVER` podem ser substituídos nas variáveis da stack se a infraestrutura mudar. Não é necessário preencher nenhum deles para o Traefik do exemplo. O Compose não cria nem modifica o Traefik existente.

### Alternativa pelo terminal

Copie o projeto para o home server, copie `infra/.env.example` para `infra/.env` e preencha o domínio. Depois:

```sh
docker compose --env-file infra/.env -f infra/compose.traefik.yml up --build -d
```

Os dois serviços também sobem juntos e a exportação é feita no build. Somente `juno-web` participa da rede externa do Traefik e tem labels de publicação. `juno-servidor` tem `traefik.enable=false` e permanece apenas na rede interna. O domínio recebe HTTPS do Traefik; a página usa automaticamente `wss://SEU-DOMINIO/multiplayer`, passando por nginx até o servidor.

Não é necessário abrir a porta 9080 no roteador ou montar uma pasta de exportação manual. A imagem atual usa Linux x86_64. Cliente web usa Compatibility/WebGL 2, sem threads, e áudio em Stream para preservar a mixagem; desempenho e tons das luzes precisam de avaliação no navegador.

## Regras e salas

Servidor e cliente compartilham os scripts de regras deste projeto. O Docker do servidor copia somente cartas, lógica, rede e sua cena/autoload reduzidos; imagens, áudio e UI ficam no cliente web. Não há outra implementação das regras em outra linguagem.

Criar sala gera um código de seis caracteres e publica a mesa na lista. O organizador inicia, mas não hospeda a partida no computador dele. O servidor valida o remetente pela conexão e pela sala, filtra cartas privadas por jogador e distingue cada rodada por ID. Chat, erros e eventos ficam dentro da sala correspondente.

Ao sair durante uma partida, somente aquela sala é interrompida; os restantes podem iniciar outra rodada. Se o organizador sai, o primeiro participante restante assume. Salas vazias são removidas. Reiniciar o servidor encerra as salas, pois esta versão não usa banco de dados.

`config/rede.cfg` e variáveis `JUNO_PORTA`, `JUNO_BIND`, `JUNO_MAX_CLIENTES`, `JUNO_MAX_SALAS` configuram a rede. Por padrão são 128 conexões e 32 salas. O cliente web deriva a URL do domínio da página quando `cliente/url` está vazio; deixe vazio para esta composição.

O executável desktop e o modo direto LAN permanecem no código para desenvolvimento. Como o Compose local não publica a porta 9080, a URL desktop antiga de localhost:9080 não alcança esse servidor. Um desktop configurado para a URL pública do proxy ainda pode comunicar pelo protocolo, conforme a limitação explicada acima.

## Conferência

Teste em várias abas: criar/entrar por código, iniciar com 2–4 participantes, jogar/comprar/inverter/escolher cor/trocar mãos. Abra duas salas simultâneas e confira que chat, cartas e desconexões não se misturam. Avalie a aparência do Turno visual v3 e a abertura/áudio no browser.

O usuário autorizou executar Godot, exportação e containers nesta rodada, substituindo a restrição anterior para esta tarefa. O resultado da execução local é registrado nos documentos de contexto.

Fontes: [exportação web Godot](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html), [WebSocketMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_websocketmultiplayerpeer.html), [servidores dedicados](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html).

Instruções do Portainer: [criar stack a partir de Git](https://docs.portainer.io/user/docker/stacks/add).
