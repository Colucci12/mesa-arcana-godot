# JUNO — contexto para continuar o projeto

Atualizado em 02/10/2026. Este documento orienta a navegação no código e registra as decisões do projeto. O usuário tem seu próprio planejamento de próximas entregas; alinhar o pedido atual com ele antes de ampliar o escopo.

## Projeto e forma de trabalhar

- Jogo de cartas em Godot 4.6.2, GDScript, com anfitrião participante e partidas de 2 a 4 jogadores por ENet/IP.
- Nome atual: **JUNO**. Há nomes e artes herdados da fase inicial de UNO; não renomear tudo automaticamente.
- Código em português, simples, bem escrito e com comentários apenas quando explicam algo necessário. Preservar os nomes existentes em inglês sem fazer uma reorganização geral.
- **Scripts ficam em `scripts`; cenas ficam em `scenes`. Nunca misturar.** Cenas usadas no jogo ficam em `scenes/main`, separadas em `telas`, `componentes` e `globais`; seus scripts e shaders acompanham essa divisão em `scripts/main`. Prévias, laboratórios e testes ficam em `desenvolvimento`, com subpastas próprias dentro de `scenes` e `scripts`.
- A organização atual satisfaz o usuário. Evitar novas camadas, pastas e refatorações amplas sem necessidade concreta.
- Preservar encapsulamento e coesão: operações internas de um componente podem ser chamadas diretamente; sinais são usados para comunicação entre componentes quando fazem sentido. Não transformar cada operação em um sinal.
- Quando o usuário pede discussão ou planejamento, discutir antes de implementar. Evoluir o visual em entregas pequenas e apresentar para avaliação.
- O usuário executa as cenas e valida o visual no editor. Não abrir o jogo para gerar capturas por iniciativa própria; nesta etapa, a comparação visual fica com ele.
- O repositório é local. Fazer commits quando solicitado. `export_presets.cfg` é uma configuração legítima de exportação criada pelo usuário, mantida localmente e ignorada pelo Git; não excluir nem passar a versionar sem pedido.
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

- `scenes/main/telas/menu_principal.tscn`: entrada do jogo, com título JUNO, Jogar e Sair. Nesta branch, a cena inicial selecionada pelo usuário é o laboratório de transferências 2.5D.
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

### Quais laboratórios continuam úteis

- **Composição atual:** `laboratorio_maos_erguidas.tscn` — mesa compartilhada, adversários erguidos, inferior em primeiro plano, hover e fonte ajustável de sombras. É o ponto de partida desta branch.
- **Transferências na composição atual:** `laboratorio_transferencias_2_5d.tscn` — deriva da referência visual, acrescenta monte/descarte e comandos individuais de compra/jogada, com apresentação e sombra próprias durante o trajeto.
- **Referência fixa:** `laboratorio_maos_no_plano.tscn` — mãos apoiadas com a projeção da mesa. Também é a cena e o script-base do laboratório atual; não remover enquanto existir essa herança.
- **Mesa isolada:** `laboratorio_mesa.tscn` — ajusta a geometria de `MesaVisual` sem interferência das mãos.
- **Movimentos:** `laboratorio_movimento_maos.tscn` — compra, descarte, reorganização e comandos sobrepostos. Ainda não usa a projeção compartilhada nem as sombras novas; serve de referência para integrar essas transferências depois.
- **Base dos movimentos:** `laboratorio_quatro_maos.tscn` e `laboratorio_mao.tscn` — editores dos componentes, importação dos testes antigos e dependências transitivas do laboratório de movimentos. Mantidos por essa função, não como direção visual principal.
- **Teste original:** `teste.tscn` — laboratório original do usuário, preservado junto das prévias e testes de lógica/rede.

As cenas ficam em `scenes/desenvolvimento/laboratorios`; os scripts e shaders locais, em `scripts/desenvolvimento/laboratorios`. A cadeia antiga é movimento → quatro mãos → uma mão; a atual é mãos erguidas → referência fixa → `MesaVisual`/`MaoVisual`/`Carta`.

Foram removidos `laboratorio_obliquo` e seu shader duplicado `plano_obliquo`, substituídos pela mesa reutilizável e pela composição atual, e `laboratorio_mesa_maos`, que mantinha mesa e adversários em projeções independentes. Arquivos temporários de cena também foram removidos. Não remover shaders compartilhados de iluminação: monte, descarte e mesa real ainda os utilizam.

Os conjuntos e as anotações permanecem em `user://`, fora do repositório; a limpeza não apaga esses arquivos. Eles não acompanham um clone do Git. Os presets antigos continuam acessíveis pelos laboratórios de uma/quatro mãos e movimento. O novo laboratório grava seu próprio arquivo, sem sobrescrever os anteriores.

