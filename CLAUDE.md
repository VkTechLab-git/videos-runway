# Memória do projeto: edição de vídeo com Runway Aleph 2

Responda sempre em português. O usuário edita vídeos em que ele mesmo aparece falando e quer trocar
cenário, roupa e luz sem alterar o rosto, a boca (lip sync) nem o áudio.

## Regras de trabalho
- Toda geração acontece no Runway (API em `api.dev.runwayml.com`, credenciais injetadas pelo proxy).
  O Claude só prepara os arquivos (recompressão, recorte do trecho de teste) e chama a API; não edita a imagem.
- Nunca gere sem o usuário pedir. Antes do vídeo completo, faça sempre um teste de 5 s num trecho de fala
  contínua (use `silencedetect` do ffmpeg para achar o trecho) e mostre o original e o resultado lado a lado.
- Informe o custo antes de gerar e o saldo depois (`GET /v1/organization` → `creditBalance`).
- Ao final de cada vídeo, atualize a seção "Aprendizados" abaixo com o que funcionou ou não.

## No início de um novo vídeo: faça estas perguntas
Antes, analise o vídeo (ffprobe e uma grade de frames) e já responda o que der para ver.
Pergunte só o que faltar, em blocos curtos:

1. **Vídeo:** duração (2 a 30 s por geração; acima disso, dividir em cortes)? A câmera se move? Há cortes?
   Quem deve ficar intacto? Fala o tempo todo?
2. **Cenário:** ambiente, época e país, numa frase. Os 3 a 5 elementos indispensáveis. Onde cada um fica
   no quadro (esquerda/direita, frente/fundo); o Aleph NÃO muda o enquadramento, então não pedir "plano aberto".
   Outras pessoas: o que fazem e para onde estão viradas?
3. **Personagem:** manter a roupa ou trocar (peças, cor, acessórios como touca e máscara)?
   O que pode ser coberto (cabelo pela touca) e o que nunca pode mudar?
4. **Luz (o mais importante):** fonte principal, direção em relação à pessoa (de cima/lado/frente),
   temperatura (fria/quente/mista). A luz do rosto pode mudar?
5. **Estética:** atual e nítida, ou de época (granulação, cor dessaturada)? Vale para o quadro inteiro? (recomendado)
6. **Orçamento:** quantos créditos usar? (teste de 5 s ≈ 140; 21 s ≈ 590 por passe)

## Modelo de prompt para uma única geração (sempre em inglês, até cerca de 900 caracteres)
```
Change the background to [AMBIENTE, ÉPOCA, PAÍS], and dress the man on the left in
[ROUPA + ACESSÓRIOS]. [POSIÇÃO NO QUADRO]: [OUTRAS PESSOAS E AÇÃO]. [3-5 ELEMENTOS].
Light the whole scene, including the man, from [FONTE] above/beside him: [COR DA LUZ],
soft shadows under his brows and nose, a faint [cor] rim light from [fonte secundária].
Keep his skin tone natural. One uniform [ESTÉTICA] look with fine grain over the entire
frame. Keep the man's face, facial features, mouth movements, expression, gestures,
hands and framing exactly the same. Static camera.
```
Princípios: não descrever o rosto, só pedir para mantê-lo; usar "the man on the left" em vez de
primeira pessoa; descrever o que deve aparecer em vez de negativas; "mouth movements" em vez de "fala".

## API (validada em outubro de 2026)
- `POST /v1/video_to_video` com `model: "aleph2"`. Campos: `videoUri` (obrigatório), `promptText`,
  `keyframes` (até 5: `{uri, seconds}` ou `{uri, at}` com `at` de 0 a 1), `seed` (>= 0), `ratio`,
  `contentModeration`. Não aceita `references` nem `duration`; a saída tem a duração da entrada.
- `gen4_aleph` foi descontinuado nesse endpoint. Outros modelos de video_to_video (seedance2,
  gemini_omni_flash_1.1) aceitam `references`, mas preservam pior a identidade.
- Custo: cerca de 28 créditos/s, mínimo 56. A saída vem em 1080×1920 (vertical) com o áudio original intacto.
- Upload: `POST /v1/uploads {"filename","type":"ephemeral"}` → POST multipart no S3 → `runwayUri`.
  Se o arquivo passar de cerca de 16 MB, recomprimir com `libx264 -crf 14..16` (sem perda visível).
- `act_two` (`/v1/character_performance`) serve para reaplicar a atuação facial se a boca sair diferente.
  Não existe endpoint `/v1/lip_sync`.
- Scripts prontos: `scripts/upload.sh <arquivo>` (retorna o runwayUri) e
  `scripts/aleph.sh <videoUri> <prompt.txt> <saida.mp4> [seed]` (gera, espera e baixa).

## Aprendizados
### Projeto 1: sala cirúrgica alemã dos anos 1990 (outubro de 2026, vídeo de 21 s, vertical)
- Editar o 1º frame com modelo de imagem (keyframe) DISTORCEU o rosto. Só com o prompt de texto, o rosto
  e a boca ficaram perfeitos.
- Com cenário trocado e luz do rosto mantida, a pessoa parece "colada": a luz frontal do celular e a pele
  quente não combinam com a sala. É preciso descrever a luz sobre a pessoa.
- Trocar roupa e touca e reiluminar NÃO alterou o rosto.
- "Greenish bounce light on his skin" deixou o pescoço verde-neon → usar "keep his skin tone natural".
- O Aleph quase não desfoca o fundo, mesmo pedindo explicitamente. Não insistir.
- Mesmo seed (4242): o vídeo completo mantém o estilo do teste, mas o layout do cenário pode mudar.
- Resultado final aprovado: 2 passes (cenário + roupa, depois reiluminação). O objetivo é conseguir em
  1 passe juntando as instruções de luz no prompt (modelo acima). Prompts usados: `prompts/projeto1-*.txt`.

### Projeto 2: consultório da Mayo Clinic em 1940 (outubro de 2026, vídeo de 26,4 s, vertical, selfie com câmera na mão) — em andamento
- Câmera na mão: trocar "Static camera" por "Keep the original handheld camera movement". O cenário acompanhou o movimento.
- Teste 1 (7,5–12,5 s, seed 4242, 140 créditos): rosto, boca e luz do rosto preservados; o jaleco e o P&B sépia
  ficaram bons. Problemas: o comedouro do pet no chão continuou na cena; só 1 médico apareceu, cortado na borda
  direita, a mulher não apareceu e a sala pareceu pequena. Objetos marcantes do original no chão precisam ser
  substituídos explicitamente no prompt.
- Limite da API: `promptText` aceita no máximo 1000 caracteres (o teste 2 foi recusado com 1010).
- Teste 2 (mesmo trecho e seed, 140 créditos): "a small rug where the round object on the floor was" eliminou o
  comedouro. "Behind his right shoulder and fully inside the frame" trouxe o biombo, a mulher e 1 médico
  nítidos, mas ainda saiu só 1 dos 2 médicos, e a mulher ficou ao lado do biombo, não atrás. O Aleph pôs
  sozinho um estetoscópio e um bordado no jaleco. O rosto e a boca continuaram perfeitos.
