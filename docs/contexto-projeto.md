# JUNO — contexto para continuar o projeto

Atualizado em 30/09/2026. Este documento orienta a navegação no código e registra as decisões do projeto. O usuário tem seu próprio planejamento de próximas entregas; alinhar o pedido atual com ele antes de ampliar o escopo.

## Projeto e forma de trabalhar

- Jogo de cartas em Godot 4.6.2, GDScript, com anfitrião participante e partidas de 2 a 4 jogadores por ENet/IP.
- Nome atual: **JUNO**. Há nomes e artes herdados da fase inicial de UNO; não renomear tudo automaticamente.
- Código em português, simples, bem escrito e com comentários apenas quando explicam algo necessário. Preservar os nomes existentes em inglês sem fazer uma reorganização geral.
- **Scripts ficam em `scripts`; cenas ficam em `scenes`. Nunca misturar.** Testes e prévias têm subpastas próprias dentro de cada uma dessas pastas.
- A organização atual satisfaz o usuário. Evitar novas camadas, pastas e refatorações amplas sem necessidade concreta.
- Preservar encapsulamento e coesão: operações internas de um componente podem ser chamadas diretamente; sinais são usados para comunicação entre componentes quando fazem sentido. Não transformar cada operação em um sinal.
- Quando o usuário pede discussão ou planejamento, discutir antes de implementar. Evoluir o visual em entregas pequenas e apresentar para avaliação.
- O usuário trabalha no editor e costuma executar as cenas manualmente. Ele autorizou novamente abrir o Godot para comparações visuais, mas evitar execuções repetidas ou pesadas sem propósito.
- O repositório é local. Fazer commits quando solicitado. `export_presets.cfg` é uma configuração legítima de exportação criada pelo usuário e ficou fora dos commits até aqui; não excluir nem incluir silenciosamente.
- Arquivos `.uid` e referências de recursos são relevantes para o Godot. Preservar os existentes e incluir os de scripts novos quando gerados.

## Onde começar a leitura

1. `project.godot`: nome, cena inicial, autoload e configuração de janela/renderização.
2. `scenes/game_manager.tscn` e `scripts/globais/game_manager.gd`: montagem e ligações entre rede e barramento.
3. `scripts/rede/endpoint_partida.gd`: entrada de comandos, associação da conexão ao jogador e entrega dos eventos.
4. `scripts/logica/mesa_api.gd` e `scripts/logica/mesa_logica.gd`: regras e estado autoritativo.
5. `scripts/scripts_de_cena/partida_rede.gd` e `mesa_partida.gd`: ligação da interface com os comandos e eventos.
6. O componente visual específico da alteração: carta, mão, monte, descarte, chat ou fundo.

Há um diagrama e regras detalhadas em [arquitetura-multiplayer.md](arquitetura-multiplayer.md). Algumas referências ali são históricas: `SceneRouter` é uma proposta, não uma classe implementada; atualmente o menu troca de cena diretamente.

## Organização existente

- `scenes/menu_principal.tscn`: cena inicial, com título JUNO, Jogar e Sair.
- `scenes/partida_rede.tscn`: conexão por nome/IP/porta, sala, mesa real e chat.
- `scenes/mesa_partida.tscn`: apresentação da partida, mãos, compra, descarte e escolhas de cor/alvo.
- `scenes/carta.tscn`, `mao.tscn`, `monte.tscn`, `descarte.tscn`: componentes visuais reutilizáveis.
- `scenes/fundo_mesa.tscn`: fundo compartilhado pelo menu, conexão e mesa.
- `scenes/chat_partida.tscn`: painel recolhível do chat.
- `scenes/teste.tscn` e `scripts/teste.gd`: laboratório original do usuário para testar objetos, leque, virada, compra e troca entre mãos. **Preservar como laboratório; não convertê-lo na partida final.**
- `scenes/tests/previa_mesa_partida.tscn`: instancia a mesa real sem conexão, com dois jogadores; comandos locais passam pela mesma lógica e filtragem. Não inclui o chat nem representa toda a experiência de quatro jogadores.
- `scenes/tests/teste_mesa_basica.tscn`, `teste_rede_quatro.tscn`, `teste_chat_rede.tscn`: verificações de recortes da lógica e rede, com scripts em `scripts/tests`.
- `scripts/cartas`: objetos lógicos e sua hierarquia, separados da carta visual.
- `scripts/logica`: mesa, API de comandos, contexto de efeitos, jogadores, baralho, descarte e filtragem de eventos.
- `scripts/rede`: conexão e endpoints de partida/chat.
- `scripts/globais`: autoload e barramento.
- `scripts/scripts_de_cena`: scripts visuais e shaders existentes. Manter essa organização.
- `images`: sprites, moldura, verso e fonte Barlow Condensed Bold. Licença da fonte em `docs/OFL-BarlowCondensed.txt`.