### Laboratório de uma mão ajustável

Executar `scenes/desenvolvimento/laboratorios/laboratorio_mao.tscn` com F6. A cena mostra sete cartas em um fundo escuro, sem mesa, partida ou rede. O painel fica na própria cena, com rolagem para alcançar todos os controles. A composição completa com mesa é avaliada no laboratório de mãos erguidas.

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

Usar `receber_carta()`, `remover_carta()`, `obter_cartas()`, `obter_carta()`, `quantidade_cartas()` e `limpar()` em vez de depender dos filhos diretos da raiz. `receber_carta_do_monte()` continua disponível. A mão reorganiza automaticamente as cartas após entrada/saída, calculando o estado completo conforme a quantidade: mão vazia não gera posições; carta única usa o meio das inclinações e tamanho sem variação; outras quantidades distribuem os parâmetros entre as extremidades. `Carta.aplicar_estado_visual()` anima posição, rotação, escala, inclinação e deformação com um tween interrompível, enquanto a virada mantém o controle exclusivo da escala quando ativa. O hover permanece disponível durante a reorganização: a ampliação usa um `HoverVisual` interno, independente do tween de posição/escala-base do leque. A inclinação dinâmica também permanece separada da base. Transferência e virada suspendem somente o hover da carta envolvida. `mao_adversaria` desabilita o hover das cartas dessa mão.

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

`scenes/main/componentes/mesa_visual.tscn` encapsula a mesa num único nó `MesaVisual`, com parâmetros no Inspector e `configurar_visual(ajustes, grade, cartas)` para o laboratório. `mesa_perspectiva.gdshader` projeta o plano no trapézio, com largura distante de 15% a 100%. `superficie_mesa.gdshader` desenha apenas cores e grade. Os materiais são locais a cada instância. Esta etapa não integra as mãos nem transferências para o plano projetado.

Validação visual pelo usuário: experimentar 100%, 56% e 15% de largura distante; variar profundidade; comparar moldura/espessura em zero e nos extremos; mostrar/ocultar grade e cartas; testar giro, arraste e Tab; salvar uma combinação, restaurar e carregar de novo. Comparar a composição em 1280×720 e 1920×1080. As verificações automáticas são estáticas e matemáticas; não executar o Godot nem gerar capturas automaticamente.

### Comparação fixa: mãos no plano da mesa

Executar `scenes/desenvolvimento/laboratorios/laboratorio_maos_no_plano.tscn` com F6. É uma comparação rápida e independente, sem painel, edição ou persistência. Usa a geometria de **Teste 1** da mesa como valores fixos (largura 1600, profundidade 400, borda distante 50%, moldura 30, espessura 100) e quatro mãos de sete cartas, inferior aberta e adversárias de costas. Não carrega nenhum preset das mãos.

As mãos reutilizam o leque original de `MaoVisual`, com perspectiva individual desabilitada, mesma escala nas quatro, inclinações/deformação-base zeradas e apenas posição/orientação conforme cada assento. São adicionadas dentro de `Mesa/PlanoViewport/Conteudo`, junto do tampo: recebem integralmente o shader de projeção da mesa, incluindo compressão e redução por distância. As referências centrais ficam ocultas. Isso testa todas as mãos no mesmo plano do tampo, inclusive a inferior, para comparar com o laboratório em que ficam fora da projeção. Os componentes compartilhados e demais cenas não foram alterados; a execução visual fica com o usuário.

Sombras originais e hover estão ativos nas quatro mãos, inclusive nos versos apenas neste laboratório. O laboratório converte a posição do cursor pela mesma fórmula do shader da mesa e encaminha movimento ao SubViewport em coordenadas lógicas, preservando os sinais e efeitos originais de `Carta`: escala, inclinação dinâmica e ordem de desenho. Sair do tampo/da janela ou perder o foco encerra o hover. A projeção é atualizada a cada quadro para acompanhar redimensionamento e a escala do próprio hover; o conteúdo interno das cartas continua sem entrada de mouse. A habilitação de entrada ocorre apenas na instância da mesa deste laboratório. Validar passando por cartas sobrepostas nas quatro mãos, saindo rapidamente do tampo e voltando, redimensionando a janela e alternando o foco. Godot e jogo não são executados automaticamente.

