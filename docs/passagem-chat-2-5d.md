# Contexto para o próximo chat

- Projeto JUNO em Godot 4.6, branch `codex/experimento-2-5d`. Leia `docs/contexto-projeto.md` para detalhes; multiplayer em `docs/arquitetura-multiplayer.md`.
- Estamos validando 2.5D com projeção matemática em 2D, sem migrar para 3D. Mesa e adversários compartilham perspectiva; mão inferior pode ficar independente, em primeiro plano.
- Cena atual: `scenes/desenvolvimento/laboratorios/laboratorio_transferencias_2_5d.tscn` (também selecionada como cena inicial). Deriva do laboratório de mãos erguidas, com monte, descarte, sombras e fonte ajustável.
- Abre com o conjunto visual aprovado **teste 5**, importado de `user://laboratorio_maos_erguidas.json`, se existir. Testes deste laboratório são salvos separadamente em `user://laboratorio_transferencias_2_5d.json`. Esses arquivos são locais ao usuário.
- **D** compra, **J** joga primeira/meio/última da mão selecionada, **R** esvazia, **Tab** oculta o painel. Baralho completo com cores, especiais e coringas; comandos podem se sobrepor.
- Preservar o fluxo original: reparent imediato para mão/descarte; componentes reorganizam as cartas com tweens interrompíveis a partir do estado atual. A apresentação projetada acompanha sinais do mesmo tween, sem relógio paralelo. Não voltar a complicar essa lógica.
- Últimas correções: continuidade ao redirecionar cartas em trânsito; captura temporária aguarda o primeiro desenho; hover da mão inferior continua durante reorganização/compra/jogada, com ampliação interna independente (`HoverVisual`). Adversárias não recebem hover, mesmo reveladas; carta em transferência/virada também não.
- Verificações de componentes e continuidade passaram em headless. **O usuário executa e valida a aparência: não abrir o jogo nem tirar prints automaticamente.** Manter iterações pequenas e discutir mudanças maiores antes de implementar.
