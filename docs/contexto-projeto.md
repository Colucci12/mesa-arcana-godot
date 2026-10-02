# JUNO — contexto para continuar o projeto

Atualizado em 01/10/2026. Este documento orienta a navegação no código e registra as decisões do projeto. O usuário tem seu próprio planejamento de próximas entregas; alinhar o pedido atual com ele antes de ampliar o escopo.

## Projeto e forma de trabalhar

- Jogo de cartas em Godot 4.6.2, GDScript, com anfitrião participante e partidas de 2 a 4 jogadores por ENet/IP.
- Nome atual: **JUNO**. Há nomes e artes herdados da fase inicial de UNO; não renomear tudo automaticamente.
- Código em português, simples, bem escrito e com comentários apenas quando explicam algo necessário. Preservar os nomes existentes em inglês sem fazer uma reorganização geral.
- **Scripts ficam em `scripts`; cenas ficam em `scenes`. Nunca misturar.** Cenas usadas no jogo ficam em `scenes/main`, separadas em `telas`, `componentes` e `globais`; seus scripts e shaders acompanham essa divisão em `scripts/main`. Prévias, laboratórios e testes ficam em `desenvolvimento`, com subpastas próprias dentro de `scenes` e `scripts`.
- A organização atual satisfaz o usuário. Evitar novas camadas, pastas e refatorações amplas sem necessidade concreta.
- Preservar encapsulamento e coesão: operações internas de um componente podem ser chamadas diretamente; sinais são usados para comunicação entre componentes quando fazem sentido. Não transformar cada operação em um sinal.
- Quando o usuário pede discussão ou planejamento, discutir antes de implementar. Evoluir o visual em entregas pequenas e apresentar para avaliação.
- O usuário executa as cenas e valida o visual no editor. Não abrir o jogo para gerar capturas por iniciativa própria; nesta etapa, a comparação visual fica com ele.
- O repositório é local. Fazer commits quando solicitado. `export_presets.cfg` é uma configuração legítima de exportação criada pelo usuário e ficou fora dos commits até aqui; não excluir nem incluir silenciosamente.
- Arquivos `.uid` e referências de recursos são relevantes para o Godot. Preservar os existentes e incluir os de scripts novos quando gerados.

## Onde começar a leitura

1. `project.godot`: nome, cena inicial, autoload e configuração de janela/renderização.
2. `scenes/main/globais/game_manager.tscn` e `scripts/main/globais/game_manager.gd`: montagem e ligações entre rede e barramento.
3. `scripts/rede/endpoint_partida.gd`: entrada de comandos, associação da conexão ao jogador e entrega dos eventos.
4. `scripts/logica/mesa_api.gd` e `scripts/logica/mesa_logica.gd`: regras e estado autoritativo.
5. `scripts/main/telas/partida_rede.gd` e `scripts/main/componentes/mesa_partida.gd`: ligação da interface com os comandos e eventos.
6. O componente visual específico da alteração: carta, mão, monte, descarte, chat ou fundo.

Há um diagrama e regras detalhadas em [arquitetura-multiplayer.md](arquitetura-multiplayer.md). Algumas referências ali são históricas: `SceneRouter` é uma proposta, não uma classe implementada; atualmente o menu troca de cena diretamente.

## Organização existente

`main` identifica cenas e componentes usados pelo jogo, não uma única cena inicial. O fluxo é `menu_principal` → `partida_rede`, que instancia `mesa_partida` e o chat. `GameManager` é carregado como autoload. As cenas de `desenvolvimento` são executadas separadamente e reutilizam os componentes de `main`.