A largura da mesa neste teste aumenta o **espaço do plano original**, sem ampliar horizontalmente tudo que ele contém. O laboratório ajusta a largura lógica do SubViewport à largura próxima do tampo (1600), mantendo a profundidade lógica original (700) e a resolução de renderização existente. O tamanho de cada mão/carta permanece em unidades desse plano, com escala uniforme; seus centros são relativos ao plano maior. A superfície recebe as mesmas dimensões para a moldura conservar sua largura em unidades. Isso remove a ampliação horizontal de 1,6× que ocorria ao exibir o plano fixo de largura 1000 numa mesa de largura 1600. A compressão e a redução por distância da projeção oblíqua continuam presentes. O mapeamento do hover usa as novas dimensões automaticamente. Essa mudança é local ao laboratório fixo; os presets e componentes compartilhados permanecem iguais. Para validar, comparar principalmente a proporção das cartas inferiores e o espaço livre entre as mãos, além do hover nas laterais após a correção.

### Laboratório reduzido de mãos erguidas

Executar `scenes/desenvolvimento/laboratorios/laboratorio_maos_erguidas.tscn` com F6. É uma cena derivada do teste fixo, com a mesma mesa larga e quatro mãos de sete cartas. As adversárias começam na referência, com inclinação/altura zero; a inferior começa no modo de primeiro plano descrito abaixo. Não importa automaticamente os presets antigos. A cena fixa permanece disponível; `project.godot` mantém o laboratório de mãos erguidas como cena inicial, conforme a seleção do usuário.

O painel seleciona uma mão e mantém seis controles básicos no topo. No modo mesa: posição horizontal/vertical no espaço da mesa, tamanho uniforme, giro no plano, inclinação do conjunto e altura do apoio. **Erguer a mão** gira o plano inteiro em torno de uma linha próxima à base das cartas; valores positivos levantam a parte superior. **Altura do apoio** eleva esse plano como um todo. Na inferior livre, esses controles passam a editar seu perfil de primeiro plano.

**Avançados** fica recolhido por padrão, com botão e fundo vermelhos. Reaproveita `MaoVisual.configurar_visual()` para altura/compressão das cartas, largura/separação/curvatura/abertura do leque, deformação uniforme/gradual, variação de tamanho, inclinações dos shaders uniformes/graduais com primeira/última independentes, frente/verso e sombras. Tamanho e giro continuam exclusivamente nos básicos, sem controles duplicados. Os padrões avançados reproduzem a referência atual (largura 360, separação -10, curvatura -15, abertura 5, compressão 1, demais valores geométricos zero), em vez de importar os defaults/presets do laboratório antigo. A compensação da origem centrada mantém o leque no mesmo lugar ao habilitar a configuração 2.5D.

Cada controle avançado mostra **Padrão** ou **Alterado**, sempre com o valor padrão; alterações ficam em amarelo. O cabeçalho mostra a contagem e um resumo abaixo lista as chaves modificadas mesmo com a seção recolhida. Os indicadores são próprios da mão selecionada e voltam ao estado padrão quando seu valor é restaurado. **Restaurar só os avançados** mantém todos os básicos. **Copiar alterações avançadas** copia, para cada uma das quatro mãos, apenas as chaves alteradas com padrão/valor e as observações. Os gradientes conservam a lógica de primeira/última do componente existente; os dois campos aparecem ao ativar cada eixo gradual. Frente/verso preserva os dados fictícios para revelar novamente, com o controle de faces aguardando a conclusão da virada.

A perspectiva usa uma câmera matemática comum à mesa e às mãos, sem nós 3D. Para altura/inclinação zero, a projeção das mãos reproduz a homografia do tampo. Inclinar ou elevar modifica as coordenadas de um plano inteiro, projetadas pela mesma câmera; não equivale a apenas deslocar a imagem na tela. As quatro mãos são desenhadas em regiões de **um único SubViewport**, inicialmente 1200×720, compartilhado por quatro polígonos com materiais próprios. Quando geometria avançada exige mais espaço, a captura se expande conforme os limites dos quads das cartas, com margem para hover, evitando cortes e vazamento entre regiões. Restaurar todos os avançados retorna à resolução inicial. `plano_mao_perspectiva.gdshader` aplica a homografia de cada plano sem a costura diagonal de uma interpolação afim. As matrizes/captura são recalculadas apenas ao editar/carregar/restaurar/comparar; o hover usa a inversa dessa mesma transformação para encaminhar o cursor à carta original no atlas. Margens transparentes de um plano não bloqueiam outra mão. Em posições extremas, um plano que fica de perfil ou atravessa a câmera pode desaparecer; restaurar seus ajustes retorna à configuração inicial.

**Comparar mãos da mesa apoiadas** zera temporariamente inclinação e altura das mãos no espaço da mesa, preservando os valores escolhidos e os outros ajustes. **Restaurar mão selecionada** e **Restaurar referência completa** retornam aos defaults sem apagar os testes. A restauração completa também religa primeiro plano e sombras no tampo. **Tab** mostra/oculta o painel; a escala de apresentação se ajusta uniformemente ao espaço disponível. Hover permanece ativo nas quatro mãos, inclusive nos versos; as sombras seguem a comparação descrita abaixo. A roda apenas rola o painel, mesmo sobre barras/campos numéricos. Não há arraste, distribuição de cartas ou integração com partida.

