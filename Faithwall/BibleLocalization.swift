import Foundation

// MARK: - Bible Localization Manager
/// Provides localized strings based on selected Bible translation language
/// Overrides system locale to match Bible language selection
final class BibleLocalizationManager {
    static let shared = BibleLocalizationManager()
    
    private init() {}
    
    /// Get localized string for the currently selected Bible translation
    func localizedString(_ key: LocalizationKey, for translation: BibleTranslation? = nil) -> String {
        let trans = translation ?? BibleLanguageManager.shared.selectedTranslation
        let language = trans.languageCode
        
        return strings[language]?[key] ?? strings["en"]?[key] ?? key.rawValue
    }
    
    // MARK: - Localization Keys
    enum LocalizationKey: String {
        // Testament
        case oldTestament
        case newTestament
        
        // Bible Explorer
        case exploreBible
        case loadingBible
        case unableToLoadBible
        case downloadBible
        case resetAndRedownload
        case changeLanguage
        case searchBooks
        case closeBible
        case bibleLanguage
        case done
        case cancel
        case retry
        case ready
        case downloaded
        case tapToDownload
        case tapToRetry
        case downloading
        case downloadFailed
        
        // Verse Actions
        case addToLockScreen
        case add
        case verseAddedToLockScreen
        
        // Settings
        case settings
        case bibleLanguageAndVersion
        case downloadedVersions
        case versions
        
        // General
        case close
        case continues
        case downloadAndContinue
        case chooseBibleLanguage
        case chooseVersion
        case offlineAvailable
    }
    
