import SwiftUI

struct MultiplayerView: View {

    enum Page {

        case home

        case createRoom

        case browseRooms

        case hostLobby

        case guestLobby

        case cardSelection

    }

    @ObservedObject

    var service: MultiplayerService

    @ObservedObject

    var arState: GameARState

    @ObservedObject

    var gameFlow: GameFlowState

    let onExit: () -> Void

    @State

    private var page: Page = .home

    @State

    private var roomName = ""

    @State

    private var roomPrivacy:

        RoomPrivacy = .open

    @State

    private var selectedRoom:

        DiscoveredRoom?

    @State

    private var roomCode = ""

    @State

    private var showingCodeEntry = false

    var body: some View {

        ZStack {

            background

            switch page {

            case .home:

                multiplayerHome

            case .createRoom:

                createRoomView

            case .browseRooms:

                roomBrowserView

            case .hostLobby:

                hostLobbyView

            case .guestLobby:

                guestLobbyView

            case .cardSelection:

                MultiplayerCardSelectionView(

                    arState: arState,

                    gameFlow: gameFlow,

                    service: service,

                    onBack: {

                        if service.hostedRoom != nil {

                            page = .hostLobby

                        } else {

                            page = .guestLobby

                        }

                    }

                )

            }

        }

        .onDisappear {

            if page != .hostLobby

                && page != .guestLobby {

                service.stopBrowsing()

            }

        }

        .sheet(

            isPresented:

                $showingCodeEntry

        ) {

            privateRoomCodeSheet

                .presentationDetents(

                    [.height(280)]

                )

                .presentationDragIndicator(

                    .visible

                )

        }

        .onChange(

            of: service.connectionState

        ) {

            _,

            newState in

            if newState == .connected {

                page = .guestLobby

            }

        }

    }

    private var background: some View {

        LinearGradient(

            colors: [

                Color.black,

                Color.indigo.opacity(0.72),

                Color.black

            ],

            startPoint: .topLeading,

            endPoint: .bottomTrailing

        )

        .ignoresSafeArea()

    }

    private var multiplayerHome: some View {

        VStack(

            spacing: 18

        ) {

            header(

                title: "MULTIPLAYER",

                subtitle:

                    "Jogue com outro iPhone próximo",

                backAction: {

                    service.stopAll()

                    onExit()

                }

            )

            Spacer()

            actionButton(

                title: "CRIAR PARTIDA",

                subtitle:

                    "Crie uma nova sala",

                icon:

                    "plus.circle.fill"

            ) {

                page = .createRoom

            }

            actionButton(

                title: "ENTRAR EM UMA SALA",

                subtitle:

                    "Veja partidas disponíveis",

                icon:

                    "magnifyingglass"

            ) {

                service.startBrowsing()

                page = .browseRooms

            }

            Spacer()

            Spacer()

        }

        .padding(

            .horizontal,

            24

        )

    }

