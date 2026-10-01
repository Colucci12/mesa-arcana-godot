# Arquitetura multiplayer do UNO

> Arquitetura do recorte jogável atual. O roteamento para um menu elaborado permanece como evolução futura.

```mermaid
%%{init: {"theme":"dark","themeVariables":{"background":"#0B1020","lineColor":"#94A3B8","textColor":"#E2E8F0"}}}%%
flowchart LR
    UI["Interface<br/>ChatPanel + MesaUI"]:::ui

    subgraph APP["GameManager · Autoload em cada peer"]
        direction TB
        ROUTER["SceneRouter · futuro<br/>troca as telas"]:::local
        BUS["EventBus<br/>comandos e eventos locais"]:::local

        subgraph NETWORK["Rede · nodes separados"]
            direction TB
            PEER["Conexão e ciclo dos peers<br/>entrada / saída"]:::network
            CHAT["ChatEndpoint<br/>Node · RPCs do chat"]:::network
            MATCH["MatchEndpoint<br/>Node · RPCs da partida"]:::network
        end
    end

    subgraph GAME["Partida · estado autoritativo no servidor"]
        direction TB
        API["Mesa_Api<br/>recebe comandos e valida regras"]:::logic
        TABLE["Mesa_Logica<br/>jogadores · mãos · descarte · turno"]:::state
        CARD["Classes Carta_*<br/>executam o efeito da carta"]:::logic
        EFFECTS["Efeitos_Api<br/>contexto para alterar o estado"]:::logic

        API -->|"consulta / atualiza"| TABLE
        API -->|"aplica efeito"| CARD
        CARD -->|"chama operações"| EFFECTS
        EFFECTS -->|"altera o estado"| TABLE
    end

    RPC["Godot RPC / ENet<br/>comunicação entre os peers"]:::network
    PLAYERS["Todos os peers<br/>incluindo quem enviou a ação"]:::peers

    UI -->|"mensagem de chat"| BUS
    BUS -->|"solicita envio"| CHAT
    UI -->|"jogar · comprar · passar"| BUS
    BUS -->|"encaminha comandos"| MATCH

    PEER -->|"participantes / interrupção"| MATCH
    MATCH -->|"pedido recebido no servidor"| API
    API -->|"resultado + eventos ordenados"| MATCH

    CHAT <-->|"mensagens de chat"| RPC
    MATCH <-->|"comandos e eventos da partida"| RPC
    RPC <-->|"broadcast ou envio direcionado"| PLAYERS

    CHAT -->|"avisa localmente"| BUS
    MATCH -->|"avisa localmente"| BUS
    BUS -->|"atualiza a interface"| UI
    ROUTER -->|"carrega"| UI

    classDef ui fill:#E0F2FE,stroke:#0284C7,color:#0C4A6E
    classDef local fill:#E2E8F0,stroke:#64748B,color:#1E293B
    classDef network fill:#DBEAFE,stroke:#3B82F6,color:#1E3A8A
    classDef logic fill:#F3E8FF,stroke:#9333EA,color:#581C87
    classDef state fill:#D1FAE5,stroke:#059669,color:#064E3B
    classDef peers fill:#FEF3C7,stroke:#D97706,color:#78350F
```

## Ideias registradas

- `GameManager` permanece entre cenas e contém `EventBus`, `NetworkManager`, `MatchEndpoint` e `ChatEndpoint`. Um roteador de cenas poderá ser adicionado quando houver outras telas.
- `ChatEndpoint` e `MatchEndpoint` separam os RPCs de chat dos RPCs da partida.
- O servidor valida e altera o estado autoritativo da partida. A `Mesa_Logica` guarda jogadores, mãos, descarte e turno; `Mesa_Api` recebe comandos e coordena as regras.
- As cartas chamam operações de efeito pelo `Efeitos_Api`. Essa classe participa da lógica local e não transmite pela rede.
- Depois de uma ação aceita, a camada de rede distribui o resultado e os eventos ordenados. O `EventBus` avisa a interface local; os RPCs comunicam os peers.
- Eventos públicos vão para todos. Informações privadas, como a mão de um jogador, são enviadas apenas ao destinatário correto.

## Estado da implementação