- `scenes/main/telas/menu_principal.tscn`: cena inicial, com título JUNO, Jogar e Sair.
- `scenes/main/telas/partida_rede.tscn`: conexão por nome/IP/porta, sala, mesa real e chat.
- `scenes/main/componentes/mesa_partida.tscn`: apresentação da partida, mãos, compra, descarte e escolhas de cor/alvo.
- `scenes/main/componentes/carta.tscn`, `mao.tscn`, `monte.tscn`, `descarte.tscn`: componentes visuais reutilizáveis.
- `scenes/main/componentes/fundo_mesa.tscn`: fundo compartilhado pelo menu, conexão e mesa.
- `scenes/main/componentes/chat_partida.tscn`: painel recolhível do chat.
- `scenes/main/componentes/luz_mesa.tscn`: iluminação modular instanciada pela mesa; script e shaders em `scripts/main/componentes`.
- `scenes/desenvolvimento/laboratorios/teste.tscn` e `scripts/desenvolvimento/laboratorios/teste.gd`: laboratório original do usuário para testar objetos, leque, virada, compra e troca entre mãos. **Preservar como laboratório; não convertê-lo na partida final.**
- `scenes/desenvolvimento/previas/previa_mesa_partida.tscn`: instancia a mesa real sem conexão, com dois jogadores; comandos locais passam pela mesma lógica e filtragem. Não inclui o chat nem representa toda a experiência de quatro jogadores.
- `scenes/desenvolvimento/previas/previa_acabamento_carta.tscn`: comparação visual entre carta original e acabamento de impressão, com ajustes para experimentação.
- `scenes/desenvolvimento/tests/teste_mesa_basica.tscn`, `teste_rede_quatro.tscn`, `teste_chat_rede.tscn`: verificações de recortes da lógica e rede, com scripts em `scripts/desenvolvimento/tests`.
- `scripts/cartas`: objetos lógicos e sua hierarquia, separados da carta visual.
- `scripts/logica`: mesa, API de comandos, contexto de efeitos, jogadores, baralho, descarte e filtragem de eventos.
- `scripts/rede`: conexão e endpoints de partida/chat.
- `scripts/main/globais`: autoload e barramento.
- `scripts/main/telas`: scripts do menu e da partida em rede.
- `scripts/main/componentes`: scripts visuais reutilizáveis, shaders e includes compartilhados.
- `scripts/desenvolvimento`: scripts de prévias, laboratórios e testes nas mesmas subpastas das cenas. Os nomes existentes foram preservados.
- `images`: sprites, moldura, verso e fonte Barlow Condensed Bold. Licença da fonte em `docs/OFL-BarlowCondensed.txt`.

## Arquitetura e responsabilidades

### Lógica do jogo

`Mesa_Logica` é um `Resource`: guarda jogadores, mãos, baralho, descarte, ordem/turno, fase, compra acumulada e escolhas pendentes. Não conhece RPCs nem interface.

`Mesa_Api` é um `RefCounted`: recebe os comandos, valida e coordena mudanças na mesa. Retorna um dicionário com sucesso ou erro/mensagem e uma lista ordenada de eventos. Comandos recusados não devem alterar o estado.

As classes `Carta_*` de `scripts/cartas` representam cartas lógicas, com ID, valor, cor e efeito. `Carta_Base.para_dados()` serializa esses dados. IDs de cartas identificam objetos; não usar posição no array como identidade.

`Efeitos_Api` é um contexto interno de efeitos, apesar do nome. As cartas chamam suas operações; ele altera a mesa e registra fatos. **Não é um endpoint de rede.**

`Baralho_Logico` centraliza composição, criação e reposição. A partida e o laboratório reutilizam esse comportamento. `Jogador_Logico` contém a mão lógica; `Descarte_Logico` contém o descarte. A lista circular em `scripts/logica/auxiliares` sustenta a ordem dos jogadores.

### Rede e barramento

`GameManager` é o autoload de `scenes/main/globais/game_manager.tscn`. Seus filhos persistentes são `EventBus`, `NetworkManager`, `MatchEndpoint` e `ChatEndpoint`; manter os caminhos iguais entre as instâncias para os RPCs.

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

As cinco cores visuais são centralizadas em `Carta.MAP_CORES`, em `scripts/main/componentes/carta.gd`:

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

