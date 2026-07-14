-- French. Missing keys fall back to enUS. File is UTF-8.
local _, NS = ...
NS.locales = NS.locales or {}

NS.locales.frFR = {
    TITLE = "HCBB Dungeon Finder",
    TAB_FIND = "Chercher un groupe",
    TAB_POOL = "Qui cherche ?",
    TAB_OPT = "Options",

    BOSS_LABEL = "Boss visé",
    BOSS_REQ = "Requiert niveau %d–%d — vous êtes %d",
    BOSS_CLEARED = "Vaincu",
    BOSS_TOGGLE_HINT = "Maj-clic : marquer vaincu / à faire",

    ROLES_LABEL = "Vos rôles",
    ROLES_HINT = "Choisissez chaque rôle que vous savez vraiment jouer — au moins un requis.",
    ROLE_TANK = "Tank",
    ROLE_HEAL = "Soigneur",
    ROLE_SUPPORT = "Soutien",
    ROLE_DPS = "DPS",
    ERR_NO_ROLE = "Sélectionnez au moins un rôle",

    MIN_LABEL = "Taille minimale du groupe",
    MIN_3 = "3+",
    MIN_4 = "4+",
    MIN_5 = "5 uniquement",
    MIN_HINT = "Les groupes de 5 sont toujours privilégiés ; une taille plus souple élargit vos chances.",

    OPT_LEAD = "Je veux bien diriger le groupe",
    BTN_SEARCH = "Chercher un groupe",
    BTN_CANCEL = "Annuler la recherche",
    POOL_COUNT = "%d joueurs cherchent dans votre tranche",

    PROP_TITLE = "Groupe trouvé !",
    PROP_YOU_ROLE = "Votre rôle assigné :",
    BTN_ACCEPT = "Accepter",
    BTN_DECLINE = "Refuser",
    BTN_OKAY = "OK",
    PROP_TIMER = "%d s pour répondre",
    PROP_OF = "sur",
    PROP_ALL_IN = "tout le monde a accepté — formation du groupe",
    PROP_CANCELLED = "Proposition annulée",
    PROP_WAIT = "Accepté — en attente des autres…",
    PROP_FORMING = "Tout le monde a accepté — guettez l'invitation de groupe !",
    PROP_DECLINED = "Un joueur a refusé — retour à la recherche, votre annonce est intacte.",
    PROP_EXPIRED = "Proposition expirée — retour à la recherche.",
    LEADER = "Chef",

    FILTER_ALL = "Tous les donjons",
    POOL_EMPTY = "Personne dans cette tranche — inscrivez-vous pour lancer le mouvement.",
    BROWSER_CLICK_HINT = "Clic droit pour les options",
    BROWSER_INVITE = "Inviter dans le groupe",
    BROWSER_SUGGEST = "Suggérer au chef de groupe",
    BROWSER_WHISPER = "Chuchoter",
    BROWSER_CANCEL = "Annuler",
    SUGGEST_MSG = "Invitons %s pour %s",
    SUGGEST_POPUP = "%s suggère d'inviter %s pour %s. Inviter maintenant ?",

    OPT_LANG = "Langue",
    LANG_AUTO = "Auto (client du jeu)",
    OPT_MM = "Afficher le bouton minicarte",
    OPT_SOUND = "Jouer un son à la proposition de groupe",
    OPT_HB_INFO = "Signal toutes les %d s · les annonces expirent après %d s",

    CH_OK = "Connecté au canal de recherche",
    CH_RECON = "Reconnexion au canal de recherche…",
    CH_LABEL = "Canal LFG",
    CH_RECON_SHORT = "reconnexion…",
    ST_SEARCH_FULL = "Recherche — %s · %d dans votre tranche",

    ST_NOT_ENROLLED = "Ce personnage n'est pas inscrit au défi Hardcore Boss Blitz",
    ST_UPDATE = "Mise à jour disponible \226\128\148 pensez à mettre à jour l'addon",
    NOT_ENROLLED_HINT = "Seuls les participants inscrits peuvent chercher un groupe. Parlez au Maître des épreuves dans votre zone de départ (niveau 1) pour rejoindre le Boss Blitz.",
    ALREADY_GROUPED_HINT = "Vous êtes déjà dans un groupe — quittez-le pour en chercher un nouveau.",

    ST_IDLE = "Inactif",
    ST_SEARCH = "Recherche — %s",
    ST_PROPOSAL = "Proposition en attente — répondez à la fenêtre",
    ST_FORMING = "Groupe en formation — guettez l'invitation",
    ST_GROUP = "En groupe — bonne chance !",
    ST_PAUSED = "En pause — reconnexion au canal…",

    MSG_BOSS_CLEARED = "%s marqué comme vaincu.",
    MSG_NEWER_PROTO = "Une version plus récente de HCBB Dungeon Finder circule — pensez à mettre à jour.",
    MSG_USAGE = "/hcbb — ouvrir la fenêtre · /hcbb demo — visite guidée",
}