Nome, observações e **Salvar conjunto** gravam as quatro mãos em `user://laboratorio_maos_erguidas.json`, incluindo básicos, avançados e um registro separado das alterações avançadas. Carregar restaura os ajustes de cada uma e as notas; testes salvos antes dos avançados recebem os padrões novos sem perder os básicos. A comparação temporária é desligada ao carregar e não modifica os valores salvos. Salvar com o mesmo nome atualiza o conjunto. Esse arquivo é independente de todos os testes anteriores e não há gravação automática.

Validar primeiro com Tab e valores iniciais, comparando a geometria com a cena fixa ao desligar os dois modos novos descritos abaixo. Comparar apoiadas/erguidas, testar hover e saída rápida nas quatro mãos, giro/tamanho, Tab/redimensionamento e salvar/restaurar/carregar. As verificações automáticas são estáticas e matemáticas, sem executar Godot ou gerar capturas.

#### Primeiro plano e sombras no tampo

**Mão inferior em primeiro plano** começa ligado. A inferior usa uma câmera matemática frontal própria e não recebe a compressão, a redução por distância ou a orientação da mesa. Os básicos passam a ajustar posição na composição de 1280×720 (permitindo sair parcialmente da tela), tamanho de 0,6 a 3, giro, inclinação local e **Aproximar da câmera**, de 0 a 400. Começa frontal, tamanho 1,8, posição 50%/90% e proximidade zero. O hover e os avançados continuam disponíveis. Desligar o modo retorna ao perfil anterior sobre a mesa; os básicos dos dois modos ficam guardados separadamente. Os perfis antigos continuam carregando: preservam a inferior anterior no modo mesa e recebem os defaults do primeiro plano. A comparação **mãos da mesa apoiadas** não afeta a inferior livre.

**Sombras projetadas no tampo** também começa ligado. Reaproveita o alpha das cartas do atlas, sem outro SubViewport, para formar a silhueta da mão projetada sobre z=0. A sombra recebe a câmera da mesa, é recortada ao feltro, fica abaixo de todas as mãos e suaviza/perde intensidade conforme a altura do plano. A sombra original das cartas é ocultada nas mãos com projeção no tampo, evitando duplicação. Desligar a comparação restaura as sombras anteriores. **Mostrar sombras** continua sendo independente por mão. A inferior em primeiro plano conserva a sombra original entre cartas e não projeta sombra no tampo. Os parâmetros também ficam no Inspector da raiz, em **Sombras no tampo**.

**Fonte das sombras** permite ajustar uma fonte invisível em um ponto do espaço da mesa. **Fonte em ponto específico** começa ligado, com horizontal 50%, profundidade -20% e altura 700. Horizontal/profundidade são percentuais do plano original, com 0%/100% nas bordas, e aceitam posições externas à mesa; altura é em unidades do mundo, de 20 a 2000. Os raios partem da fonte, passam pelos pontos do plano da mão e interceptam o tampo: direção e tamanho variam conforme a posição relativa, com uma homografia própria da sombra. Desligar a fonte localizada compara com a direção fixa anterior. A fonte não adiciona claridade, halo ou marcador à cena. **Restaurar fonte** afeta somente a fonte. Sua posição e modo são salvos com o conjunto; presets antigos recebem os valores iniciais.

As sombras são desenhadas sobre o retângulo receptor da mesa e recortadas ao feltro, evitando quads gigantes ou desaparecimento de toda a sombra quando uma margem transparente da captura cruza a altura da fonte. Pontos do plano na altura da fonte ou acima dela não projetam sombra no tampo por essa fonte. Luz baixa pode produzir sombras muito longas, que saem do feltro; isso é esperado. Para comparar, usar uma adversária inclinada/erguida, variar horizontal entre 20% e 80%, profundidade entre -20% e 120% e altura entre 400 e 1000; depois conferir fonte baixa, modo direcional e salvar/carregar. São verificações matemáticas/estáticas; a execução visual fica com o usuário.

É uma aproximação visual por plano de mão: mudanças de forma no hover e nas viradas aparecem na silhueta do atlas, mas não há oclusão física, fonte luminosa real nem altura 3D individual por carta. As inclinações/deformações avançadas alteram a silhueta capturada, sem reconstruir volumes. Comparar uma adversária com altura 0/50/100 e inclinação 0/70/85; a sombra deve permanecer sobre o feltro. Testar também Tab, hover, viradas, carga dos testes 3/4 e troca entre os dois modos da inferior. O teste fixo e os componentes compartilhados permanecem iguais.