### Laboratório oblíquo em 2D

Executar `scenes/desenvolvimento/laboratorios/laboratorio_obliquo.tscn` diretamente com F6. É uma composição visual com dados fictícios, sem partida ou rede. O experimento anterior de câmera/luz foi removido; esta versão mantém o projeto em 2D e prioriza separar o plano de jogo das mãos.

O fundo de feltro, o monte e três cartas no descarte são desenhados juntos em um SubViewport. O shader local `plano_obliquo.gdshader` projeta esse conteúdo num trapézio: borda distante mais estreita, borda próxima mais larga. Assim, monte e descarte seguem a mesma perspectiva da mesa. A faixa frontal escura sugere espessura. Não há câmera móvel nem iluminação adicional.

As quatro mãos reutilizam `MaoVisual` e `Carta`, mas ficam fora da projeção da mesa. A inferior é maior e sobrepõe a borda próxima, preservando o hover existente. A superior é menor; as laterais usam rotação e compressão. Adversários mostram os versos. As sombras de contato ficam ocultas nas cartas das mãos por `Carta.definir_sombra_visivel()`; a aparência das outras cenas continua com o padrão anterior.

Ajustar no Inspector da raiz, antes de executar: área da mesa, largura da borda distante, espessura frontal, centros do monte/descarte no plano e posição/escala das mãos. A referência é 1280×720, com escala uniforme e centralização em outras dimensões. Primeiro avaliar se a mão inferior parece segurada diante da mesa, se monte/descarte parecem apoiados e se a mão superior parece distante. A execução e a aprovação visual desta versão ficam com o usuário.

### Laboratório de uma mão ajustável

Executar `scenes/desenvolvimento/laboratorios/laboratorio_mao.tscn` com F6. A cena mostra sete cartas em um fundo escuro, sem mesa, partida ou rede. O painel fica na própria cena, com rolagem para alcançar todos os controles. O laboratório oblíquo permanece disponível para conferir depois a composição completa.

Os ajustes ao vivo incluem posição, tamanho, compressão vertical, giro e deformação do conjunto; largura, separação, curvatura e abertura do leque; variação de tamanho entre as pontas; e inclinação nos dois eixos do shader existente. Frente/verso e sombra podem ser comparados separadamente. Com o painel visível, as cartas não recebem hover e a mão pode ser arrastada. Ocultar o painel com **Tab** habilita o hover existente, inclusive nos versos apenas neste laboratório, e suspende o arraste. Mostrar o painel encerra o hover e restaura a escala e a inclinação-base ajustadas. A virada suspende o hover até a reaplicação dos ajustes.

Arrastar na área escura move a mão. A roda do mouse apenas rola o painel, inclusive sobre sliders e campos numéricos, sem alterar valores ou o tamanho da mão. **Tab** mostra ou oculta o painel, ignorando repetição automática. A posição é relativa à área de visualização disponível, inclusive quando o painel é ocultado. Durante a virada, os ajustes de geometria aguardam sua conclusão e os comandos de salvar/carregar/restaurar ficam temporariamente indisponíveis.

Nomear o teste, escrever observações e usar **Salvar teste** guarda a combinação em `user://laboratorio_mao.json`, na pasta de dados do usuário do Godot. Salvar novamente com o mesmo nome atualiza a combinação. **Carregar teste selecionado** restaura os ajustes, faces, sombras e anotações; **Copiar valores e anotações** coloca o perfil em JSON na área de transferência para compartilhar. **Restaurar ajustes iniciais** preserva os testes salvos.

O componente compartilhado `Carta` recebe uma `inclinacao_base` opcional, zero por padrão, composta com a inclinação dinâmica do hover e preservada durante a virada. `MaoVisual.configurar_leque()` permite reposicionamento imediato no laboratório; o comportamento animado segue como padrão nas demais cenas. A execução e a aprovação visual ficam com o usuário; não lançar o jogo nem produzir capturas automaticamente para essas iterações.