    private var createRoomView: some View {

        VStack(

            spacing: 20

        ) {

            header(

                title: "CRIAR PARTIDA",

                subtitle:

                    "Configure sua sala",

                backAction: {

                    page = .home

                }

            )

            VStack(

                spacing: 18

            ) {

                VStack(

                    alignment: .leading,

                    spacing: 8

                ) {

                    Text(

                        "NOME DA SALA"

                    )

                    .font(.caption2)

                    .fontWeight(.black)

                    .foregroundStyle(

                        .white.opacity(0.55)

                    )

                    TextField(

                        "Ex: Arena do Victor",

                        text: $roomName

                    )

                    .textInputAutocapitalization(

                        .words

                    )

                    .autocorrectionDisabled()

                    .padding(

                        .horizontal,

                        14

                    )

                    .frame(

                        height: 52

                    )

                    .background(

                        Color.white.opacity(

                            0.10

                        )

                    )

                    .clipShape(

                        RoundedRectangle(

                            cornerRadius: 14

                        )

                    )

                    .foregroundStyle(

                        .white

                    )

                }

                VStack(

                    alignment: .leading,

                    spacing: 8

                ) {

                    Text(

                        "PRIVACIDADE"

                    )

                    .font(.caption2)

                    .fontWeight(.black)

                    .foregroundStyle(

                        .white.opacity(0.55)

                    )

                    Picker(

                        "Privacidade",

                        selection:

                            $roomPrivacy

                    ) {

                        ForEach(

                            RoomPrivacy.allCases

                        ) { privacy in

                            Label(

                                privacy.displayName,

                                systemImage:

                                    privacy.systemImage

                            )

                            .tag(privacy)

                        }

                    }

                    .pickerStyle(

                        .segmented

                    )

                }

                if roomPrivacy == .privateRoom {

                    HStack(

                        spacing: 10

                    ) {

                        Image(

                            systemName:

                                "key.fill"

                        )

                        Text(

                            "Um código de 6 dígitos será gerado quando a sala for criada."

                        )

                        .font(

                            .caption

                        )

                    }

                    .foregroundStyle(

                        .white.opacity(

                            0.72

                        )

                    )

                    .frame(

                        maxWidth:

                            .infinity,

                        alignment:

                            .leading

                    )

                    .padding(

                        14

                    )

                    .background(

                        Color.white.opacity(

                            0.07

                        )

                    )

                    .clipShape(

                        RoundedRectangle(

                            cornerRadius: 14

                        )

                    )

                }

                if case let .failed(message) =

                    service.connectionState {

                    Text(LocalizedStringKey(message))

                        .font(.caption)

                        .foregroundStyle(

                            .red

                        )

                        .frame(

                            maxWidth:

                                .infinity,

                            alignment:

                                .leading

                        )

                }

                Button {

                    service.createRoom(

                        name: roomName,

                        privacy:

                            roomPrivacy

                    )

                    page = .hostLobby

                } label: {

                    Label(

                        "CRIAR SALA",

                        systemImage:

                            "plus.circle.fill"

                    )

                    .font(.headline)

                    .fontWeight(.bold)

                    .foregroundStyle(

                        .black

                    )

                    .frame(

                        maxWidth:

                            .infinity

                    )

                    .padding(

                        .vertical,

                        15

                    )

                    .background(

                        Color.green

                    )

                    .clipShape(

                        RoundedRectangle(

                            cornerRadius: 16

                        )

                    )

                }

                .disabled(

                    roomName

                        .trimmingCharacters(

                            in:

                                .whitespacesAndNewlines

                        )

                        .isEmpty

                )

                .opacity(

                    roomName

                        .trimmingCharacters(

                            in:

                                .whitespacesAndNewlines

                        )

                        .isEmpty

                    ? 0.45

                    : 1

                )

            }

            .padding(

                18

            )

            .background(

                Color.black.opacity(

                    0.45

                )

            )

            .clipShape(

                RoundedRectangle(

                    cornerRadius: 22

                )

            )

            Spacer()

        }

        .padding(

            .horizontal,

            24

        )

    }

    private var roomBrowserView: some View {

        VStack(

            spacing: 16

        ) {

            header(

                title: "SALAS DISPONÍVEIS",

                subtitle:

                    "Partidas próximas",

                backAction: {

                    service.stopBrowsing()

                    page = .home

                }

            )

            if service.discoveredRooms.isEmpty {

                Spacer()

                ProgressView()

                    .tint(.white)

                Text(

                    "Procurando salas..."

                )

                .font(.headline)

                .foregroundStyle(

                    .white

                )

                Text(

                    "Os dois iPhones precisam permitir acesso à rede local."

                )

                .font(.caption)

                .foregroundStyle(

                    .white.opacity(

                        0.55

                    )

                )

                .multilineTextAlignment(

                    .center

                )

                .padding(

                    .horizontal,

                    30

                )

                Spacer()

            } else {

                if service.connectionState

                    == .connecting {

                    HStack(

                        spacing: 8

                    ) {

                        ProgressView()

                            .tint(.white)

                        Text(LocalizedStringKey(service.statusMessage ?? "Conectando..."))

                        .font(.caption)

                        .foregroundStyle(

                            .white.opacity(

                                0.70

                            )

                        )

                    }

                    .padding(

                        .vertical,

                        6

                    )

                }

                if case let .failed(message) =

                    service.connectionState {

                    Text(LocalizedStringKey(message))

                        .font(.caption)

                        .foregroundStyle(

                            .red

                        )

                        .frame(

                            maxWidth:

                                .infinity,

                            alignment:

                                .leading

                        )

                        .padding(

                            .horizontal,

                            4

                        )

                }

                ScrollView {

                    LazyVStack(

                        spacing: 12

                    ) {

                        ForEach(

                            service

                                .discoveredRooms

                        ) { room in

                            roomRow(room)

                        }

                    }

                }

                .refreshable {

                    service.stopBrowsing()

                    service.startBrowsing()

                }

            }

        }

        .padding(

            .horizontal,

            20

        )

    }

