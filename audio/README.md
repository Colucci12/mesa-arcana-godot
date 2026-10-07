# Áudio de Mesa Arcana

As músicas foram selecionadas de uma fonte CC0, conforme verificação informada pelo autor. O nome/URL do site ainda não foi recuperado. O registro de origem abaixo descreve a preparação e os caminhos locais; não constitui comprovação independente de licença. A origem/licença dos efeitos sonoros não está identificada nesse registro.

- `cartas`: efeitos curtos, separados por família e variante, em WAV PCM 16 bits.
- `ambiente`: três opções de vento e um relógio, em Ogg Vorbis.
- `fogo`: camada de fogo para a composição, em Ogg Vorbis.
- `musica`: quatro músicas disponíveis para comparação, em Ogg Vorbis.

Os nomes das variantes de cartas foram preservados para identificar os arquivos do pacote original. Os arquivos M4A do vento não foram duplicados: a seleção já possuía os mesmos nomes em Ogg.

`origem_arquivos.json` registra a origem de cada arquivo, seus parâmetros e a preparação aplicada. Os originais permanecem intactos em `C:\Users\colubio\Desktop\audios_jogos\audios escolhidos pro game`; a pasta de áudios brutos não foi importada para o projeto.

Os efeitos de cartas tiveram silêncio externo aparado, margem curta e suavização de bordas. Vento e fogo tiveram a emenda circular preparada com crossfade. Relógio e músicas mantêm a duração; suas emendas precisam ser avaliadas pelo ouvido. Não houve redução de ruído, equalização ou normalização de loudness nesta etapa. Os níveis originais foram preservados, exceto a atenuação constante dos arquivos com pico acima de 0,98.

Experimente na aba **Áudio** do Laboratório de Cenário 2D. As cartas respondem a compra, retirada da mão, chegada à mesa e hover conforme o conjunto escolhido. Ative ou desligue cada camada em **Tocar na cena**. Para ouvir só um arquivo sem mantê-lo tocando, use **Ouvir uma vez**. **Ouvir todas as categorias** encerra o isolamento.

As referências **Audio V1** e **Audio V2** ficam em `scripts/desenvolvimento/laboratorios/presets/audio_v1.json` e `audio_v2.json`. A **Audio V2** aprovada é a configuração inicial quando não há arquivo local: música 2 para a mesa, fogo e relógio habilitados, chegada ao descarte desligada, compra com Retirar do pacote e hover com Deslizar. Ambas aparecem como fallback na biblioteca; conjuntos locais prevalecem sobre referências com o mesmo nome. Os arquivos originais de todas as variantes continuam disponíveis.

O relógio da cena só toca durante a vez local. No laboratório, use **Simular minha vez** em Ambiente > Relógio; a simulação começa desligada e não é salva com os conjuntos. Na futura ligação à partida real, enviar o estado de turno para `definir_vez_local`. **Ouvir uma vez** permite avaliar o arquivo explicitamente fora da simulação.

Ao jogar uma carta sob o mouse, somente a próxima entrada de hover fica silenciosa para evitar sobreposição com a reorganização da mão. O hover visual continua funcionando; as próximas cartas voltam a fazer som. Essa supressão não usa temporizador.

Quando **Selecionar na mão** usa **Deslizar**, somente `card-slide-1` a `card-slide-4` ficam disponíveis para seleção e alternância. As variantes 5–8 permanecem nos arquivos e disponíveis para outras ações. Índices de hover antigos fora dessa faixa são ajustados durante a carga, sem regravar automaticamente o conjunto local.

Guarde os ajustes em **Conjuntos de áudio**. Esse arquivo é independente dos conjuntos visuais e só é escrito pelo botão Salvar. Não houve gravação automática dos arquivos locais do usuário durante a implementação.
