<img width="1448" height="1086" alt="DeckSpawn_logo" src="https://github.com/user-attachments/assets/ba67d7e5-bd88-4e0a-a2be-1daa41688502" />

# DeckSpawn

**Dê vida às cartas físicas com realidade aumentada.**

Um **jogo nativo de batalha com cartas para iOS**, desenvolvido como projeto pessoal e acadêmico. Criado com **Swift, SwiftUI, ARKit, RealityKit e Network.framework**, o DeckSpawn transforma cartas físicas em lutadores 3D animados, combinando batalhas em realidade aumentada, efeitos visuais personalizados, singleplayer e multiplayer local entre dois iPhones.

**Escaneie uma carta. Invoque um personagem. Batalhe em RA.**

[**English**](README.md) · [**Português (Brasil)**](README.pt-BR.md)

> **Estado do projeto:** Protótipo funcional — singleplayer e multiplayer local implementados; em desenvolvimento ativo  
> **Tipo de repositório:** Apresentação pública do código-fonte para estudos e portfólio  
> **Importante:** Este repositório **não inclui** os modelos 3D dos personagens, arquivos de animação, imagens de referência das cartas nem arquivos de áudio. Leia [Recursos ausentes e limitações](#recursos-ausentes-e-limitações) e [Licenciamento](#licenciamento).

---

## Conteúdo

- [Sobre o jogo](#sobre-o-jogo)
- [Demonstração do jogo](#demonstração-do-jogo)
- [Funcionalidades](#funcionalidades)
- [Personagens jogáveis e efeitos de combate](#personagens-jogáveis-e-efeitos-de-combate)
- [Como funciona uma partida](#como-funciona-uma-partida)
- [Tecnologias utilizadas](#tecnologias-utilizadas)
- [Arquitetura do projeto](#arquitetura-do-projeto)
- [Como abrir o projeto](#como-abrir-o-projeto)
- [Recursos ausentes e limitações](#recursos-ausentes-e-limitações)
- [Estado do desenvolvimento e próximos passos](#estado-do-desenvolvimento-e-próximos-passos)
- [Repositório público e histórico do desenvolvimento](#repositório-público-e-histórico-do-desenvolvimento)
- [Licenciamento](#licenciamento)
- [Sobre o projeto](#sobre-o-projeto)

## Sobre o jogo

O **DeckSpawn** combina cartas físicas com personagens 3D interativos. Ao apontar a câmera do iPhone para uma carta impressa compatível, o aplicativo utiliza reconhecimento de imagem e permite invocar o personagem correspondente em uma cena de realidade aumentada.

A carta é o ponto de partida de uma batalha jogável, e não apenas um gatilho para exibição de um modelo 3D. Os jogadores escolhem seus personagens, enfrentam um adversário controlado pelo jogo ou outro jogador próximo e recebem feedback visual, sonoro e tátil durante a experiência.

O projeto explora a integração entre desenvolvimento nativo para iOS, rastreamento em RA, animações 3D, gerenciamento de estados de batalha e comunicação entre dispositivos. Ambos os modos de jogo estão implementados, e o fluxo de multiplayer local já foi testado em iPhones físicos.

## Demonstração do jogo

*Capturas reais e vídeo de gameplay*

### Screenshots

| Menu principal | Escaneamento da carta | Batalha em RA |
|:---:|:---:|:---:|
| *Em breve* | *Em breve* | *Em breve* |

| Seleção de personagens | Multiplayer local | Resultado da batalha |
|:---:|:---:|:---:|
| *Em breve* | *Em breve* | *Em breve* |

<!-- GUIA PARA SCREENSHOTS — substitua as linhas de preenchimento das tabelas quando estiver pronto.
Crie docs/media/ e utilize imagens próprias que você tenha autorização para divulgar.

| Menu principal | Escaneamento da carta | Batalha em RA |
|:---:|:---:|:---:|
| ![Menu principal do DeckSpawn](docs/media/main-menu.png) | ![Escaneamento de carta física](docs/media/card-scanning.png) | ![Batalha em realidade aumentada](docs/media/ar-battle.png) |

| Seleção de personagens | Multiplayer local | Resultado da batalha |
|:---:|:---:|:---:|
| ![Seleção de personagens](docs/media/character-selection.png) | ![Conexão multiplayer local](docs/media/local-multiplayer.png) | ![Resultado da batalha](docs/media/battle-result.png) |

Use os mesmos nomes de arquivos de imagem nos dois READMEs.
-->

### Vídeo de gameplay

*Vídeo de demonstração em breve.*

<!-- GUIA PARA VÍDEO — substitua a linha acima quando estiver pronto.
Para um vídeo hospedado:
[Assistir à demonstração do DeckSpawn](URL_DO_SEU_VIDEO)

Para uma miniatura clicável:
[![Assistir ao gameplay do DeckSpawn](docs/media/gameplay-thumbnail.png)](URL_DO_SEU_VIDEO)

Não publique vídeos ou artes de personagens sem as autorizações necessárias.
-->

## Funcionalidades

| Funcionalidade | Descrição |
|---|---|
| **Reconhecimento de cartas físicas** | Identifica cartas impressas compatíveis pela câmera do iPhone, utilizando rastreamento de imagens do ARKit. |
| **Invocação em RA** | Carrega o personagem 3D animado correspondente na cena do mundo real exibida pela câmera. |
| **Seleção de personagens** | Permite confirmar o personagem invocado ou escanear outra carta antes da batalha. |
| **Singleplayer (PvE)** | Batalhas contra adversários controlados pelo jogo e selecionados aleatoriamente. |
| **Multiplayer local (PvP)** | Conecta dois iPhones próximos por meio do Network.framework para batalhas entre jogadores. |
| **Sistema de batalha** | Coordena movimentos, regras, contagem regressiva, transições de estado e resultados das partidas. |
| **Sincronização multiplayer** | Troca informações de gameplay entre os dispositivos e coordena o andamento e os resultados das partidas sob a perspectiva de cada jogador. |
| **Animações 3D** | Conjuntos de animações específicos para cada personagem, incluindo postura de espera, ações de combate e reações/resultados de batalha. |
| **Efeitos visuais de combate (VFX)** | Efeitos de ataque personalizados, incluindo rastros de movimento e cores características, complementam as animações 3D. |
| **Efeitos sonoros (SFX)** | Feedback sonoro no escaneamento e na invocação, com sons distintos de vitória e derrota conforme o resultado de cada jogador. |
| **Feedback tátil** | Respostas hápticas complementam as interações durante o jogo. |
| **Interface localizada** | Menus e interface do jogo disponíveis em português brasileiro e inglês. |

## Personagens jogáveis e efeitos de combate

A versão de desenvolvimento conta atualmente com quatro personagens jogáveis, cada um associado a uma carta física e a seu próprio conjunto de animações 3D.

| Personagem | Imagem |
|---|---|
| Homem-Aranha (Spider-Man) | <img width="575" height="460" alt="spiderman_cardgame" src="https://github.com/user-attachments/assets/776227f3-d448-49f3-a283-a80008de0ad3" /> |
| Stormtrooper | <img width="575" height="460" alt="stormtrooper_cardgame" src="https://github.com/user-attachments/assets/6403981f-6d13-409c-809a-ae3a0206d666" /> |
| Goku | <img width="575" height="460" alt="goku_cardgame" src="https://github.com/user-attachments/assets/5847e81b-6fac-4701-bc96-01e1ab8e9654" /> |
| Sra. Incrível (Mulher-Elástica / Mrs. Incredible) | <img width="575" height="460" alt="mrsincredible_cardgame" src="https://github.com/user-attachments/assets/73b227ce-9143-478a-9512-d72edfd671b0" /> |

Foram desenvolvidos efeitos para destacar o movimento de cada ataque, em vez de apenas exibir efeitos genéricos ao redor dos personagens. Os rastros de ataque do Stormtrooper, os efeitos de soco e chute da Sra. Incrível, o kamehameha bem característico do Goku e efeitos de teia do Homem-Aranha, estão entre as adições recentes à apresentação do combate.

A preparação dos personagens envolve importação e rigging dos modelos 3D, preparação das animações e exportação dos arquivos no formato USDZ para uso no RealityKit. O jogo associa cada carta compatível aos identificadores do personagem e de suas animações.

> Esses personagens reconhecíveis de terceiros são utilizados como referências de desenvolvimento e aprendizado. Seus modelos, texturas, arquivos de animação e artes das cartas não são distribuídos neste repositório público. Leia [Licenciamento](#licenciamento).

## Como funciona uma partida

### Singleplayer

1. Selecione o modo singleplayer no menu principal.
2. Escaneie uma carta física compatível usando a câmera do iPhone.
3. Visualize o personagem animado correspondente invocado em RA.
4. Escolha **Pronto** para confirmar ou **Trocar Personagem** para escanear outra carta.
5. O jogo seleciona aleatoriamente um adversário e inicia a contagem regressiva para a batalha.
6. Dispute a partida utilizando o sistema de combate, com animações e efeitos visuais dos personagens.
7. Receba o feedback correspondente ao resultado da batalha.

### Multiplayer local

1. Abra o DeckSpawn em dois iPhones compatíveis diferentes.
2. Estabeleça uma conexão de proximidade no modo multiplayer utilizando Network.framework.
3. Cada jogador escolhe seu personagem escaneando uma carta física compatível.
4. Ambos avançam pelo fluxo da partida e iniciam o combate.
5. O jogo troca informações de gameplay entre os dispositivos para coordenar o andamento e os resultados da batalha.
6. Cada iPhone apresenta o resultado sob a **perspectiva de seu próprio jogador**: o vencedor escuta o som de vitória, enquanto o jogador derrotado escuta o som de derrota.

O multiplayer local está funcional e não depende de um servidor dedicado de jogos online nem do Game Center. Ambos os aparelhos precisam ter uma versão jogável do aplicativo instalada. Multiplayer pela internet e matchmaking remoto não estão implementados.

## Tecnologias utilizadas

| Tecnologia | Função |
|---|---|
| **Swift** | Lógica do aplicativo, regras e gerenciamento de estado |
| **SwiftUI** | Telas, menus e atualização da interface |
| **ARKit** | Reconhecimento de imagens e rastreamento em RA |
| **RealityKit** | Apresentação de entidades 3D, reprodução de animações e efeitos de combate em RA |
| **Network.framework** | Comunicação de proximidade entre dispositivos no multiplayer |
| **Xcode** | Desenvolvimento, configuração e testes para iOS |
| **Blender / Mixamo** | Preparação de modelos 3D, rigging e fluxo de animação dos personagens |
| **USDZ** | Formato dos modelos 3D e animações utilizados pelo RealityKit (assets não distribuídos aqui) |
| **String Catalog (`.xcstrings`)** | Localização para português brasileiro e inglês |

## Arquitetura do projeto

O repositório público preserva a organização original do código-fonte. Algumas pastas de recursos existem somente na cópia privada de desenvolvimento.

```text
DeckSpawn/                           # Repositório público
├── App/
│   └── MyApp.swift
├── Features/
│   ├── Main/                        # Menu principal e configurações
│   │   └── Views/
│   ├── MultiPlayer/                 # Modelos, serviço e telas do multiplayer
│   │   ├── Models/
│   │   ├── Services/
│   │   └── Views/
│   ├── Shared/                      # RA, batalhas, háptica e dados das cartas
│   │   ├── AR/
│   │   ├── Battle/
│   │   ├── Haptics/
│   │   ├── Models/
│   │   └── Views/
│   └── SinglePlayer/                # Fluxo e telas do modo solo
│       ├── Models/
│       └── Views/
├── Services/
│   └── Audio/                       # SoundManager.swift (apenas código)
├── Resources/
│   └── Assets.xcassets/             # Ícone, logotipo e cor de destaque
├── CardArenaAR.xcodeproj/           # Nome técnico original no Xcode
├── CardArenaAR-Info.plist
├── DeckSpawnL10n.swift
├── Localizable.xcstrings
├── .gitignore
├── README.md
├── README.pt-BR.md
└── LICENSE                           # Licença MIT (adicionada separadamente)
```

**Arquivos importantes:**

| Arquivo | Responsabilidade |
|---|---|
| `Features/Shared/AR/ARViewContainer.swift` | Sessão de RA, reconhecimento das cartas, apresentação dos personagens, animações e efeitos de combate |
| `Features/Shared/AR/GameARState.swift` | Estado compartilhado da experiência em RA |
| `Features/Shared/Battle/` | Motor de batalha, movimentos, regras e estados |
| `Features/Shared/Models/CardDatabase.swift` | Definições das cartas e identificadores dos personagens/modelos |
| `Features/Shared/Models/CharacterAnimationSet.swift` | Configuração e busca de nomes de animações |
| `Features/MultiPlayer/Services/MultiplayerService.swift` | Comunicação de proximidade entre aparelhos e coordenação multiplayer |
| `Features/SinglePlayer/` | Fluxo e interface do modo solo |
| `Services/Audio/SoundManager.swift` | Áudio de escaneamento, invocação e feedback dos resultados da partida |
| `Localizable.xcstrings` | Traduções da interface |

> **Por que o projeto Xcode ainda se chama `CardArenaAR`?** Esse era o nome utilizado no início do desenvolvimento. **DeckSpawn** é o nome público atual do jogo, mas o projeto Xcode e alguns identificadores internos ainda preservam o nome original.

## Como abrir o projeto

### Requisitos

- Um Mac com uma versão adequada do **Xcode** instalada.
- Um **iPhone físico compatível** para testar as funcionalidades de RA pela câmera.
- Dois iPhones compatíveis para explorar o fluxo completo do multiplayer local.
- Sua própria configuração de assinatura de desenvolvimento Apple, quando necessária.
- Assets substitutos devidamente licenciados, caso deseje executar as funcionalidades dependentes de recursos gráficos e sonoros.

### Abrindo o código-fonte

```bash
git clone https://github.com/victorhasse/DeckSpawn.git
cd DeckSpawn
open CardArenaAR.xcodeproj
```

Abra o projeto no Xcode, revise as configurações de assinatura e as permissões necessárias e explore o código. Para tentar executar uma versão jogável, adicione recursos adequados e ajuste as referências ou configurações de compilação que dependerem deles.

**Não há garantia de que uma cópia deste repositório compile ou execute o jogo completo sem alterações.** Leia a próxima seção antes de tentar rodá-lo.

## Recursos ausentes e limitações

O repositório público foi preparado para apresentar o **código-fonte**, e não para distribuir o jogo completo pronto para jogar.

Os seguintes recursos foram intencionalmente **deixados fora dos commits**:

| Excluído do repositório público | Local original no projeto privado |
|---|---|
| Modelos 3D, texturas e animações dos personagens | `Resources/Models3D/` |
| Efeitos sonoros e arquivos de áudio | `Resources/Audio/` |
| Imagens de referência das cartas físicas utilizadas pelo ARKit | `Resources/Assets.xcassets/AR Resources.arresourcegroup/` |

O **ícone do aplicativo, o logotipo DeckSpawn e a cor de destaque** continuam em `Resources/Assets.xcassets/` para identificação visual do projeto. Isso **não** significa que estejam cobertos pela licença MIT do código.

O código Swift pode conter referências aos nomes de arquivos ausentes (como `.usdz` e `.wav`) e ao grupo de imagens `AR Resources` do ARKit. Essas referências indicam o que o aplicativo espera encontrar, mas **não disponibilizam os recursos em si**. Sem arquivos substitutos, o escaneamento, a exibição dos personagens, os sons e outras funcionalidades podem ficar indisponíveis. Dependendo da configuração do Xcode, arquivos ausentes também podem provocar erros de compilação.

Quem reutilizar o código deve adicionar **seus próprios assets ou recursos com autorização de uso**, atualizar os identificadores e referências correspondentes e verificar a configuração nos dispositivos utilizados.

## Estado do desenvolvimento e próximos passos

O DeckSpawn é um protótipo funcional com finalidade pessoal, acadêmica e de portfólio, não um produto comercial finalizado. O foco atual está em aprimorar os modos de jogo já implementados e sua apresentação, em vez de expandir para serviços online.

### Funcionalidades implementadas

- [x] Reconhecimento de cartas físicas e invocação de personagens animados em RA.
- [x] Batalhas singleplayer contra adversários controlados pelo jogo.
- [x] Multiplayer local funcional entre dois iPhones físicos.
- [x] Quatro personagens jogáveis com conjuntos próprios de animações.
- [x] Efeitos de combate personalizados, incluindo os ataques do Stormtrooper e da Sra. Incrível.
- [x] Sons de escaneamento e invocação, feedback tátil e áudio de vitória/derrota.
- [x] Localização para português brasileiro e inglês.
- [x] Repositório público de código-fonte separado dos assets não distribuídos.

### Melhorias futuras

- [ ] Melhorar a confiabilidade do escaneamento, o desempenho e a estabilidade do jogo.
- [ ] Refinar as animações, os efeitos visuais e a apresentação das batalhas.
- [ ] Ampliar a documentação e facilitar testes com assets substitutos devidamente autorizados.
- [ ] Adicionar screenshots e vídeos de gameplay a este README.
- [ ] Explorar a substituição dos conteúdos de terceiros por personagens e artes autorais.

**Escopo:** O multiplayer local é o modo de batalha entre jogadores oferecido pelo projeto. Multiplayer online, integração com Game Center e distribuição pública pela App Store estão fora do escopo atual. Este planejamento não representa um cronograma de lançamento.

## Repositório público e histórico do desenvolvimento

O DeckSpawn foi originalmente desenvolvido em um **repositório privado** com o nome de projeto `CardArenaAR`. Este repositório público começa com uma **cópia selecionada do código-fonte**: o histórico Git privado original e os assets não distribuíveis não fazem parte dele.

Portanto, um primeiro commit grande representa a **publicação de um projeto já desenvolvido**, e não todo o trabalho realizado em um único dia. O repositório público é agora a base principal para as próximas atualizações, enquanto o repositório privado original permanece como backup da versão anterior e de seus assets de desenvolvimento.

## Licenciamento

### Código-fonte — MIT

O **código-fonte original** do projeto está disponibilizado sob a **[Licença MIT](LICENSE)**. Ela permite usar, modificar e redistribuir o código abrangido — inclusive comercialmente — desde que sejam respeitadas as condições da licença e preservado o aviso de direitos autorais.

### Assets, identidade visual e propriedade intelectual de terceiros

**A licença MIT se aplica somente ao código-fonte original. Ela não concede direitos sobre assets do jogo, identidades de personagens, materiais audiovisuais ou elementos de marca.** Isso inclui, entre outros:

- Modelos 3D, rigs, animações, texturas e artes de terceiros.
- Personagens reconhecíveis, nomes de personagens, logotipos e marcas pertencentes a terceiros.
- Artes das cartas físicas e imagens de referência para reconhecimento em RA.
- Efeitos sonoros, músicas, vídeos e outros conteúdos de mídia.
- Nome DeckSpawn, logotipo, ícone do aplicativo e demais elementos autorais de identidade visual, salvo licença específica em contrário.

Os materiais de terceiros permanecem sujeitos aos direitos de seus respectivos titulares e às licenças aplicáveis. Sua presença em descrições, referências do código, screenshots ou demonstrações **não concede permissão para copiar, redistribuir ou explorar comercialmente esses materiais**. O projeto não possui afiliação, patrocínio ou endosso dos titulares dos personagens ou marcas de terceiros eventualmente mostrados durante o desenvolvimento.

## Sobre o projeto

O DeckSpawn é um projeto pessoal e acadêmico voltado à prática da engenharia de software para iOS. Ele reúne **realidade aumentada, interação com cartas físicas, animações 3D, efeitos de combate, gerenciamento de estados de jogo, design de interfaces, localização e networking multiplayer local** em um único protótipo jogável.

**Portfólio:** [Veja mais projetos no meu website!](www.victorhasse.com)