Salvar conjunto inclui os modos de primeiro plano/sombra e os dois perfis básicos da inferior no mesmo arquivo do laboratório, sem gravação automática. Opções graduais ativadas com valores neutros são tratadas como sem efeito; valores de eixos uniformes/extremos que estejam inativos não entram na contagem/cópia das alterações avançadas. Os valores originais dos campos permanecem disponíveis para edição e gravação.

### Laboratório de transferências na mesa projetada

Executar `scenes/desenvolvimento/laboratorios/laboratorio_transferencias_2_5d.tscn` com F6. Herda a cena e o script de mãos erguidas, preservando a referência visual e a cena inicial selecionada no projeto. Usa as mesmas mãos, mesa, opções de primeiro plano e fonte ajustável de sombras. Acrescenta `MonteVisual` e `DescarteVisual` apoiados no tampo. Começa com sete cartas por mão e três no descarte; os dados vêm do `Baralho_Logico` completo e embaralhado, incluindo cores, especiais e coringas, sem executar regras.

**Monte e descarte** no painel seleciona qual pilha editar: posição horizontal/profundidade, tamanho, giro sobre a mesa, espessura e intensidade/suavidade da sombra. A compra tem também **Camadas visíveis**, de 1 a 12, e **Desalinhamento**. Seu sprite antigo fica oculto somente neste laboratório: uma carta real de costas fornece a aparência do topo, e a mesma silhueta forma camadas claras em alturas distintas. Uma camada permite comparar com uma carta única apoiada. O padrão é oito camadas e altura total 12. No descarte, cada carta real tem seu próprio plano/captura, com espessura padrão 0,8 por carta, limitada a 32 unidades de altura acumulada. Seu desalinhamento é aleatório, com controles separados de **Variação em X**, **Variação em Y** e **Variação de rotação**, descritos abaixo. Cada pilha usa a câmera da mesa e a fonte de sombras existente; uma sombra do topo evita escurecimento progressivo ao acumular cartas. **Restaurar pilha selecionada** afeta apenas essa pilha; **Restaurar referência completa** inclui ambas. A edição das pilhas fica bloqueada durante os trajetos, como a geometria das mãos.

**Importar conjunto visual selecionado** lê `user://laboratorio_maos_erguidas.json` e aplica aparência/fonte sem gravar nesse arquivo. **Salvar conjunto** neste laboratório grava `user://laboratorio_transferencias_2_5d.json`, com os perfis, fonte, notas, duração/altura do trajeto, centros e ajustes separados das pilhas na chave `pilhas`. Conjuntos antigos recebem os padrões das pilhas e preservam os centros antigos. A distribuição e cartas em trânsito não são persistidas. **Carregar** aplica os parâmetros às cartas existentes. Na abertura, o laboratório importa o conjunto visual aprovado **teste 5**, quando encontrado, sem modificar os arquivos salvos. O nome pode ser alterado no Inspector em **Conjunto visual inicial**. Sem esse perfil, mantém os defaults.

- **D / Comprar:** compra uma carta para a mão selecionada no painel. Ela entra imediatamente no contêiner da mão, que reorganiza suas cartas.
- **J / Jogar:** joga a primeira, a do meio ou a última da mão selecionada; o descarte recebe a carta imediatamente, e a mão reorganiza as restantes. Funciona também com uma carta ainda chegando.
- **R / Esvaziar:** cancela as apresentações em trânsito, remove cartas das mãos/descarte e prepara outro baralho completo, sem alterar perfis, fonte ou testes salvos.
- **Tab:** mostra/oculta os controles. Compras e jogadas podem se sobrepor, sem fila ou espera global. Repetição automática e comandos durante edição de texto são ignorados.

Os donos e o fluxo original de reparent/reorganização continuam em `MaoVisual` e `DescarteVisual`. A carta original mantém seus tweens/virada; sua face nativa fica oculta e `plano_carta_laboratorio.gd` apresenta a mesma textura/material/virada numa pequena captura externa enquanto cruza os canvases. Não há uma segunda carta lógica nem reparent na chegada. A apresentação acompanha os sinais de início, progresso e conclusão do mesmo tween de `Carta.aplicar_estado_visual()`, sem relógio próprio no laboratório. Uma nova reorganização preserva o plano projetado atual e calcula o novo destino uma vez; o progresso do tween reiniciado conduz ambas as apresentações. Ao chegar à mão, a face nativa retorna e a captura é removida. Ao chegar ao descarte, a captura é reutilizada para apresentar a carta na sua altura individual, mantendo a ordem de entrada mesmo com chegadas fora de ordem. As conexões de transferência são removidas nos dois casos. Uma compra redirecionada ao descarte reutiliza sua apresentação e parte do plano corrente. Compra sai do topo atual; descarte recebe na altura da carta. Intensidade/suavidade da sombra também interpolam até os valores da pilha de destino no mesmo tween.