    private var hostLobbyView: some View {

        VStack(

            spacing: 18

        ) {

            header(

                title: "SALA",

                subtitle:

                    "Você é o host",

                backAction: {

                    service.deleteRoom()

                    page = .home

                }

            )

            Spacer()

            if let room =

                service.hostedRoom {

                VStack(

                    spacing: 18

                ) {

                    Image(

                        systemName:

                            room.privacy

                                == .privateRoom

                            ? "lock.fill"

                            : "lock.open.fill"

                    )

                    .font(

                        .system(size: 34)

                    )

                    .foregroundStyle(

                        .purple

                    )

                    Text(room.name)

                        .font(

                            .title2

                        )

                        .fontWeight(

                            .black

                        )

                        .foregroundStyle(

                            .white

                        )

                    Text(LocalizedStringKey(room.privacy.displayName))

                    .font(.caption)

                    .foregroundStyle(

                        .white.opacity(

                            0.60

                        )

                    )

                    if let code =

                        room.joinCode {

                        VStack(

                            spacing: 5

                        ) {

                            Text(

                                "CÓDIGO DA SALA"

                            )

                            .font(

                                .caption2

                            )

                            .fontWeight(

                                .black

                            )

                            .foregroundStyle(

                                .white.opacity(

                                    0.55

                                )

                            )

                            Text(code)

                                .font(

                                    .system(

                                        size: 34,

                                        weight:

                                            .black,

                                        design:

                                            .monospaced

                                    )

                                )

                                .foregroundStyle(

                                    .white

                                )

                                .tracking(5)

                        }

                        .padding(

                            .vertical,

                            12

                        )

                    }

                    Divider()

                        .overlay(

                            Color.white.opacity(

                                0.10

                            )

                        )

                    HStack(

                        spacing: 12

                    ) {

                        playerStatus(

                            title:

                                "PLAYER 1",

                            connected:

                                true

                        )

                        playerStatus(

                            title:

                                "PLAYER 2",

                            connected:

                                service

                                    .guestConnected

                        )

                    }

                    Text(LocalizedStringKey(service.statusMessage ?? "Aguardando jogador..."))

                    .font(.caption)

                    .foregroundStyle(

                        .white.opacity(

                            0.65

                        )

                    )

                }

                .padding(

                    22

                )

                .background(

                    Color.black.opacity(

                        0.52

                    )

                )

                .clipShape(

                    RoundedRectangle(

                        cornerRadius: 24

                    )

                )

                if service.guestConnected {

                    Button {

                        arState.resetForNewSession()

                        service.resetLocalSelection()

                        page = .cardSelection

                    } label: {

                        Label(

                            "ESCOLHER PERSONAGEM",

                            systemImage:

                                "rectangle.and.hand.point.up.left.fill"

                        )

                        .font(.headline)

                        .fontWeight(.bold)

                        .foregroundStyle(.black)

                        .frame(

                            maxWidth:

                                .infinity

                        )

                        .padding(

                            .vertical,

                            14

                        )

                        .background(

                            Color.green

                        )

                        .clipShape(

                            RoundedRectangle(

                                cornerRadius: 16

                            )

                        )

                    }

                }

                Button(

                    role: .destructive

                ) {

                    service.deleteRoom()

                    page = .home

                } label: {

                    Label(

                        "EXCLUIR SALA",

                        systemImage:

                            "trash.fill"

                    )

                    .font(.headline)

                    .foregroundStyle(

                        .white

                    )

                    .frame(

                        maxWidth:

                            .infinity

                    )

                    .padding(

                        .vertical,

                        14

                    )

                    .background(

                        Color.red.opacity(

                            0.78

                        )

                    )

                    .clipShape(

                        RoundedRectangle(

                            cornerRadius: 16

                        )

                    )

                }

            } else {

                ProgressView(

                    "Criando sala..."

                )

                .tint(.white)

                .foregroundStyle(

                    .white

                )

            }

            Spacer()

        }

        .padding(

            .horizontal,

            24

        )

    }

