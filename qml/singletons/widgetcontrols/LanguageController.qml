pragma Singleton

import Quickshell
import Quickshell.Io
import "../../"

// Controle do idioma por IPC (troca na hora, sem reiniciar):
//
//   quickshell -c wayck ipc call language set pt     # muda e grava no config.json
//   quickshell -c wayck ipc call language set auto   # volta a seguir o idioma do sistema
//   quickshell -c wayck ipc call language get        # idioma que está na tela
//   quickshell -c wayck ipc call language list       # códigos e nomes disponíveis
Singleton {
    id: root

    function set(code: string): void {
        I18n.setLanguage(code)
    }

    function get(): string {
        return I18n.activeLang
    }

    function list(): string {
        return I18n.languages.map(l => l.code + "\t" + l.name).join("\n")
    }

    IpcHandler {
        target: "language"

        function set(code: string): void { root.set(code) }
        function get(): string { return root.get() }
        function list(): string { return root.list() }
    }
}