O controle **Deformação gradual por carta** alterna entre a deformação atual do conjunto inteiro e a deformação local com sinais opostos: com valor +25°, a primeira carta recebe −25°, o centro fica em zero e a última recebe +25°, com transição linear. Escolher −25° inverte os lados. Essa opção acompanha os testes salvos e copiados; testes antigos usam o modo de conjunto inteiro. A abertura do leque aceita valores de −35° a +35°.

As inclinações cima/baixo e esquerda/direita possuem opções graduais independentes. Ao ativar um eixo, seu controle uniforme dá lugar aos valores da **primeira** e da **última** carta, de −85° a +85°; as intermediárias usam uma transição linear. As pontas podem ter o mesmo sinal ou valores iguais, sem obrigar o centro a passar por zero. Primeira/última seguem a ordem das cartas no leque, não cima/baixo na tela quando a mão está girada. Testes e composições antigos preservam sua aparência: o valor gradual anterior é convertido em primeira = −valor e última = +valor durante o carregamento. Os extremos são salvos e copiados com o perfil nos dois laboratórios. Restaurar os ajustes iniciais desliga os modos graduais.

Nos laboratórios, as inclinações uniformes e os extremos graduais aceitam até ±85°. `Carta.limite_inclinacao_total` mantém 55° por padrão nas demais cenas; o laboratório usa 89° para a soma da base com o hover, evitando atravessar 90°, quando a face fica de perfil. Perto desse ângulo, a carta fica muito estreita por causa da perspectiva.

### Laboratório de quatro mãos

Executar `scenes/desenvolvimento/laboratorios/laboratorio_quatro_maos.tscn` com F6. É uma cena separada que herda o laboratório individual e reutiliza seu painel, cartas, shaders e controles. Mostra quatro mãos no mesmo fundo escuro, sem mesa ou partida. O laboratório de uma mão continua disponível.

O seletor **Editar mão inferior/superior/esquerda/direita** determina quais cartas recebem os ajustes e o arraste. Cada mão guarda seus próprios parâmetros, frentes/versos, sombras, modos graduais e observações. A roda somente rola o painel. **Tab** oculta os controles e ativa o hover nas quatro mãos, inclusive nos versos; mostrar o painel encerra o hover. Viradas bloqueiam a seleção e os comandos de carregamento até o término.

**Aplicar teste à mão selecionada** lê os testes de `user://laboratorio_mao.json` e aplica o perfil escolhido somente à mão atual. O arquivo individual é apenas lido nesta cena. **Salvar composição inteira** usa o nome informado e grava as quatro mãos e as observações do conjunto em `user://laboratorio_quatro_maos.json`. **Carregar composição selecionada** restaura tudo; **Copiar composição e anotações** permite compartilhar o conjunto em JSON. Salvar com o mesmo nome atualiza a composição. Restaurar uma mão ou as quatro preserva os arquivos salvos.

As posições são percentuais da área disponível; ocultar o painel amplia essa área, mantendo a distribuição relativa. Os valores iniciais são apenas uma composição de partida: inferior maior, superior menor e laterais rotacionadas. Aplicar os testes individuais e ajustar o tamanho relativo é parte da comparação. Conferir visualmente seleção/arraste independente, frente/verso, hover com Tab e salvar/carregar o conjunto. A execução visual fica com o usuário; não lançar o jogo nem produzir capturas automaticamente.

### Mão visual reutilizável

`scenes/main/componentes/mao.tscn` é a única cena pública da mão. Os laboratórios individual e de quatro mãos instanciam essa cena diretamente, sem um Node2D externo para aplicar a perspectiva. O grupo de deformação e o contêiner das cartas ficam dentro da mão. Posição na composição pertence à cena que a utiliza; leque, escala, compressão, giro, deformação, inclinações por eixo/extremidade e variação de tamanho pertencem ao componente.