A orientação dos planos usa interpolação de quaternions, preservando tamanho/cisalhamento sem colapsar o quad ao girar 180°. O trajeto tem uma altura em arco, ajustável no Inspector junto da duração (0,8–2 s) e centros das pilhas. O arco começa na troca de dono; reorganizações durante a transferência retomam a altura atual sem adicionar outro arco. Para a inferior livre, a apresentação mistura progressivamente a projeção da mesa com a câmera frontal; a matriz frontal também é interpolada ao mudar o destino, preservando os quatro cantos no reinício. A posição no mundo usada para a sombra é uma aproximação virtual, pois essa mão não pertence à câmera da mesa. A sombra desaparece ao chegar à mão livre e reaparece ao sair dela. Adversárias usam planos da mesma câmera da mesa.

Cada carta em trânsito tem sua própria sombra, calculada com o ponto/altura/orientação atuais e a fonte selecionada. As mãos mantêm a sombra coletiva; as pilhas usam sombras baixas de conjunto. Durante os trajetos, o hover das cartas que continuam na mão inferior permanece ativo, inclusive enquanto o leque se reorganiza. A carta em transferência/virada não recebe hover; mãos adversárias também não recebem, mesmo quando reveladas para comparação. A edição de geometria/arquivos fica suspensa; seleção de mão, comandos e fonte continuam disponíveis. A roda continua apenas rolando o painel. Os dados para restaurar frentes são guardados por instância, não pelo índice no leque, preservando especiais/coringas após remoções e viradas.

**Sombras sobre as cartas das pilhas** habilita a recepção de sombras no painel e no Inspector. Cartas em trânsito e cartas pousadas do descarte usam a mesma rotina para projetar sobre todas as cartas visíveis abaixo delas e sobre o topo da compra, quando há sobreposição. A mesma fonte calcula a interseção do raio na altura da carta receptora, em vez de sempre usar o tampo. `sombra_entre_cartas.gdshader` recorta a sombra pelo alpha da face receptora e da origem; suavidade e atenuação consideram a distância entre os planos. A sombra sobre a mesa continua nas regiões expostas. Intensidade/suavidade usam os ajustes existentes de pilha ou os valores interpolados da transferência. As faces superiores cobrem as sombras inferiores pela ordem de desenho. Esta etapa usa receptores horizontais das pilhas; as mãos continuam com sua sombra coletiva.

Os polígonos de sombra recebida são filhos da apresentação receptora, reutilizados por origem e liberados quando deixam de se sobrepor, ao desligar a opção ou ao remover a captura. Somente o topo atual da compra recebe sombras; mudar as camadas limpa o antigo receptor. Nenhuma captura ou animação extra é criada. `sombras_entre_cartas` acompanha Salvar conjunto, ativado por padrão nos conjuntos antigos. A validação headless passou em 123 verificações de raios com fonte localizada/direcional, receptor elevado, máscaras/ordem, ausência de sombras de cartas abaixo, comparação, perfis, troca de topo, transferências sobrepostas, limite visível e R. O renderer headless não desenha as capturas; a aparência final ainda precisa da avaliação do usuário. Os avisos já existentes de certificados, anchors e compilador do shader antigo de sombra coletiva permaneceram.

Na avaliação seguinte, o usuário relatou que a sombra do descarte desaparecia ao terminar o movimento. As faces pousadas e os polígonos de sombra recebida compartilhavam o mesmo Z; passaram a usar ordens explícitas intercaladas: face da camada, sombra recebida, face seguinte. A compra fica abaixo do descarte, as mãos acima das pilhas e as transferências acima das mãos. A captura da carta que chega é preservada, incluindo sua silhueta e altura; o assentamento recalcula as ordens sem depender da posição dos nós na árvore. Esse ajuste de ordem não resolveu o corte observado: o trajeto sombreava todos os receptores, mas o pouso limitava a projeção à carta imediatamente inferior e removia as sombras sobre as demais. Agora `_projetar_sombra_nas_pilhas()` aplica os mesmos receptores antes e depois da chegada. A sombra sobre uma carta não adjacente conserva o mesmo polígono, material, geometria, intensidade e suavidade no pouso; continua recalculada com a luz e o assentamento, sem congelar um quadro da animação. A confirmação visual desse último ajuste fica com o usuário.

A mão inferior perdia nitidez ao trocar a captura individual da transferência pela célula do atlas compartilhado, renderizada com um pixel por unidade. Somente neste laboratório, a inferior agora usa `CapturaMaoInferior`, com dois pixels por unidade e dimensões lógicas iguais às anteriores. As outras três mãos continuam no atlas; a arte interna da carta não foi alterada. O polígono e a sombra coletiva da inferior usam a textura inteira dessa captura; o mouse é encaminhado ao mesmo viewport, conservando as coordenadas lógicas, o hover e a geometria das transferências. Ajustar o leque redimensiona a captura junto dos limites existentes.