- `GameManager` é um autoload com `EventBus`, `NetworkManager`, `MatchEndpoint` e `ChatEndpoint` em caminhos iguais em todas as instâncias.
- `NetworkManager` abre ou conecta por ENet, apresenta cada cliente e associa o peer remoto a um ID estável de jogador. O anfitrião participa como jogador 1; os demais IDs são atribuídos pelo servidor e não dependem dos IDs de conexão do Godot.
- `MatchEndpoint` encaminha comandos à `Mesa_Api` somente no anfitrião. Cada evento volta aos participantes na mesma ordem; os dados privados são incluídos apenas na entrega ao dono da mão.
- `VisibilidadeEventos` aplica a mesma filtragem por jogador na rede e na prévia local. Eventos destinados apenas a uma pessoa não são enviados aos demais jogadores.
- `partida_rede.tscn` oferece uma entrada simples por nome, IP e porta e uma sala para dois a quatro jogadores. O anfitrião inicia manualmente quando todos os participantes confirmam a entrada.
- A interface distribui as mãos em relação ao jogador local: ele fica embaixo; os oponentes ocupam o topo e as laterais conforme a quantidade de participantes. As mãos laterais reutilizam a cena `mao.tscn` rotacionada.
- A saída de um participante durante a partida interrompe a rodada e devolve os restantes à sala. Eles podem iniciar outra partida; quem saiu pode entrar novamente na sala. A saída do anfitrião encerra a conexão dos clientes. Não há retomada da rodada nem migração de anfitrião.
- O chat usa o próprio endpoint e um painel recolhível, disponível na sala e durante a partida. As recusas de mensagens ficam nesse painel; as recusas de jogadas continuam na interface da mesa.
- A cena local `scenes/desenvolvimento/previas/previa_mesa_partida.tscn` continua disponível para revisar a interface sem rede.
- A cena `teste.tscn` é o laboratório de objetos e usa o baralho completo por padrão. A partida configura o mesmo `Baralho_Logico` com as cartas já implementadas; ambos usam `comprar_carta()`, que repõe a composição configurada quando o monte esgota.
- A partida básica entre duas instâncias em localhost foi validada manualmente no Godot.
- As cartas especiais coloridas `PULA`, `INVERTE` e `+2` e os coringas `TROCACOR`, `+4` e `TROCAMAO` participam do baralho.

## Planejamento e pendências

- [x] Etapa 1: lógica de partida, turnos, jogadas, compra e vitória.
- [x] Etapa 2: interface conectada ao estado real da mesa.
- [x] Etapa 3: anfitrião participante, conexão por IP e resultados distribuídos aos jogadores.
- [x] Etapa 4: efeitos coloridos, compras acumuladas e escolhas de cor e alvo.
- [x] Etapa 5, recorte básico: sala, chat, mensagens de erro e interrupção por desconexão.
- [ ] Validar uma partida completa com amigos em computadores diferentes, pela rede pretendida.

Menu elaborado, pontuação e retomada após reconexão continuam fora deste recorte.

## Chat

- A interface solicita o envio por `mensagem_chat_solicitada`. `GameManager` encaminha a solicitação ao `ChatEndpoint`.
- O cliente envia apenas o texto. O servidor identifica o autor pela conexão e usa o nome cadastrado na sala; participantes que ainda não concluíram a entrada não podem publicar mensagens.
- O servidor remove espaços nas extremidades, substitui quebras de linha por espaços e recusa mensagens vazias ou com mais de 280 caracteres. A recusa é enviada apenas ao remetente.
- Mensagens aceitas chegam aos participantes confirmados, incluindo o próprio autor e o anfitrião. O endpoint emite `mensagem_chat_recebida` no barramento local.
- O painel mostra o texto literalmente, sem interpretar BBCode, conserva as últimas 50 mensagens recebidas e indica mensagens novas quando está recolhido. A entrada é limpa após a confirmação do servidor.
- O histórico é local à sessão da sala: permanece entre rodadas e é limpo ao desconectar. Quem entra depois recebe as novas mensagens, sem recuperar mensagens anteriores.
- Chat não altera o estado da mesa e não depende da fila de animações das cartas.

## Regra de compra da partida básica

