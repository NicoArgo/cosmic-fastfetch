# cosmic-fastfetch — POP Flow

O [fastfetch](https://github.com/fastfetch-cli/fastfetch) abrindo sozinho em
todo terminal novo, com o resumo do sistema ao lado de um logo. O logo pode
ser o da distro ou uma imagem sua, desenhada com letras e números.

**Opcional.** O `install-all.sh` da suíte pergunta antes, e a resposta padrão é
não. Tudo fica na sua conta (config do fastfetch e um bloco no `~/.bashrc`);
só a instalação do próprio fastfetch pede `sudo`.

## Uso

```bash
./install.sh                               # logo da distro
./install.sh --logo LOGO.png               # o seu logo, feito de letras
./install.sh --logo LOGO.png --fill POPOS  # as áreas cheias escrevem "POPOS"
./install.sh --no-autostart                # não abrir sozinho no terminal
./uninstall.sh                             # volta o que havia antes
```

Opções do logo:

| Opção | Para quê |
|---|---|
| `--cols N` | largura em caracteres (padrão 40); a altura sai da proporção da imagem |
| `--fill TEXTO` | texto repetido nas áreas cheias, em diagonal |
| `--crop X,Y,L,A` | usa só esse pedaço da imagem (em pixels) |
| `--circle` | só o círculo dentro do recorte, para logos redondos |
| `--invert` | o contrário: as partes escuras (ou as transparentes) viram letras |
| `--by-light` | decide por claro/escuro mesmo numa imagem com transparência |
| `--overlay ARQ` | remendo desenhado à mão por cima do resultado (veja abaixo) |

Rode o `install.sh` de novo para trocar o logo, e também depois de trocar a
fonte do terminal.

## Como o logo é desenhado

1. Num logo com fundo transparente, a silhueta vira letras, seja qual for a
   cor. Numa imagem sem transparência, as partes claras viram letras e as
   escuras ficam com o fundo do terminal, o que fica bom em terminal escuro.
   `--invert` faz o contrário.
2. Para cada célula do terminal, o script desenha todas as letras, números e
   alguns sinais (`` .,:;'`-_ ``) **na fonte do próprio terminal** e escolhe o
   caractere cuja forma mais se parece com aquele pedaço da imagem. Por isso
   a borda sai com `g`, `F`, `L`, `P` e `_`, e não com blocos chapados.
3. A proporção da célula vem do cosmic-term: a fonte e o tamanho em
   `~/.config/cosmic/com.system76.CosmicTerm/v1/`, e a altura da linha é
   `ceil(1,4 × tamanho)`. Com JetBrains Mono 15 a célula tem 9 × 21 px. Sem
   essa conta, um logo redondo sai oval.

Detalhes pequenos, como olhos, ocupam poucas células e às vezes saem
embaralhados. O `--overlay` resolve: um arquivo de texto do tamanho do logo em
que `?` mantém o caractere gerado e qualquer outro caractere (espaço também)
entra no lugar. Por exemplo, para trocar só a linha 9, das colunas 11 a 18:

```
(8 linhas vazias)
??????????  .dNNb.
```

O script também roda sozinho, para testar antes de instalar:

```bash
python3 tools/make-logo.py LOGO.png --fill TEXTO | sed 's/^\$1//'
```

## Arquivos

| No repo | Instalado em |
|---|---|
| `tools/make-logo.py` | só roda na instalação; gera o logo |
| — | `~/.config/fastfetch/config.jsonc` (o que havia antes vira `config.jsonc.pop-flow-orig`) |
| — | `~/.config/fastfetch/pop-flow-logo.txt` |
| — | bloco entre `# >>> POP Flow: cosmic-fastfetch >>>` e `<<<` no `~/.bashrc` |

O Pop!_OS 24.04 não tem o fastfetch no APT, então o `install.sh` baixa o .deb
das releases do projeto. Instalado assim, o APT não atualiza: para uma versão
nova, `sudo apt remove fastfetch` e rode o `install.sh` de novo.