No Inspector, habilitar **Perspectiva habilitada** para usar esses parâmetros. Por código, `configurar_visual(ajustes, opcoes, animar)` recebe os perfis existentes dos laboratórios. A raiz representa o centro da mão nesse modo. O modo padrão permanece sem perspectiva adicional para as cenas atuais da partida. O painel dos laboratórios agora apenas envia as configurações ao componente, preservando o formato dos arquivos de testes e composições.

Usar `receber_carta()`, `remover_carta()`, `obter_cartas()`, `obter_carta()`, `quantidade_cartas()` e `limpar()` em vez de depender dos filhos diretos da raiz. `receber_carta_do_monte()` continua disponível. A mão reorganiza automaticamente as cartas após entrada/saída, calculando o estado completo conforme a quantidade: mão vazia não gera posições; carta única usa o meio das inclinações e tamanho sem variação; outras quantidades distribuem os parâmetros entre as extremidades. `Carta.aplicar_estado_visual()` anima posição, rotação, escala, inclinação e deformação com um tween interrompível, enquanto a virada mantém o controle exclusivo da escala quando ativa. O hover fica suspenso durante essa reorganização.

A encapsulação da mão também é usada pelo laboratório de movimento descrito abaixo. Para validar a geometria separadamente, carregar os presets nos laboratórios individual/de quatro mãos, comparar giro/compressão/deformação e testar Tab, hover e alternância de faces. A transferência para o plano projetado da mesa ainda fica para outro experimento. Não executar o jogo ou produzir capturas automaticamente.

### Laboratório de movimento das mãos

As cartas iniciais e as compras usam uma instância independente de `Baralho_Logico`, na composição completa e embaralhada do jogo: números 0–9 nas quatro cores, +2, inverte, pula, troca-cor, +4 e troca-mão. O laboratório usa apenas a geração e os dados das cartas; não executa seus efeitos ou regras. R prepara outro baralho completo embaralhado, e a reposição automática permite continuar comprando quando ele acaba. A escolha é aleatória: cada mão pode receber qualquer cor/tipo, sem garantir um curinga em cada compra.

Executar `scenes/desenvolvimento/laboratorios/laboratorio_movimento_maos.tscn` diretamente com F6. A cena herda o laboratório de quatro mãos, incluindo painel, ajustes, testes individuais e composições salvas. Começa com sete cartas por mão; carregar uma composição aplica os parâmetros às cartas presentes. Monte e descarte ficam no centro do fundo escuro, sem mesa projetada ou regras de partida. A cena principal do projeto permanece a mesma.

- **D / Comprar uma por mão:** cria uma carta fictícia no monte e a leva até o último lugar de cada mão. As cartas anteriores se reorganizam para abrir espaço.
- **J / Jogar uma por mão:** retira a primeira, a do meio ou a última, conforme o seletor do painel. As restantes se reorganizam; a carta viaja até o descarte, revela sua frente e retorna à inclinação/deformação zero.
- **R / Esvaziar mãos e descarte:** cancela movimentos em andamento e limpa as cartas, preservando os ajustes e arquivos salvos. Repetir D permite comparar zero, uma, sete e mais cartas.
- **Tab:** mantém a comparação painel/hover nas quatro mãos, inclusive nos versos. D/J/R funcionam com o painel oculto, ignorando repetição automática e campos de texto em edição.

A transferência mantém o fluxo original: comprar chama `MaoVisual.receber_carta_do_monte()`, a carta vira filha do contêiner da mão imediatamente, e a mão reorganiza todas as filhas conforme a quantidade real. Jogar chama `DescarteVisual.receber_carta()`, que recebe a carta imediatamente; a saída continua disparando a reorganização automática da mão. O laboratório envia os comandos e preserva os dados para revelar as cartas após a limpeza do verso, sem controlar trajetos ou manter uma ordem lógica paralela à árvore.