- No começo da vez, o jogador pode jogar uma carta da própria mão ou começar a comprar.
- Depois da primeira compra, só pode jogar a carta jogável recém-comprada. Se a carta não for jogável, continua comprando até encontrar uma jogável.
- Ao encontrar uma carta jogável, escolhe entre jogá-la e passar a vez. Não pode comprar outra carta nesse momento.
- Se o monte esgotar, o `Baralho_Logico` cria outro baralho da mesma composição da partida. O descarte permanece como está.
- O servidor informa publicamente a quantidade comprada e se o jogador está decidindo entre jogar e passar. A identidade da carta comprada continua privada.
- A mesa calcula os IDs de cartas que o jogador pode jogar e os envia apenas a ele. A mão usa essa lista para escurecer as demais cartas sem interromper as animações.
- A distribuição inicial alterna uma carta por jogador até cada um ter sete. Compra voluntária e penalidade usam a mesma operação da mesa para entregar cada carta.
- Cada entrega gera um `CartaRecebida` próprio, enviado em um RPC confiável. O evento informa publicamente quem recebeu e a nova quantidade da mão; os dados da carta chegam somente ao dono. A interface espaça o início das animações sem alterar os tweens da carta.

## Regras das cartas especiais coloridas

- A partida começa com uma carta numérica no descarte. O baralho contém números, `PULA`, `INVERTE`, `+2`, `TROCACOR`, `+4` e `TROCAMAO`.
- Uma carta especial combina com a cor ou com o símbolo da carta do topo.
- `PULA` salta o próximo jogador. Com dois jogadores, quem jogou recebe outra vez.
- `INVERTE` muda o sentido da mesa e, com dois jogadores, também salta o adversário.
- Cada `+2` soma dois à pilha pública de compra. O jogador seguinte pode rebater com qualquer `+2` ou clicar no monte para comprar a pilha e perder a vez.
- O `+4` soma quatro à pilha e pede uma cor antes de passar a vez. Pode rebater outro `+4`, mas não pode ser jogado sobre um `+2`. Um `+2` rebate um `+4` somente se combinar com a cor escolhida para ele; a partir daí, o topo é `+2` e continua a regra dos `+2`.
- Comprar a pilha é uma penalidade separada da compra voluntária: nenhuma das cartas recebidas pode ser jogada nesse turno. Se o monte esgotar durante a penalidade, o baralho repõe as cartas e a entrega continua.
- Quando a última carta da mão é uma especial, seu efeito ocorre antes de encerrar a partida. Se for `+2` ou `+4`, o próximo jogador compra a pilha automaticamente, sem nova oportunidade de rebater, e a partida termina. No caso do `+4`, a cor é escolhida antes dessa compra. A vitória considera todos os jogadores após os efeitos pendentes.
- Os efeitos e as quantidades compradas são eventos públicos ordenados; as identidades das cartas compradas continuam privadas.

## Escolha de cor

- `TROCACOR` e `TROCAMAO` podem ser jogadas em qualquer cor, exceto enquanto houver uma pilha de compra pendente. O `+4` também é coringa, mas não pode ser jogado sobre um `+2`.
- Após `CartaJogada`, a mesa aguarda a escolha de quem jogou. O servidor publica `EscolhaCorSolicitada`; comandos de jogo ficam bloqueados até receber uma das quatro cores válidas.
- A escolha altera a cor do objeto lógico identificado pelo ID. O topo do descarte passa a ser a referência de cor das próximas jogadas, sem uma segunda cor guardada na mesa.
- `CorDaCartaAlterada` informa ID e cor a todos se a carta estiver no descarte; se estiver em uma mão, só o dono recebe o evento. Uma carta ainda no monte é alterada apenas no servidor e será entregue com a nova cor quando for comprada.
- A `Carta` visual recebe a alteração pelo ID e anima seu próprio fundo. A regra de perder o efeito especial ao deixar de ser preta fica para uma etapa posterior.
- Se o coringa foi a última carta da mão, a escolha é resolvida antes de `PartidaEncerrada`.

## Troca de mãos

- Com dois jogadores, `TROCAMAO` troca automaticamente as mãos de quem jogou e do adversário. Depois, quem jogou escolhe a cor do coringa.
- Com três ou quatro jogadores, quem jogou escolhe primeiro o alvo. `EscolhaAlvoSolicitada` informa publicamente quem está escolhendo; as jogadas ficam bloqueadas até a escolha válida. Depois da troca, quem jogou escolhe a cor.
- A mesa transfere os objetos de carta entre os jogadores. `MaosTrocadas` informa publicamente quem trocou e as novas quantidades; cada `MaoAtualizada` entrega as identidades da nova mão apenas ao respectivo dono.
- A interface move as cartas visuais entre as duas mãos com `reparent`. A `MaoVisual` cuida do leque e da virada; a mão local recebe seus novos dados privados após o movimento.
- A vitória é verificada para todos após a escolha de cor. Se a carta de troca foi a última da mão de quem jogou, a mão vazia passa ao adversário e ele vence.