    // MARK: - Localization Strings Database
    private let strings: [String: [LocalizationKey: String]] = [
        // English
        "en": [
            .oldTestament: "Old Testament",
            .newTestament: "New Testament",
            .exploreBible: "Explore Bible",
            .loadingBible: "Loading Bible...",
            .unableToLoadBible: "Unable to Load Bible",
            .downloadBible: "Download Bible",
            .resetAndRedownload: "Reset & Redownload",
            .changeLanguage: "Change Language",
            .searchBooks: "Search books...",
            .closeBible: "Close",
            .bibleLanguage: "Bible Language",
            .done: "Done",
            .cancel: "Cancel",
            .retry: "Retry",
            .ready: "Ready",
            .downloaded: "Downloaded",
            .tapToDownload: "Tap to download",
            .tapToRetry: "Tap to retry",
            .downloading: "Downloading",
            .downloadFailed: "Download failed",
            .addToLockScreen: "Add to Lock Screen?",
            .add: "Add",
            .verseAddedToLockScreen: "Verse added to lock screen",
            .settings: "Settings",
            .bibleLanguageAndVersion: "Bible Language & Version",
            .downloadedVersions: "Downloaded versions are available offline",
            .versions: "versions",
            .close: "Close",
            .continues: "Continue",
            .downloadAndContinue: "Download & Continue",
            .chooseBibleLanguage: "Choose your preferred Bible language",
            .chooseVersion: "Choose Version",
            .offlineAvailable: "Bible databases are downloaded for offline use (~4MB each)"
        ],
        
        // Ukrainian
        "uk": [
            .oldTestament: "Старий Завіт",
            .newTestament: "Новий Завіт",
            .exploreBible: "Дослідити Біблію",
            .loadingBible: "Завантаження Біблії...",
            .unableToLoadBible: "Не вдалося завантажити Біблію",
            .downloadBible: "Завантажити Біблію",
            .resetAndRedownload: "Скинути і завантажити знову",
            .changeLanguage: "Змінити мову",
            .searchBooks: "Пошук книг...",
            .closeBible: "Закрити",
            .bibleLanguage: "Мова Біблії",
            .done: "Готово",
            .cancel: "Скасувати",
            .retry: "Повторити",
            .ready: "Готово",
            .downloaded: "Завантажено",
            .tapToDownload: "Натисніть для завантаження",
            .tapToRetry: "Натисніть для повтору",
            .downloading: "Завантаження",
            .downloadFailed: "Помилка завантаження",
            .addToLockScreen: "Додати на екран блокування?",
            .add: "Додати",
            .verseAddedToLockScreen: "Вірш додано на екран блокування",
            .settings: "Налаштування",
            .bibleLanguageAndVersion: "Мова і версія Біблії",
            .downloadedVersions: "Завантажені версії доступні офлайн",
            .versions: "версії",
            .close: "Закрити",
            .continues: "Продовжити",
            .downloadAndContinue: "Завантажити і продовжити",
            .chooseBibleLanguage: "Виберіть бажану мову Біблії",
            .chooseVersion: "Виберіть версію",
            .offlineAvailable: "Бази даних Біблії завантажуються для офлайн-використання (~4МБ кожна)"
        ],
        
        // Russian
        "ru": [
            .oldTestament: "Ветхий Завет",
            .newTestament: "Новый Завет",
            .exploreBible: "Исследовать Библию",
            .loadingBible: "Загрузка Библии...",
            .unableToLoadBible: "Не удалось загрузить Библию",
            .downloadBible: "Скачать Библию",
            .resetAndRedownload: "Сбросить и скачать заново",
            .changeLanguage: "Изменить язык",
            .searchBooks: "Поиск книг...",
            .closeBible: "Закрыть",
            .bibleLanguage: "Язык Библии",
            .done: "Готово",
            .cancel: "Отмена",
            .retry: "Повторить",
            .ready: "Готово",
            .downloaded: "Загружено",
            .tapToDownload: "Нажмите для загрузки",
            .tapToRetry: "Нажмите для повтора",
            .downloading: "Загрузка",
            .downloadFailed: "Ошибка загрузки",
            .addToLockScreen: "Добавить на экран блокировки?",
            .add: "Добавить",
            .verseAddedToLockScreen: "Стих добавлен на экран блокировки",
            .settings: "Настройки",
            .bibleLanguageAndVersion: "Язык и версия Библии",
            .downloadedVersions: "Загруженные версии доступны офлайн",
            .versions: "версии",
            .close: "Закрыть",
            .continues: "Продолжить",
            .downloadAndContinue: "Скачать и продолжить",
            .chooseBibleLanguage: "Выберите предпочитаемый язык Библии",
            .chooseVersion: "Выберите версию",
            .offlineAvailable: "Базы данных Библии загружаются для автономного использования (~4МБ каждая)"
        ],
        
        // Spanish
        "es": [
            .oldTestament: "Antiguo Testamento",
            .newTestament: "Nuevo Testamento",
            .exploreBible: "Explorar Biblia",
            .loadingBible: "Cargando Biblia...",
            .unableToLoadBible: "No se puede cargar la Biblia",
            .downloadBible: "Descargar Biblia",
            .resetAndRedownload: "Restablecer y descargar",
            .changeLanguage: "Cambiar idioma",
            .searchBooks: "Buscar libros...",
            .closeBible: "Cerrar",
            .bibleLanguage: "Idioma de la Biblia",
            .done: "Hecho",
            .cancel: "Cancelar",
            .retry: "Reintentar",
            .ready: "Listo",
            .downloaded: "Descargado",
            .tapToDownload: "Toca para descargar",
            .tapToRetry: "Toca para reintentar",
            .downloading: "Descargando",
            .downloadFailed: "Error de descarga",
            .addToLockScreen: "¿Agregar a pantalla de bloqueo?",
            .add: "Agregar",
            .verseAddedToLockScreen: "Versículo agregado a pantalla de bloqueo",
            .settings: "Ajustes",
            .bibleLanguageAndVersion: "Idioma y versión de la Biblia",
            .downloadedVersions: "Las versiones descargadas están disponibles sin conexión",
            .versions: "versiones",
            .close: "Cerrar",
            .continues: "Continuar",
            .downloadAndContinue: "Descargar y continuar",
            .chooseBibleLanguage: "Elige tu idioma preferido de la Biblia",
            .chooseVersion: "Elegir versión",
            .offlineAvailable: "Las bases de datos de la Biblia se descargan para uso sin conexión (~4MB cada una)"
        ],
        
        // French
        "fr": [
            .oldTestament: "Ancien Testament",
            .newTestament: "Nouveau Testament",
            .exploreBible: "Explorer la Bible",
            .loadingBible: "Chargement de la Bible...",
            .unableToLoadBible: "Impossible de charger la Bible",
            .downloadBible: "Télécharger la Bible",
            .resetAndRedownload: "Réinitialiser et télécharger",
            .changeLanguage: "Changer de langue",
            .searchBooks: "Rechercher des livres...",
            .closeBible: "Fermer",
            .bibleLanguage: "Langue de la Bible",
            .done: "Terminé",
            .cancel: "Annuler",
            .retry: "Réessayer",
            .ready: "Prêt",
            .downloaded: "Téléchargé",
            .tapToDownload: "Appuyez pour télécharger",
            .tapToRetry: "Appuyez pour réessayer",
            .downloading: "Téléchargement",
            .downloadFailed: "Échec du téléchargement",
            .addToLockScreen: "Ajouter à l'écran de verrouillage?",
            .add: "Ajouter",
            .verseAddedToLockScreen: "Verset ajouté à l'écran de verrouillage",
            .settings: "Paramètres",
            .bibleLanguageAndVersion: "Langue et version de la Bible",
            .downloadedVersions: "Les versions téléchargées sont disponibles hors ligne",
            .versions: "versions",
            .close: "Fermer",
            .continues: "Continuer",
            .downloadAndContinue: "Télécharger et continuer",
            .chooseBibleLanguage: "Choisissez votre langue de Bible préférée",
            .chooseVersion: "Choisir la version",
            .offlineAvailable: "Les bases de données de la Bible sont téléchargées pour une utilisation hors ligne (~4Mo chacune)"
        ],
        
        // German
        "de": [
            .oldTestament: "Altes Testament",
            .newTestament: "Neues Testament",
            .exploreBible: "Bibel erkunden",
            .loadingBible: "Bibel wird geladen...",
            .unableToLoadBible: "Bibel kann nicht geladen werden",
            .downloadBible: "Bibel herunterladen",
            .resetAndRedownload: "Zurücksetzen und neu herunterladen",
            .changeLanguage: "Sprache ändern",
            .searchBooks: "Bücher suchen...",
            .closeBible: "Schließen",
            .bibleLanguage: "Bibelsprache",
            .done: "Fertig",
            .cancel: "Abbrechen",
            .retry: "Wiederholen",
            .ready: "Bereit",
            .downloaded: "Heruntergeladen",
            .tapToDownload: "Zum Herunterladen tippen",
            .tapToRetry: "Zum Wiederholen tippen",
            .downloading: "Wird heruntergeladen",
            .downloadFailed: "Download fehlgeschlagen",
            .addToLockScreen: "Zum Sperrbildschirm hinzufügen?",
            .add: "Hinzufügen",
            .verseAddedToLockScreen: "Vers zum Sperrbildschirm hinzugefügt",
            .settings: "Einstellungen",
            .bibleLanguageAndVersion: "Bibelsprache und -version",
            .downloadedVersions: "Heruntergeladene Versionen sind offline verfügbar",
            .versions: "Versionen",
            .close: "Schließen",
            .continues: "Fortfahren",
            .downloadAndContinue: "Herunterladen und fortfahren",
            .chooseBibleLanguage: "Wählen Sie Ihre bevorzugte Bibelsprache",
            .chooseVersion: "Version wählen",
            .offlineAvailable: "Bibeldatenbanken werden für die Offline-Nutzung heruntergeladen (~4MB pro Stück)"
        ],
        
        // Portuguese
        "pt": [
            .oldTestament: "Antigo Testamento",
            .newTestament: "Novo Testamento",
            .exploreBible: "Explorar Bíblia",
            .loadingBible: "Carregando Bíblia...",
            .unableToLoadBible: "Não foi possível carregar a Bíblia",
            .downloadBible: "Baixar Bíblia",
            .resetAndRedownload: "Redefinir e baixar novamente",
            .changeLanguage: "Mudar idioma",
            .searchBooks: "Pesquisar livros...",
            .closeBible: "Fechar",
            .bibleLanguage: "Idioma da Bíblia",
            .done: "Concluído",
            .cancel: "Cancelar",
            .retry: "Tentar novamente",
            .ready: "Pronto",
            .downloaded: "Baixado",
            .tapToDownload: "Toque para baixar",
            .tapToRetry: "Toque para tentar novamente",
            .downloading: "Baixando",
            .downloadFailed: "Falha no download",
            .addToLockScreen: "Adicionar à tela de bloqueio?",
            .add: "Adicionar",
            .verseAddedToLockScreen: "Versículo adicionado à tela de bloqueio",
            .settings: "Configurações",
            .bibleLanguageAndVersion: "Idioma e versão da Bíblia",
            .downloadedVersions: "Versões baixadas estão disponíveis offline",
            .versions: "versões",
            .close: "Fechar",
            .continues: "Continuar",
            .downloadAndContinue: "Baixar e continuar",
            .chooseBibleLanguage: "Escolha seu idioma preferido da Bíblia",
            .chooseVersion: "Escolher versão",
            .offlineAvailable: "Bancos de dados da Bíblia são baixados para uso offline (~4MB cada)"
        ],
        
        // Chinese (Simplified - covering both)
        "zh": [
            .oldTestament: "旧约",
            .newTestament: "新约",
            .exploreBible: "探索圣经",
            .loadingBible: "加载圣经中...",
            .unableToLoadBible: "无法加载圣经",
            .downloadBible: "下载圣经",
            .resetAndRedownload: "重置并重新下载",
            .changeLanguage: "更改语言",
            .searchBooks: "搜索书籍...",
            .closeBible: "关闭",
            .bibleLanguage: "圣经语言",
            .done: "完成",
            .cancel: "取消",
            .retry: "重试",
            .ready: "准备就绪",
            .downloaded: "已下载",
            .tapToDownload: "点击下载",
            .tapToRetry: "点击重试",
            .downloading: "下载中",
            .downloadFailed: "下载失败",
            .addToLockScreen: "添加到锁屏？",
            .add: "添加",
            .verseAddedToLockScreen: "经文已添加到锁屏",
            .settings: "设置",
            .bibleLanguageAndVersion: "圣经语言和版本",
            .downloadedVersions: "已下载版本可离线使用",
            .versions: "版本",
            .close: "关闭",
            .continues: "继续",
            .downloadAndContinue: "下载并继续",
            .chooseBibleLanguage: "选择您喜欢的圣经语言",
            .chooseVersion: "选择版本",
            .offlineAvailable: "圣经数据库下载后可离线使用（每个约4MB）"
        ]
    ]
}

// MARK: - BibleTranslation Extension
extension BibleTranslation {
    /// ISO 639-1 language code for localization
    var languageCode: String {
        switch self {
        case .kjv, .bsb, .asv, .web, .bbe:
            return "en"
        case .ukrOgienko:
            return "uk"
        case .rusSynodal:
            return "ru"
        case .spaRV:
            return "es"
        case .freJND:
            return "fr"
        case .gerSch:
            return "de"
        case .porBLivre:
            return "pt"
        case .chiUn:
            return "zh"
        }
    }
}

// MARK: - Convenience Accessor
/// Helper to get localized strings easily
func BL(_ key: BibleLocalizationManager.LocalizationKey) -> String {
    BibleLocalizationManager.shared.localizedString(key)
}