## Arquitetura e responsabilidades

### Lógica do jogo

`Mesa_Logica` é um `Resource`: guarda jogadores, mãos, baralho, descarte, ordem/turno, fase, compra acumulada e escolhas pendentes. Não conhece RPCs nem interface.

`Mesa_Api` é um `RefCounted`: recebe os comandos, valida e coordena mudanças na mesa. Retorna um dicionário com sucesso ou erro/mensagem e uma lista ordenada de eventos. Comandos recusados não devem alterar o estado.

As classes `Carta_*` de `scripts/cartas` representam cartas lógicas, com ID, valor, cor e efeito. `Carta_Base.para_dados()` serializa esses dados. IDs de cartas identificam objetos; não usar posição no array como identidade.

`Efeitos_Api` é um contexto interno de efeitos, apesar do nome. As cartas chamam suas operações; ele altera a mesa e registra fatos. **Não é um endpoint de rede.**

`Baralho_Logico` centraliza composição, criação e reposição. A partida e o laboratório reutilizam esse comportamento. `Jogador_Logico` contém a mão lógica; `Descarte_Logico` contém o descarte. A lista circular em `scripts/logica/auxiliares` sustenta a ordem dos jogadores.

### Rede e barramento

`GameManager` é o autoload de `scenes/game_manager.tscn`. Seus filhos persistentes são `EventBus`, `NetworkManager`, `MatchEndpoint` e `ChatEndpoint`; manter os caminhos iguais entre as instâncias para os RPCs.

`GerenciadorRede` cuida de ENet, apresentação/handshake, participantes, início permitido e desconexões. O anfitrião é jogador 1. Outros IDs estáveis de jogador são atribuídos pelo servidor e **não são os IDs dos peers do Godot**. O servidor identifica o remetente pela conexão, não por um ID de jogador enviado pelo cliente.

`EndpointPartida` executa comandos pela `Mesa_Api` no servidor e distribui os resultados. O anfitrião recebe os mesmos eventos filtrados localmente; os clientes recebem por RPC confiável. `_id_partida` distingue rodadas na comunicação.

`VisibilidadeEventos.para_jogador()` filtra cada evento antes de entregá-lo. Quantidades e ações são públicas; identidades de cartas da mão são privadas. Eventos exclusivos de um destinatário retornam vazios para os outros. A prévia local usa a mesma filtragem.

`BarramentoEventos` contém sinais de comunicação local, sem regras do jogo. Ele transporta solicitações e resultados; comprar, jogar, escolher cor etc. são nomes do comando em `comando_solicitado`, não um sinal diferente para cada ação.

Fluxo da partida em rede: `TelaMesa` emite uma solicitação → `partida_rede.gd` encaminha ao barramento → `GameManager` encaminha ao endpoint → servidor valida e altera a lógica → endpoint filtra os eventos por jogador → barramento local avisa a interface → interface apresenta os fatos.

