# DeckSpawn

**Dê vida às cartas físicas com realidade aumentada.**

Um **jogo de batalha com cartas para iOS**, desenvolvido como projeto pessoal e acadêmico com **Swift, SwiftUI, ARKit e RealityKit**. O DeckSpawn reconhece cartas físicas, invoca personagens 3D animados em uma cena de realidade aumentada e oferece batalhas singleplayer e multiplayer local entre dois iPhones.

[**English**](README.md) · [**Português (Brasil)**](README.pt-BR.md)

> **Estado do projeto:** Em desenvolvimento ativo  
> **Tipo de repositório:** Apresentação pública do código-fonte para estudos e portfólio  
> **Importante:** Este repositório **não inclui** os modelos 3D dos personagens, arquivos de animação, imagens de referência das cartas nem arquivos de áudio. Leia [Recursos ausentes e limitações](#recursos-ausentes-e-limitações) e [Licenciamento](#licenciamento).

---

## Conteúdo

- [Sobre o jogo](#sobre-o-jogo)
- [Demonstração do jogo](#demonstração-do-jogo)
- [Funcionalidades](#funcionalidades)
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

O **DeckSpawn** combina cartas físicas com personagens 3D interativos. Ao apontar a câmera do iPhone para uma carta compatível, o aplicativo utiliza reconhecimento de imagem e permite invocar o personagem correspondente em uma cena de realidade aumentada.

A experiência vai além do escaneamento: o jogador pode escolher um personagem e participar de batalhas contra um adversário controlado pelo jogo ou contra outro jogador em um iPhone próximo. O projeto explora a integração entre realidade aumentada, estados de jogo, animações e comunicação entre dispositivos em um único aplicativo iOS nativo.

## Demonstração do jogo

*Capturas reais e vídeo de gameplay serão adicionados aqui.*

### Screenshots

| Menu principal | Escaneamento da carta | Batalha em RA |
|:---:|:---:|:---:|
| *Em breve* | *Em breve* | *Em breve* |

<!-- GUIA PARA SCREENSHOTS — substitua a linha acima quando estiver pronto.
Crie docs/media/ e utilize imagens próprias que você tenha autorização para divulgar.

| Menu principal | Escaneamento da carta | Batalha em RA |
|:---:|:---:|:---:|
| ![Menu principal do DeckSpawn](docs/media/main-menu.png) | ![Escaneamento de carta física](docs/media/card-scanning.png) | ![Batalha em realidade aumentada](docs/media/ar-battle.png) |

Opcional: adicione uma segunda tabela com conexão multiplayer,
seleção de personagens e tela de vitória/derrota.
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
| **Reconhecimento de cartas físicas** | Identifica cartas impressas compatíveis pela câmera do iPhone, utilizando ARKit. |
| **Invocação em RA** | Apresenta o personagem 3D animado correspondente na cena da câmera. |
| **Animações dos personagens** | Carrega animações específicas para ações e resultados da partida. |
| **Batalhas singleplayer** | Permite escolher um personagem e enfrentar um adversário controlado pelo jogo. |
| **Multiplayer local** | Conecta dois iPhones próximos para batalhas multiplayer. |
| **Sistema de batalha** | Coordena movimentos, regras, transições de estado e resultados. |
| **Áudio e feedback tátil** | Reproduz efeitos e respostas táteis, incluindo sons distintos de vitória ou derrota conforme o resultado em cada aparelho. |
| **Interface bilíngue** | Possui localização para português brasileiro e inglês. |

> Esses sistemas fazem parte de um projeto em evolução. Seu comportamento pode mudar conforme o gameplay e a estabilidade forem aprimorados.

## Como funciona uma partida

### Singleplayer

1. Inicie uma partida no modo singleplayer.
2. Escaneie uma carta física compatível usando a câmera do iPhone.
3. Visualize o personagem correspondente invocado em RA.
4. Escolha **Pronto** para confirmar ou **Trocar Personagem** para escanear outra carta.
5. O jogo seleciona um adversário e inicia a batalha após uma contagem regressiva.
6. Finalize a partida e receba o feedback correspondente ao resultado.

### Multiplayer local

1. Os dois jogadores abrem o DeckSpawn em iPhones compatíveis diferentes.
2. Os aparelhos estabelecem uma conexão multiplayer de proximidade.
3. Os jogadores selecionam seus personagens e avançam pelo fluxo da partida.
4. O jogo coordena os eventos e resultados da batalha entre os dispositivos.
5. Cada iPhone apresenta o resultado sob a **perspectiva de seu próprio jogador** — por exemplo, o vencedor escuta o som de vitória, enquanto o outro escuta o som de derrota.

## Tecnologias utilizadas

| Tecnologia | Função |
|---|---|
| **Swift** | Lógica do aplicativo, regras e gerenciamento de estado |
| **SwiftUI** | Telas, menus e atualização da interface |
| **ARKit** | Reconhecimento de imagens e rastreamento em RA |
| **RealityKit** | Conteúdo de RA e apresentação de entidades 3D |
| **MultipeerConnectivity** | Comunicação de proximidade entre dispositivos no multiplayer |
| **Xcode** | Desenvolvimento, configuração e testes para iOS |
| **Blender / USDZ** | Preparação de modelos e animações 3D (assets não distribuídos aqui) |

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
| `Features/Shared/AR/ARViewContainer.swift` | Sessão de RA, reconhecimento das cartas e integração com o gameplay |
| `Features/Shared/AR/GameARState.swift` | Estado compartilhado da experiência em RA |
| `Features/Shared/Battle/` | Motor de batalha, movimentos, regras e estados |
| `Features/Shared/Models/CardDatabase.swift` | Definições das cartas e identificadores dos personagens/modelos |
| `Features/Shared/Models/CharacterAnimationSet.swift` | Configuração e busca de nomes de animações |
| `Features/MultiPlayer/Services/MultiplayerService.swift` | Comunicação e coordenação multiplayer |
| `Features/SinglePlayer/` | Fluxo e interface do modo solo |
| `Services/Audio/SoundManager.swift` | Reprodução dos sons e feedback dos resultados |
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

O DeckSpawn é um **projeto pessoal e acadêmico em andamento**, não um produto comercial finalizado. O desenvolvimento já abrange as bases de reconhecimento de cartas em RA, apresentação de personagens animados, fluxos de batalha singleplayer e multiplayer local, lógica de batalha, localização e feedback sonoro/tátil.

Entre os próximos objetivos considerados estão:

- Corrigir casos de instabilidade e melhorar a experiência de escaneamento e jogo.
- Refinar as animações, os efeitos e a apresentação visual.
- Substituir conteúdos de personagens de terceiros por **personagens e artes autorais**.
- Aprimorar a documentação e a reprodução das funcionalidades a partir do código público.

Essas intenções podem mudar ao longo do desenvolvimento.

## Repositório público e histórico do desenvolvimento

O DeckSpawn foi originalmente desenvolvido em um **repositório privado** com o nome de projeto `CardArenaAR`. Este repositório público começa com uma **cópia selecionada do código-fonte**: o histórico Git privado original e os assets não distribuíveis não fazem parte dele.

Portanto, um primeiro commit grande representa a **publicação de um projeto já desenvolvido**, e não todo o trabalho realizado em um único dia. Atualizações futuras poderão ser publicadas conforme a evolução do jogo.

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

O DeckSpawn é um projeto pessoal e também acadêmico. Seu objetivo é explorar a engenharia de software para iOS por meio de um jogo que combina **realidade aumentada, interação com cartas físicas, animações 3D, interfaces e comunicação multiplayer local**.

<!-- LINK DO PORTFÓLIO — substitua esta linha quando a página do seu site estiver disponível.
**Portfólio:** [Conheça o projeto DeckSpawn](URL_DO_SEU_PORTFOLIO)
-->

*Link para o projeto no portfólio em breve.*