A inferior também reaproveita a sombra 2D nativa de `Carta`: deslocamento inicial (-2, 3), opacidade inicial 0,14, desenhada atrás da própria face e sobre a carta anterior na ordem esquerda → direita. Seu deslocamento independe da fonte da mesa. Vale para inferior livre e inferior sobre a mesa; a opção **Sombras** do perfil da mão continua controlando sua visibilidade. A chegada restaura a visibilidade conforme o componente da mão, inclusive quando o usuário desligou as sombras. `Carta.configurar_sombra()` preserva o comportamento anterior por padrão; apenas a inferior deste laboratório recebe o estilo novo. Passaram 360 verificações headless de chegada, captura/recorte, hover e saída, sombras nativas, ordem no descarte, acomodação/limite, comandos sobrepostos, R e compatibilidade com o laboratório de mãos erguidas. Essa validação não confirma pixels renderizados.

**Sombra entre cartas da mão inferior** no painel acrescenta **Intensidade** (0–100%), **Deslocamento horizontal** e **Deslocamento vertical** (−20 a 20, passo 0,5). X negativo aponta para a esquerda; Y positivo, para baixo. Os controles afetam somente a inferior e não reorganizam o leque. Os valores acompanham **Salvar conjunto** e cópia do perfil na chave `sombra_inferior`, com `intensidade` em porcentagem e `x`/`y` em unidades locais. Perfis antigos recebem 14%, −2 e 3; valores inválidos são ignorados e valores fora dos limites são ajustados aos limites. **Restaurar referência completa** recupera esses padrões. Cartas compradas recebem o ajuste escolhido ao chegar. A validação seguinte passou em 441 verificações headless de preservação da sombra não adjacente antes/depois do pouso, luz dinâmica, gravação/carga em dados isolados, perfis antigos/inválidos, controles, novas cartas, limite 20, comandos sobrepostos, comparação e R. Os dados reais do usuário não foram gravados automaticamente.

`Carta.obter_apresentacao()`, `definir_apresentacao_externa()` e `transformacao_da_aparencia()` expõem a apresentação necessária ao laboratório. Os sinais `reorganizacao_iniciada`, `reorganizacao_atualizada` e `reorganizacao_concluida` permitem acompanhar o tween existente, inclusive interrupções e aplicação sem animação; cenas sem ouvintes seguem o comportamento anterior. A captura temporária desenha oculta com `UPDATE_ALWAYS` até `RenderingServer.frame_post_draw`, antes de liberar face/sombra e passar para atualização por visibilidade; assim não se apresenta uma textura ainda não inicializada. `MaoVisual.transformacao_destino_carta()` consulta a transformação final sem iniciar outra animação. A base visual ganhou hooks de arquivo/dados/metadados e aplicação de perfil para reaproveitar seu painel/persistência. A captura da mão usa limites dos destinos para não crescer conforme posições transitórias de reparent. Os demais laboratórios continuam com seus arquivos e comportamento anteriores.

`DescarteVisual.estado_destino_carta()` centraliza a geometria usada tanto por `receber_carta()` quanto pelo destino projetado no laboratório. O shader de projeção tem um tom opcional para as bordas da compra; transparente por padrão, sem alterar as mãos. As verificações headless das pilhas cobrem geometria, continuidade, compras/jogadas sobrepostas, limpeza e restauração dos parâmetros, usando dados temporários isolados. Não houve execução visual nem capturas; avaliar os novos volumes e sombras no editor.

O usuário encontrou um meio-termo visual no conjunto **teste 6**, salvo no arquivo das transferências. As notas pediam limitar o descarte e assentar as cartas restantes ao ocultar as de baixo. **Máximo de cartas visíveis** ajusta esse limite entre 10 e 20, com padrão 20; acompanha o perfil da pilha de descarte em `maximo_visiveis`. Conjuntos anteriores recebem o padrão. O limite também é exportado no Inspector de `DescarteVisual` e na raiz do laboratório. O componente registra as chegadas e retorna as cartas visíveis pela ordem de entrada, sem contar cartas em trânsito como já pousadas. Cada nova chegada além do limite oculta a mais antiga; as cartas reais e seus dados continuam no descarte. Aumentar o limite torna as anteriores disponíveis para apresentação novamente.

