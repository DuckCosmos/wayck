pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// Traduções do Wayck (mesma ideia do serpantinum: 1 JSON por idioma).
//
//   assets/languages/en.json   <- idioma-base (sempre carregado, é o fallback)
//   assets/languages/pt.json   <- idioma atual (carregado sob demanda)
//
// Uso nos componentes (só conhecem a chave, nunca o texto):
//
//   Text { text: I18n.t("launcher.search") }
//   Text { text: I18n.t("launch.notInstalled", { name: "Firefox" }) }   // {name}
//   Text { text: I18n.t("player.none", "Sem player") }                  // texto alternativo
//
// Trocar de idioma SEM reiniciar (qualquer um dos 3 funciona e atualiza a tela na hora):
//
//   1. I18n.setLanguage("ja")                      // dentro do QML (ex.: tela de configurações)
//   2. quickshell -c wayck ipc call language set ja
//   3. editar "language" no ~/.config/wayck/config.json
//
// Ordem de decisão: config.json ("auto" = idioma do sistema) -> sistema -> inglês.
// Chave que falta no idioma atual cai pro inglês; se faltar nos dois, volta a própria chave.
Singleton {
    id: root

    readonly property string i18nDir: Quickshell.shellPath("assets/languages")

    // Idiomas disponíveis. Pra adicionar um: crie assets/languages/<code>.json e uma linha aqui.
    readonly property var languages: [
        { code: "ar",    name: "العربية" },
        { code: "az",    name: "Azərbaycanca" },
        { code: "bg",    name: "Български" },
        { code: "de",    name: "Deutsch" },
        { code: "en",    name: "English" },
        { code: "es",    name: "Español" },
        { code: "fa",    name: "فارسی" },
        { code: "fr",    name: "Français" },
        { code: "hi",    name: "हिन्दी" },
        { code: "hy",    name: "Հայերեն" },
        { code: "id",    name: "Bahasa Indonesia" },
        { code: "it",    name: "Italiano" },
        { code: "ja",    name: "日本語" },
        { code: "ko",    name: "한국어" },
        { code: "nl",    name: "Nederlands" },
        { code: "pl",    name: "Polski" },
        { code: "pt",    name: "Português" },
        { code: "ru",    name: "Русский" },
        { code: "tr",    name: "Türkçe" },
        { code: "ua",    name: "Українська" },
        { code: "vi",    name: "Tiếng Việt" },
        { code: "zh",    name: "简体中文" },
        { code: "zh_tw", name: "繁體中文" }
    ]

    readonly property var codes: languages.map(l => l.code)

    // O que o usuário escolheu ("auto" ou um código) e o que isso resolve de fato.
    readonly property string setting: Config.language
    readonly property string currentLang: resolve(setting)

    // Idioma que está NA TELA agora. Só muda depois que o JSON novo carregou,
    // então a troca é de uma vez só (sem piscar em inglês no meio do caminho).
    property string activeLang: "en"
    property var translations: ({})
    property bool isReady: false

    readonly property string currentName: nameOf(activeLang)

    // Idiomas escritos da direita pra esquerda.
    readonly property var rtlLanguages: ["ar", "fa", "ur", "he", "iw", "ps", "ug", "ckb", "yi"]
    readonly property bool rtl: rtlLanguages.indexOf(activeLang) !== -1
    readonly property int layoutDirection: rtl ? Qt.RightToLeft : Qt.LeftToRight
    readonly property int horizontalAlignment: rtl ? Text.AlignRight : Text.AlignLeft

    signal languageChanged()

    function isSupported(code) {
        return codes.indexOf(code) !== -1
    }

    function nameOf(code) {
        for (const lang of languages) {
            if (lang.code === code)
                return lang.name
        }

        return code
    }

    // Idioma do sistema: pt_BR.UTF-8 -> pt, uk_UA -> ua, zh_TW -> zh_tw.
    function systemLanguage() {
        const name = Qt.locale().name
        const lang = name.split("_")[0].toLowerCase()

        if (lang === "zh" && /^zh_(TW|HK|MO)/i.test(name))
            return "zh_tw"

        const mapped = lang === "uk" ? "ua" : lang

        return isSupported(mapped) ? mapped : "en"
    }

    function resolve(value) {
        const code = String(value || "auto").toLowerCase().trim()

        if (code === "auto" || !isSupported(code))
            return systemLanguage()

        return code
    }

    // Grava a escolha no config.json ("auto" volta a seguir o sistema).
    function setLanguage(code) {
        const value = String(code || "auto").toLowerCase().trim()

        if (value !== "auto" && !isSupported(value)) {
            console.warn("[I18n] idioma desconhecido:", code)
            return false
        }

        Config.setLanguage(value)
        return true
    }

    function resolveKey(lang, key) {
        let current = root.translations[lang]

        if (current === undefined || current === null)
            return null

        for (const part of String(key).split(".")) {
            if (current === null || typeof current !== "object" || current[part] === undefined)
                return null

            current = current[part]
        }

        return typeof current === "string" ? current : null
    }

    // t("a.b")                  -> texto traduzido (ou a própria chave se não existir)
    // t("a.b", "alternativo")   -> usa o alternativo se não existir
    // t("a.b", { name: "X" })   -> troca {name} por X
    function t(key, args) {
        const fallback = typeof args === "string" ? args : key

        if (!root.isReady)
            return fallback

        let text = resolveKey(root.activeLang, key)

        if (text === null && root.activeLang !== "en")
            text = resolveKey("en", key)

        if (text === null)
            return fallback

        if (args !== null && typeof args === "object") {
            for (const name in args)
                text = text.split("{" + name + "}").join(String(args[name]))
        }

        return text
    }

    function parse(raw) {
        if (!raw || raw.trim().length === 0)
            return null

        try {
            const data = JSON.parse(raw)
            return data && typeof data === "object" ? data : null
        } catch (e) {
            return null
        }
    }

    function store(lang, data) {
        const next = Object.assign({}, root.translations)
        next[lang] = data
        root.translations = next

        // O inglês é a base: assim que ele existe o sistema já pode traduzir.
        if (lang === "en" && !root.isReady)
            root.isReady = true

        activate()
    }

    // Troca o idioma da tela quando o JSON do idioma pedido já está na memória.
    function activate() {
        const wanted = root.currentLang
        const target = root.translations[wanted] !== undefined ? wanted : root.activeLang

        if (root.translations[target] === undefined)
            return

        const changed = target !== root.activeLang

        root.activeLang = target

        if (changed || !root.isReady)
            root.languageChanged()
    }

    onCurrentLangChanged: activate()

    FileView {
        id: baseFile

        path: root.i18nDir + "/en.json"
        watchChanges: true

        onFileChanged: reload()

        onLoaded: {
            const data = root.parse(text())

            if (data)
                root.store("en", data)
            else
                console.warn("[I18n] en.json inválido")
        }

        onLoadFailed: error => console.warn("[I18n] não consegui ler o en.json:", error)
    }

    FileView {
        id: langFile

        // Inglês já vem do baseFile.
        path: root.currentLang !== "en" ? root.i18nDir + "/" + root.currentLang + ".json" : ""
        watchChanges: true

        onFileChanged: reload()

        onLoaded: {
            const lang = root.currentLang
            const data = root.parse(text())

            if (data)
                root.store(lang, data)
            else
                console.warn("[I18n]", lang + ".json inválido; mantendo o idioma anterior")
        }

        onLoadFailed: error => console.warn("[I18n] não consegui ler", root.currentLang + ".json:", error)
    }
}