    private var guestLobbyView: some View {

        VStack(

            spacing: 18

        ) {

            header(

                title: "SALA",

                subtitle:

                    "Conectado como Player 2",

                backAction: {

                    service.leaveJoinedRoom()

                    service.startBrowsing()

                    page = .browseRooms

                }

            )

            Spacer()

            VStack(

                spacing: 18

            ) {

                Image(

                    systemName:

                        "checkmark.circle.fill"

                )

                .font(

                    .system(size: 48)

                )

                .foregroundStyle(

                    .green

                )

                Text(

                    "CONECTADO"

                )

                .font(.title2)

                .fontWeight(.black)

                .foregroundStyle(

                    .white

                )

                Text(LocalizedStringKey(service.statusMessage ?? "Você entrou na sala."))

                .font(.caption)

                .foregroundStyle(

                    .white.opacity(

                        0.65

                    )

                )

                .multilineTextAlignment(

                    .center

                )

                HStack(

                    spacing: 12

                ) {

                    playerStatus(

                        title:

                            "PLAYER 1",

                        connected:

                            true

                    )

                    playerStatus(

                        title:

                            "PLAYER 2",

                        connected:

                            true

                    )

                }

            }

            .padding(

                22

            )

            .background(

                Color.black.opacity(

                    0.52

                )

            )

            .clipShape(

                RoundedRectangle(

                    cornerRadius: 24

                )

            )

            Button {

                arState.resetForNewSession()

                service.resetLocalSelection()

                page = .cardSelection

            } label: {

                Label(

                    "ESCOLHER PERSONAGEM",

                    systemImage:

                        "rectangle.and.hand.point.up.left.fill"

                )

                .font(.headline)

                .fontWeight(.bold)

                .foregroundStyle(.black)

                .frame(

                    maxWidth:

                        .infinity

                )

                .padding(

                    .vertical,

                    14

                )

                .background(

                    Color.green

                )

                .clipShape(

                    RoundedRectangle(

                        cornerRadius: 16

                    )

                )

            }

            Button {

                service.leaveJoinedRoom()

                service.startBrowsing()

                page = .browseRooms

            } label: {

                Label(

                    "SAIR DA SALA",

                    systemImage:

                        "rectangle.portrait.and.arrow.right"

                )

                .font(.headline)

                .foregroundStyle(

                    .white

                )

                .frame(

                    maxWidth:

                        .infinity

                )

                .padding(

                    .vertical,

                    14

                )

                .background(

                    Color.white.opacity(

                        0.10

                    )

                )

                .clipShape(

                    RoundedRectangle(

                        cornerRadius: 16

                    )

                )

            }

            Spacer()

        }

        .padding(

            .horizontal,

            24

        )

    }

    private func roomRow(

        _ room: DiscoveredRoom

    ) -> some View {

        Button {

            selectedRoom = room

            roomCode = ""

            if room.privacy

                == .privateRoom {

                showingCodeEntry = true

            } else {

                service.join(

                    room: room,

                    code: nil

                )

            }

        } label: {

            HStack(

                spacing: 14

            ) {

                Image(

                    systemName:

                        room.privacy

                            .systemImage

                )

                .font(

                    .system(size: 20)

                )

                .frame(

                    width: 32

                )

                VStack(

                    alignment: .leading,

                    spacing: 3

                ) {

                    Text(room.name)

                        .font(.headline)

                    Text(LocalizedStringKey(room.privacy.displayName))

                    .font(.caption2)

                    .opacity(0.6)

                }

                Spacer()

                Text("ENTRAR")

                    .font(.caption)

                    .fontWeight(.black)

                Image(

                    systemName:

                        "chevron.right"

                )

                .font(.caption)

            }

            .foregroundStyle(

                .white

            )

            .padding(

                16

            )

            .background(

                Color.white.opacity(

                    0.09

                )

            )

            .clipShape(

                RoundedRectangle(

                    cornerRadius: 16

                )

            )

        }

        .buttonStyle(.plain)

    }

    private var privateRoomCodeSheet:

        some View {

        NavigationStack {

            VStack(

                spacing: 18

            ) {

                Image(

                    systemName:

                        "lock.fill"

                )

                .font(

                    .system(size: 32)

                )

                .foregroundStyle(

                    .purple

                )

                Text(

                    selectedRoom?.name

                    ?? "Sala privada"

                )

                .font(.headline)

                TextField(

                    "Código de 6 dígitos",

                    text:

                        $roomCode

                )

                .keyboardType(

                    .numberPad

                )

                .multilineTextAlignment(

                    .center

                )

                .font(

                    .system(

                        size: 24,

                        weight: .bold,

                        design:

                            .monospaced

                    )

                )

                .onChange(

                    of: roomCode

                ) {

                    _,

                    newValue in

                    roomCode =

                        String(

                            newValue

                                .filter(

                                    \.isNumber

                                )

                                .prefix(6)

                        )

                }

                .padding(

                    .horizontal,

                    14

                )

                .frame(

                    height: 52

                )

                .background(

                    Color.secondary.opacity(

                        0.10

                    )

                )

                .clipShape(

                    RoundedRectangle(

                        cornerRadius: 14

                    )

                )

                Button(

                    "ENTRAR NA SALA"

                ) {

                    guard let selectedRoom

                    else {

                        return

                    }

                    showingCodeEntry =

                        false

                    service.join(

                        room:

                            selectedRoom,

                        code:

                            roomCode

                    )

                }

                .fontWeight(

                    .bold

                )

                .disabled(

                    roomCode.count != 6

                )

            }

            .padding(

                24

            )

            .navigationTitle(

                "Código da sala"

            )

            .navigationBarTitleDisplayMode(

                .inline

            )

        }

    }

    private func header(

        title: LocalizedStringKey,

        subtitle: LocalizedStringKey,

        backAction:

            @escaping () -> Void

    ) -> some View {

        HStack(

            spacing: 12

        ) {

            Button(

                action:

                    backAction

            ) {

                Image(

                    systemName:

                        "chevron.left"

                )

                .fontWeight(

                    .bold

                )

                .foregroundStyle(

                    .white

                )

                .frame(

                    width: 42,

                    height: 42

                )

                .background(

                    Color.white.opacity(

                        0.10

                    )

                )

                .clipShape(

                    Circle()

                )

            }

            VStack(

                alignment: .leading,

                spacing: 2

            ) {

                Text(title)

                    .font(.headline)

                    .fontWeight(.black)

                    .foregroundStyle(

                        .white

                    )

                Text(subtitle)

                    .font(.caption)

                    .foregroundStyle(

                        .white.opacity(

                            0.55

                        )

                    )

            }

            Spacer()

        }

        .padding(

            .top,

            8

        )

    }

    private func actionButton(

        title: LocalizedStringKey,

        subtitle: LocalizedStringKey,

        icon: String,

        action:

            @escaping () -> Void

    ) -> some View {

        Button(

            action: action

        ) {

            HStack(

                spacing: 14

            ) {

                Image(

                    systemName: icon

                )

                .font(

                    .system(

                        size: 22,

                        weight:

                            .semibold

                    )

                )

                .frame(

                    width: 34

                )

                VStack(

                    alignment: .leading,

                    spacing: 3

                ) {

                    Text(title)

                        .font(.headline)

                    Text(subtitle)

                        .font(.caption)

                        .opacity(0.60)

                }

                Spacer()

                Image(

                    systemName:

                        "chevron.right"

                )

            }

            .foregroundStyle(

                .white

            )

            .padding(

                18

            )

            .background(

                Color.white.opacity(

                    0.10

                )

            )

            .clipShape(

                RoundedRectangle(

                    cornerRadius: 18

                )

            )

        }

        .buttonStyle(.plain)

    }

    private func playerStatus(

        title: LocalizedStringKey,

        connected: Bool

    ) -> some View {

        VStack(

            spacing: 7

        ) {

            Image(

                systemName:

                    connected

                    ? "checkmark.circle.fill"

                    : "clock.fill"

            )

            .font(

                .system(size: 24)

            )

            .foregroundStyle(

                connected

                ? .green

                : .orange

            )

            Text(title)

                .font(.caption)

                .fontWeight(.bold)

                .foregroundStyle(

                    .white

                )

            Text(

                connected

                ? "Conectado"

                : "Aguardando"

            )

            .font(.caption2)

            .foregroundStyle(

                .white.opacity(

                    0.55

                )

            )

        }

        .frame(

            maxWidth: .infinity

        )

        .padding(

            .vertical,

            14

        )

        .background(

            Color.white.opacity(

                0.06

            )

        )

        .clipShape(

            RoundedRectangle(

                cornerRadius: 14

            )

        )

    }

}