No laboratório, as capturas das cartas ocultadas são liberadas. As restantes descem em 0,18 segundo, usando os sinais do próprio tween de `Carta.aplicar_estado_visual()`; não há relógio paralelo. `DescarteVisual.duracao_acomodacao` permite ajustar esse tempo no Inspector. Alturas começam novamente na base do tampo; a espessura efetiva é distribuída entre as camadas para conservar o limite baixo de altura sem achatar as cartas superiores. Novas chegadas durante o assentamento retomam a altura corrente. R limpa as capturas e conexões, inclusive durante o assentamento. As verificações headless passaram para limites 10/20, restauração de perfis antigos/novos, preservação de todas as cartas, descida gradual, descartes rápidos, chegadas fora de ordem e o fluxo 2D original. A aparência do assentamento ainda aguarda avaliação do usuário.

O descarte deixou de repetir quatro combinações fixas de posição/giro. **Variação em X (±)**, **Variação em Y (±)** e **Variação de rotação (±)** ajustam limites independentes, de 0 a 30. Zero centraliza somente aquele eixo ou zera somente o giro; X começa em zero, Y em 6 e rotação em 10°. Esses parâmetros também são exportados em `DescarteVisual`. Um RNG próprio sorteia três valores normalizados por instância de carta, guardados até R/limpeza. Consultar o destino, mudar a quantidade visível ou assentar a pilha não sorteia novamente. Ajustar a amplitude e voltar ao valor anterior recupera a mesma distribuição. Os limites são salvos no perfil; as cartas/distribuição não são persistidas. Conjuntos antigos convertem o `desalinhamento` do descarte em Y = 4×valor e rotação = 5×valor, mantendo X zero; no teste 6, Y = 6,4 e rotação = 8°. A compra conserva seu desalinhamento anterior. As verificações headless passaram para limites, independência dos três controles, continuidade na chegada/assentamento, cartas ocultadas, perfis novos/antigos e limpeza. A aparência aleatória ainda será avaliada pelo usuário.

A referência mais recente do usuário é **teste 8**, salvo pelo próprio usuário no arquivo local das transferências: compra com 12 camadas, espessura 22, escala 1,15 e centro 43%/58%; descarte com espessura 3, máximo 20, escala 1,2 e centro 57%/59%, variações X ±8, Y ±13 e giro ±22°. Ambas usam intensidade de sombra 0,5; suavidade 2 na compra e 1,8 no descarte. Sombras entre cartas das pilhas ligadas; sombra entre cartas da inferior com intensidade 50%, X −6 e Y 10. Carregar esse conjunto manualmente; a importação inicial de teste 5 foi preservada. O agente apenas leu o perfil salvo, sem gravar nos arquivos locais do usuário.

Validar importando a composição aprovada e usando a inferior primeiro: D, J, primeiras/meio/últimas, D repetido, D/J antes das chegadas e R com vários trajetos. Depois selecionar uma lateral e a superior, testar frentes/versos e ausência de hover nas adversárias; na inferior, testar hover durante D/J sobrepostos, fonte de luz durante o trajeto, Tab/redimensionamento e salvar/carregar. Conferir que a carta não duplica nem muda de dono na chegada e que não há salto de posição/proporção entre mão e mesa. A sintaxe e a geometria são verificadas sem abrir o laboratório ou gerar capturas; a avaliação visual fica com o usuário.

### Verificações gerais

- A janela de referência é 1280×720, com stretch `canvas_items`/aspect `expand`; também foram consideradas telas de 1920×1080.
- Para revisar a mesa real sem rede, usar `scenes/desenvolvimento/previas/previa_mesa_partida.tscn`. Para interações completas, executar o projeto pelo menu ou `partida_rede.tscn` em instâncias separadas.
- O laboratório `teste.tscn` tem fundo cinza e áreas ciano das mãos. Isso é próprio daquela cena, não a aparência final da mesa.
- O usuário já validou manualmente lógica básica, multiplayer, cartas especiais, distribuição e troca de mãos em etapas anteriores. Esse histórico não equivale a uma verificação de toda alteração futura.
- Neste ambiente, tentativas de lançar o Godot diretamente por terminal para capturas chegaram a falhar com `signal 11`, inclusive em compatibilidade/headless. A causa não foi diagnosticada; não atribuir automaticamente o crash ao código do jogo nem alterar permanentemente o renderer para contornar.
- As últimas comparações de paleta foram imagens compostas a partir dos assets, com hexadecimais exatos e aproximação do fundo. Não eram screenshots do Godot. As prévias e arquivos temporários foram removidos do repositório.
- Em alterações visuais, revisar a composição nas cenas reais e preservar o teste original. Em alterações de regra/rede, revisar eventos, destinatários, ordem e tratamento do anfitrião.

Este arquivo é um ponto de entrada. Antes de editar, ler o código do componente envolvido e confirmar o pedido atual do usuário; evitar reconstruir funcionalidades que já existem.