Conectar/hospedar/sair e iniciar a sala usam diretamente os gerenciadores/endpoints existentes. O chat tem endpoint próprio e não depende das regras da mesa nem da fila de animações.

### Apresentação

`partida_rede.gd` liga conexão, sala e mesa aos sinais do autoload. `TelaMesa`, em `mesa_partida.gd`, traduz eventos em apresentação e emite intenções do usuário. A fila visual espaça a apresentação; não atrasa nem muda o processamento autoritativo do servidor.

`Carta`, em `carta.gd`, é um **Control visual**, diferente de `Carta_Base`. Ela cuida de desenho, sombra, hover, perspectiva, virada, deslocamento e mudança animada da cor. Preferir suas operações (`reposicionar`, `alterar_cor_visual`, `definir_jogavel`, `setup_dados`) a manipular seus nós internos de fora.

`MaoVisual` cuida do leque, virada conforme o dono e escurecimento de cartas não jogáveis. Recebe IDs permitidos calculados pela lógica. Mãos laterais reutilizam a mesma cena rotacionada. `receber_carta_do_monte()` preserva a origem da carta e compensa a rotação da mão antes de animar o leque.

`MonteVisual.criar_carta()` instancia a carta centralizada no monte, com dados conhecidos ou como verso sem dados. `DescarteVisual.receber_carta()` recebe e posiciona as cartas no descarte. Reutilizar esses componentes e evitar duplicar seu comportamento em cada tela.

## Decisões de regras que não devem ser desfeitas por acidente

- Distribuição inicial: sete cartas por jogador, alternando uma carta por pessoa a cada rodada do loop. Uma carta numérica inicia o descarte e o primeiro jogador cadastrado começa.
- Distribuição inicial, compra voluntária e penalidade usam a mesma entrega lógica de uma carta. Cada entrega gera seu próprio `CartaRecebida`, com quantidade pública e dados privados para o dono. Não juntar em um batch por iniciativa própria.
- Na compra voluntária, o jogador pode continuar comprando até encontrar uma carta jogável. Depois de começar a comprar, só pode jogar a carta jogável recém-comprada ou passar a vez; não pode escolher outra da mão nem continuar comprando após encontrar a jogável.
- Ao esgotar o monte, `Baralho_Logico.comprar_carta()` cria um baralho novo da composição configurada, com novos IDs. **Não reciclar o descarte.** Essa foi uma escolha explícita posterior ao plano inicial.
- Pular e inverter com dois jogadores devolvem a vez a quem jogou.
- `+2` rebate `+2` e acumula. `+4` rebate `+4`, mas não pode rebater `+2`. `+2` só rebate `+4` se corresponder à cor escolhida para o `+4`.
- Aceitar a pilha faz comprar toda a penalidade e perder a vez. As cartas recebidas nessa penalidade não ficam disponíveis para jogar naquele turno.
- Escolha de cor altera a cor do próprio objeto lógico pelo ID. A mesa não guarda uma segunda cor concorrente para o topo. Se a carta está no descarte, notificar todos; na mão, somente o dono; no monte, só atualizar o objeto no servidor.
- Mudar a cor não remove o efeito especial da classe da carta. Essa mudança de comportamento foi adiada explicitamente.
- Troca de mãos com dois jogadores escolhe o adversário automaticamente; com três ou quatro, pede alvo. Depois da troca, pede cor. Os dados completos das novas mãos chegam só aos respectivos donos.
- A vitória considera **todos** os jogadores após os efeitos e escolhas pendentes, antes do próximo turno, em `Mesa_Api._concluir_jogada()`. Ao jogar troca de mãos como última carta, a mão vazia passa ao adversário e ele vence.
- Se a última carta gera uma pilha de compra, o próximo jogador compra automaticamente a penalidade antes do encerramento, sem rebater. `+4` resolve a escolha de cor antes disso.
- O anfitrião inicia manualmente uma sala de 2 a 4 jogadores. Saída durante a partida interrompe a rodada e devolve os restantes à sala; saída do anfitrião encerra a conexão dos clientes. Não há retomada da rodada ou migração de anfitrião.

