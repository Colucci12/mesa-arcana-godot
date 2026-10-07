# Identidade Mesa Arcana

Nome público: **Mesa Arcana**. Nome sugerido para o futuro repositório: `mesa-arcana-godot`.

O projeto é um estudo independente de Godot, inspirado em jogos de descarte de cartas. A menção a UNO no README explica a inspiração, sem apresentar o projeto como uma versão oficial ou associada à Mattel. Não foi feita uma pesquisa de disponibilidade de marca para o novo nome nem há garantia jurídica de exclusividade.

O logo anterior com as letras U, N e O foi substituído no menu e na sala por `images/UI/logo_mesa_arcana.png`. A edição mantém ARCANA no ornamento principal e forma MESA nas quatro cartas. O arquivo anterior foi removido da versão atual; ele e os nomes antigos podem continuar presentes no histórico Git, que não foi reescrito.

Os versos antigos com o nome JUNO e o motivo colorido foram substituídos por `images/card_back_arcana.svg` e `images/deck_arcana.svg`, desenhos vetoriais próprios em verde e dourado, com estrelas e ornamentos. As dimensões de 71×95 e 81×105 foram preservadas.

O título do projeto é Mesa Arcana. Os nomes técnicos `JUNO` em variáveis de ambiente e serviços Docker continuam para conservar as configurações existentes. `application/config/use_custom_user_dir` e `custom_user_dir_name` preservam o caminho dos conjuntos locais em `Godot/app_userdata/JUNO` no desktop. Não houve migração nem regravação desses conjuntos.

## Edição do logo com IA

Ferramenta: image_gen integrada, sem CLI. Arquivo de entrada: logo anterior `images/UI/pack_menu.png`. Arquivo final: `images/UI/logo_mesa_arcana.png`, PNG com transparência.

Prompt utilizado:

> Use case: text-localization. Asset type: Godot main-menu logo replacement. Input image is the edit target: existing ornate gold and emerald fantasy card-game wordmark. Change the game name to exactly "MESA ARCANA". Spell MESA M-E-S-A, ARCANA A-R-C-A-N-A. Preserve the existing ARCANA lettering, crescent moons, stars, gold carved ornaments and painterly detailed material quality as much as possible. Replace the three foreground cards currently reading U N O with four coordinated jewel-toned fantasy cards reading M E S A, in that exact left-to-right order, so the visual reads ARCANA above MESA. Preserve wide approximately 3:1 composition with generous transparent margins and the same centered emblem scale. Output a clean genuine alpha-transparent PNG with no background. All name text must be ARCANA and MESA only. Remove all U N O lettering completely. No additional slogan, watermark or brand. Keep all decorative parts that do not require changes.

## Origem e licença

O autor informou que as artes foram geradas com IA e que conferiu as músicas como CC0. Não lembra o site de origem das músicas. Essa informação foi registrada como declaração do autor, sem inventar uma fonte ou uma comprovação de licença. A licença OFL da fonte permanece no projeto; nenhuma licença de código foi adicionada.