No modo de perspectiva, `Carta.reparentar_preservando_visual()` captura a transformação da aparência antes da troca de pai. Após o reparent, aplica a matriz inversa da nova transformação numa compensação visual interna e permanente da cena da carta. Assim, a aparência começa exatamente onde estava. `Carta.aplicar_estado_visual()` anima posição, giro, escala, inclinação e deformação; a compensação retorna à identidade no mesmo tween. Novas reorganizações interrompem o tween anterior e partem dos valores atuais, incluindo a compensação restante. Não há portadores temporários nem reparent na chegada.

No modo 2.5D, a virada anima um visual interno separado, em vez de zerar a escala da raiz da carta. Isso permite virar, reorganizar e fazer reparent simultaneamente, sem interferência entre tweens ou inversão de uma matriz singular. A virada tradicional continua como padrão nas cenas sem perspectiva. O descarte tem configuração opcional de perspectiva e duração; nesse modo usa a mesma animação da carta, com escala 1,5 e inclinação/deformação zero como destino.

Comprar/jogar aceitam comandos sobrepostos, pelos botões ou D/J, sem esperar os movimentos terminarem e sem enfileirar comandos. Primeira/meio/última usam as filhas reais da mão, incluindo cartas que já pertencem a ela mas ainda estão se aproximando visualmente. Cada entrada/saída atualiza o leque; compras rápidas podem prolongar reorganizações interrompidas. A ordem do descarte é a ordem do reparent no início, mesmo com animações terminando fora de ordem.

Hover, arraste e edição dos parâmetros ficam suspensos enquanto as cartas animam; os botões de movimento e o seletor primeira/meio/última continuam disponíveis. O laboratório apenas consulta `Carta.em_animacao_visual()` para liberar essa edição, sem orquestrar a animação. R remove as filhas atuais das mãos/descarte e seus tweens são descartados junto com as cartas. No Inspector da raiz, **Duração transferência** ajusta o tempo das reorganizações e do descarte (mínimo 0,8 segundo). As contagens vêm dos filhos atuais; o painel mostra também quantas cartas estão animando. Salvar composição continua gravando somente parâmetros/anotações, sem persistir a distribuição das cartas.

Validação visual pelo usuário: carregar sua composição, apertar D várias vezes rapidamente e alternar D/J antes das chegadas, comparando primeira/meio/última. Após R, comprar e imediatamente jogar a única carta ainda em trânsito. Conferir as contagens, ausência de cartas duplicadas/perdidas, continuidade nas mãos laterais, reorganização gradual, frente restaurada no descarte, hover após terminar o trânsito, Tab/redimensionamento durante o trajeto e R com várias transferências simultâneas. Também repetir D até superar sete cartas. Godot e jogo não foram executados automaticamente.

### Laboratório da mesa ajustável

Executar `scenes/desenvolvimento/laboratorios/laboratorio_mesa.tscn` diretamente com F6. É um laboratório separado, em fundo escuro, para ajustar a perspectiva da mesa sem mãos ou partida. O tampo é verde liso, a moldura é marrom escura e uma faixa frontal mais escura sugere espessura. Não há textura de madeira, decoração ou iluminação adicional. O estado anterior das mãos/movimentos foi registrado no commit `a826105` antes desta implementação; a cena inicial do projeto não foi alterada para abrir este laboratório.

O painel oferece posição horizontal/vertical, largura da borda próxima, profundidade aparente na tela, largura da borda distante em porcentagem da próxima, giro do conjunto, largura da moldura e espessura frontal. Largura distante de 100% gera um retângulo; reduzir estreita o lado distante. Profundidade controla separadamente a compressão vertical da superfície. São parâmetros geométricos de uma projeção 2D; o giro roda o conjunto no plano da tela, sem simular uma câmera 3D. As posições podem passar um pouco dos limites do enquadramento (-25% a 125%) para testar cortes.