## Visual atual e pontos de ajuste

Direção: retrô/arcade com sensação de mesa física; repouso calmo e respostas breves às ações. O usuário avalia o visual por pequenas entregas.

As cinco cores visuais são centralizadas em `Carta.MAP_CORES`, em `scripts/scripts_de_cena/carta.gd`:

- Vermelho: `#8F1E28`.
- Verde: `#2F6B3B`.
- Amarelo: `#B88A1B`.
- Azul: `#2A4F8F`.
- Preto/coringa: `#14161A`.

A paleta muda o fundo da carta, sem substituir os sprites. O verso e os ícones coloridos internos são imagens e não são recoloridos automaticamente por esse mapa.

`fundo_mesa.tscn` compartilha o fundo entre telas. Cores de referência: `#0C382C` e `#174A3A`. A cena tem intensidade `1.0` e extensão `0.76`, ajustadas pelo usuário; os defaults do script são diferentes. Sempre conferir overrides no Inspector/`.tscn` antes de alterar um default no script.

As cartas usam `SubViewport` transparente com a arte interna, uma textura para apresentação e `carta_perspectiva.gdshader` para perspectiva/contorno. A renderização interna usa resolução ampliada para suavizar a inclinação mantendo a arte pixelada. Preservar proporções e desenho dos sprites.

`Carta.reposicionar()` mantém movimento de **1 segundo**, com cubic/ease-out. Hover usa elastic/ease-out na entrada e saída. A sombra compensa transformações para manter o deslocamento visual na tela. Não confundir duração do deslocamento com intervalo entre entregas: a distribuição inicial usa `0.09 s`; outras entregas usam `0.15 s` definido em `mesa_partida.tscn` (default do script: `0.25 s`). Animações podem se sobrepor.

Godot `Control` não tem `global_rotation`. A orientação global é compensada usando `rotation` e `get_global_transform().get_rotation()`. Esse erro já foi corrigido na entrada da carta na mão.

O menu atual é uma cena separada, com título JUNO e ações Jogar/Sair. Jogar abre `partida_rede.tscn`; a conexão possui Voltar ao menu quando o formulário está disponível. A fonte Barlow Condensed Bold já é usada nos nomes de jogadores e no menu.

## Validação e cuidados práticos

- A janela de referência é 1280×720, com stretch `canvas_items`/aspect `expand`; também foram consideradas telas de 1920×1080.
- Para revisar a mesa real sem rede, usar `scenes/tests/previa_mesa_partida.tscn`. Para interações completas, executar o projeto pelo menu ou `partida_rede.tscn` em instâncias separadas.
- O laboratório `teste.tscn` tem fundo cinza e áreas ciano das mãos. Isso é próprio daquela cena, não a aparência final da mesa.
- O usuário já validou manualmente lógica básica, multiplayer, cartas especiais, distribuição e troca de mãos em etapas anteriores. Esse histórico não equivale a uma verificação de toda alteração futura.
- Neste ambiente, tentativas de lançar o Godot diretamente por terminal para capturas chegaram a falhar com `signal 11`, inclusive em compatibilidade/headless. A causa não foi diagnosticada; não atribuir automaticamente o crash ao código do jogo nem alterar permanentemente o renderer para contornar.
- As últimas comparações de paleta foram imagens compostas a partir dos assets, com hexadecimais exatos e aproximação do fundo. Não eram screenshots do Godot. As prévias e arquivos temporários foram removidos do repositório.
- Em alterações visuais, revisar a composição nas cenas reais e preservar o teste original. Em alterações de regra/rede, revisar eventos, destinatários, ordem e tratamento do anfitrião.

Este arquivo é um ponto de entrada. Antes de editar, ler o código do componente envolvido e confirmar o pedido atual do usuário; evitar reconstruir funcionalidades que já existem.
