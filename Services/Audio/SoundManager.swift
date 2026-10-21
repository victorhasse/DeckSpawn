import Foundation
import AVFoundation

enum GameSound: String, CaseIterable {
    case scanSuccess = "scan_success"
    case summonStart = "summon_start"
    case summonReveal = "summon_reveal"
    case despawn = "despawn"
    case victory = "victory"
    case defeat = "defeat"
}

final class SoundManager {

    static let shared = SoundManager()

    private let audioQueue = DispatchQueue(
        label: "CardArenaAR.SoundManager",
        qos: .userInitiated
    )

    private var players: [GameSound: AVAudioPlayer] = [:]

    private init() {

        audioQueue.async { [weak self] in
            self?.configureAudioSession()
        }
    }

    func play(
        _ sound: GameSound,
        enabled: Bool
    ) {
        guard enabled else { return }

        audioQueue.async { [weak self] in
            self?.playOnAudioQueue(sound)
        }
    }

    /// Reproduz o resultado na perspectiva do jogador deste iPhone.
    /// Chame uma unica vez por batalha, quando o resultado estiver confirmado.
    func playBattleResult(
        didWin: Bool,
        enabled: Bool
    ) {
        play(didWin ? .victory : .defeat, enabled: enabled)
    }

    /// Interrompe a musica de resultado ao iniciar outra batalha ou sair dela.
    func stopBattleResult() {
        audioQueue.async { [weak self] in
            guard let self else { return }

            for sound in [GameSound.victory, .defeat] {
                guard let player = self.players[sound] else { continue }
                player.stop()
                player.currentTime = 0
            }
        }
    }

    private func configureAudioSession() {

        let session =
            AVAudioSession.sharedInstance()

        do {

            try session.setCategory(
                .ambient,
                mode: .default,
                options: [.mixWithOthers]
            )

            if #available(iOS 26.0, *) {

                session.activate(
                    options: []
                ) { [weak self] activated, error in

                    guard let self else {
                        return
                    }

                    self.audioQueue.async {

                        if let error {
                            print(
                                "⚠️ Erro ativando sessão de áudio:",
                                error
                            )
                        }

                        guard activated else {
                            return
                        }

                        self.preloadSounds()
                    }
                }

            } else {

                try session.setActive(
                    true
                )

                preloadSounds()
            }

        } catch {

            print(
                "⚠️ Não foi possível configurar a sessão de áudio:",
                error
            )
        }
    }

    private func preloadSounds() {

        for sound in GameSound.allCases {

            guard players[sound] == nil else {
                continue
            }

            guard let url =
                    Bundle.main.url(
                        forResource:
                            sound.rawValue,
                        withExtension:
                            "wav"
                    )
            else {

                print(
                    "🔇 Áudio não encontrado:",
                    "\(sound.rawValue).wav"
                )

                continue
            }

            do {

                let player =
                    try AVAudioPlayer(
                        contentsOf: url
                    )

                player.prepareToPlay()

                players[sound] =
                    player

            } catch {

                print(
                    "❌ Erro pré-carregando \(sound.rawValue):",
                    error
                )
            }
        }
    }

    private func playOnAudioQueue(
        _ sound: GameSound
    ) {

        // Dois resultados diferentes nunca devem tocar ao mesmo tempo.
        if sound == .victory || sound == .defeat {
            let otherSound: GameSound = sound == .victory ? .defeat : .victory
            if let otherPlayer = players[otherSound], otherPlayer.isPlaying {
                otherPlayer.stop()
                otherPlayer.currentTime = 0
            }
        }

        if let player =
            players[sound] {

            player.currentTime = 0
            player.play()

            return
        }

        guard let url =
                Bundle.main.url(
                    forResource:
                        sound.rawValue,
                    withExtension:
                        "wav"
                )
        else {

            print(
                "🔇 Áudio não encontrado:",
                "\(sound.rawValue).wav"
            )

            return
        }

        do {

            let player =
                try AVAudioPlayer(
                    contentsOf: url
                )

            player.prepareToPlay()

            players[sound] =
                player

            player.play()

        } catch {

            print(
                "❌ Erro carregando \(sound.rawValue):",
                error
            )
        }
    }
}