**Mostrar grade** habilita quadrados de 100×100 unidades no plano original. **Mostrar duas cartas apoiadas** exibe cartas do componente atual com a mesma escala, uma próxima e outra distante, sem hover ou sombras. Ambas são referências visuais fixas, sem compra/descarte. Superfície, moldura, grade e cartas são desenhadas no mesmo SubViewport e recebem a mesma projeção; a moldura conserva sua largura no plano original e reduz pela perspectiva. A faixa frontal segue o giro do conjunto e tem espessura ajustada separadamente.

Arrastar na área escura com o painel visível move a mesa. **Tab** mostra/oculta o painel e suspende o arraste quando oculto, ignorando repetição automática. A roda do mouse apenas rola o painel, inclusive sobre sliders e campos numéricos. O enquadramento usa uma referência de 1280×720, uniformemente escalada e centralizada na área disponível; Tab e redimensionamento preservam os parâmetros e proporções da composição, ajustando apenas essa escala de apresentação.

Nomear o teste, escrever observações e usar **Salvar teste** grava `user://laboratorio_mesa.json`, independente dos arquivos das mãos. Salvar com o mesmo nome atualiza o perfil. **Carregar teste selecionado** restaura geometria, grade, referências e anotações; **Copiar valores e anotações** copia o perfil em JSON. **Restaurar ajustes iniciais** preserva o arquivo de testes salvos. Não há gravação automática ao iniciar a cena.

`scenes/main/componentes/mesa_visual.tscn` encapsula a mesa num único nó `MesaVisual`, com parâmetros no Inspector e `configurar_visual(ajustes, grade, cartas)` para o laboratório. `mesa_perspectiva.gdshader` reutiliza a fórmula do experimento oblíquo, com faixa de 15% a 100%; o shader antigo e aquele laboratório continuam iguais. `superficie_mesa.gdshader` desenha apenas cores e grade. Os materiais são locais a cada instância. Esta etapa não integra as mãos nem transferências para o plano projetado.

Validação visual pelo usuário: experimentar 100%, 56% e 15% de largura distante; variar profundidade; comparar moldura/espessura em zero e nos extremos; mostrar/ocultar grade e cartas; testar giro, arraste e Tab; salvar uma combinação, restaurar e carregar de novo. Comparar a composição em 1280×720 e 1920×1080. As verificações automáticas são estáticas e matemáticas; não executar o Godot nem gerar capturas automaticamente.

### Verificações gerais

- A janela de referência é 1280×720, com stretch `canvas_items`/aspect `expand`; também foram consideradas telas de 1920×1080.
- Para revisar a mesa real sem rede, usar `scenes/desenvolvimento/previas/previa_mesa_partida.tscn`. Para interações completas, executar o projeto pelo menu ou `partida_rede.tscn` em instâncias separadas.
- O laboratório `teste.tscn` tem fundo cinza e áreas ciano das mãos. Isso é próprio daquela cena, não a aparência final da mesa.
- O usuário já validou manualmente lógica básica, multiplayer, cartas especiais, distribuição e troca de mãos em etapas anteriores. Esse histórico não equivale a uma verificação de toda alteração futura.
- Neste ambiente, tentativas de lançar o Godot diretamente por terminal para capturas chegaram a falhar com `signal 11`, inclusive em compatibilidade/headless. A causa não foi diagnosticada; não atribuir automaticamente o crash ao código do jogo nem alterar permanentemente o renderer para contornar.
- As últimas comparações de paleta foram imagens compostas a partir dos assets, com hexadecimais exatos e aproximação do fundo. Não eram screenshots do Godot. As prévias e arquivos temporários foram removidos do repositório.
- Em alterações visuais, revisar a composição nas cenas reais e preservar o teste original. Em alterações de regra/rede, revisar eventos, destinatários, ordem e tratamento do anfitrião.

Este arquivo é um ponto de entrada. Antes de editar, ler o código do componente envolvido e confirmar o pedido atual do usuário; evitar reconstruir funcionalidades que já existem.
